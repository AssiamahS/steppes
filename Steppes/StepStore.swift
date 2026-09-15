import Foundation
import CoreMotion
import HealthKit
import ActivityKit
import BackgroundTasks
import Observation

struct DaySnapshot: Equatable {
    var steps: Int = 0
    var distanceMeters: Double = 0
    var floors: Int = 0
    var updatedAt: Date = .now
}

/// Single source of truth for today's steps and the Live Activity that mirrors them.
///
/// Step source: CMPedometer (motion coprocessor, cumulative since midnight).
/// Falls back to a HealthKit sum when Motion access is denied.
///
/// Background wake-ups (the app cannot run just because a Live Activity exists):
///   1. HealthKit background delivery for stepCount — iOS wakes us when new step samples land.
///   2. BGAppRefreshTask every ~15 min as a backstop.
/// Both paths re-query the pedometer and push the number into the activity.
/// `Activity.request` is foreground-only, so a fresh activity (e.g. after the 8h
/// Dynamic Island limit) is only minted when the app comes to the foreground.
@MainActor
@Observable
final class StepStore {
    static let shared = StepStore()
    static let refreshTaskID = "com.assiamah.steppes.refresh"

    var snapshot = DaySnapshot()
    var motionDenied = false
    var goal: Int {
        didSet {
            UserDefaults.standard.set(goal, forKey: "goal")
            Task { await pushActivity() }
        }
    }
    var islandOn: Bool {
        didSet { UserDefaults.standard.set(islandOn, forKey: "islandOn") }
    }
    private(set) var activity: Activity<StepsActivityAttributes>?
    var activityActive: Bool { activity?.activityState == .active }

    private let pedometer = CMPedometer()
    private let health = HKHealthStore()
    private var liveFrom: Date?
    private var observerRunning = false
    private var healthAsked = false

    private init() {
        goal = UserDefaults.standard.object(forKey: "goal") as? Int ?? 10_000
        islandOn = UserDefaults.standard.object(forKey: "islandOn") as? Bool ?? true
    }

    // MARK: - Lifecycle

    /// Called at every launch, foreground or background.
    func bootstrap() {
        activity = Activity<StepsActivityAttributes>.activities.first { $0.activityState == .active }
        startHealthObserver()
        scheduleRefresh()
    }

    /// Called whenever the scene becomes active.
    func foreground() {
        startLiveUpdates()
        Task {
            await refresh()
            await requestHealthIfNeeded()
            await ensureActivity()
        }
    }

    func backgroundRefresh() async {
        scheduleRefresh()
        await refresh()
    }

    // MARK: - Pedometer

    private var startOfToday: Date { Calendar.current.startOfDay(for: .now) }

    private func startLiveUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        if let liveFrom, Calendar.current.isDateInToday(liveFrom) { return }
        pedometer.stopUpdates()
        let from = startOfToday
        liveFrom = from
        pedometer.startUpdates(from: from) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.handle(motionError: error)
                    return
                }
                guard let data else { return }
                if !Calendar.current.isDateInToday(from) {
                    self.startLiveUpdates()   // midnight rolled over — restart from the new day
                    return
                }
                self.apply(data)
                await self.pushActivity()
            }
        }
    }

    /// One-shot re-query. Safe from the background.
    func refresh() async {
        let from = startOfToday
        if CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() != .denied {
            do {
                let data = try await queryPedometer(from: from)
                apply(data)
                await pushActivity()
                return
            } catch {
                handle(motionError: error)
            }
        }
        if let steps = try? await healthSteps(from: from) {
            snapshot.steps = steps
            snapshot.updatedAt = .now
            await pushActivity()
        }
    }

    private func queryPedometer(from: Date) async throws -> CMPedometerData {
        try await withCheckedThrowingContinuation { cont in
            pedometer.queryPedometerData(from: from, to: .now) { data, error in
                if let data {
                    cont.resume(returning: data)
                } else {
                    cont.resume(throwing: error ?? CocoaError(.featureUnsupported))
                }
            }
        }
    }

    private func apply(_ d: CMPedometerData) {
        snapshot = DaySnapshot(steps: d.numberOfSteps.intValue,
                               distanceMeters: d.distance?.doubleValue ?? 0,
                               floors: d.floorsAscended?.intValue ?? 0,
                               updatedAt: .now)
        motionDenied = false
    }

    private func handle(motionError: Error) {
        let code = (motionError as NSError).code
        motionDenied = code == Int(CMErrorMotionActivityNotAuthorized.rawValue)
            || CMPedometer.authorizationStatus() == .denied
    }

    // MARK: - HealthKit (background wake-ups + fallback count)

    private var stepType: HKQuantityType { HKQuantityType(.stepCount) }

    private func requestHealthIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable(), !healthAsked else { return }
        healthAsked = true
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType])
            try await health.enableBackgroundDelivery(for: stepType, frequency: .immediate)
        } catch {
            return
        }
        startHealthObserver()
    }

    private func startHealthObserver() {
        guard HKHealthStore.isHealthDataAvailable(), !observerRunning else { return }
        observerRunning = true
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.refresh()
                completion()
            }
        }
        health.execute(query)
    }

    private func healthSteps(from: Date) async throws -> Int {
        let samples = HKQuery.predicateForSamples(withStart: from, end: .now)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: samples),
            options: .cumulativeSum)
        let stats = try await descriptor.result(for: health)
        return Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }

    // MARK: - Live Activity

    private func content() -> ActivityContent<StepsActivityAttributes.ContentState> {
        let state = StepsActivityAttributes.ContentState(steps: snapshot.steps,
                                                         goal: goal,
                                                         distanceMeters: snapshot.distanceMeters,
                                                         floors: snapshot.floors,
                                                         updatedAt: snapshot.updatedAt)
        return ActivityContent(state: state, staleDate: .now.addingTimeInterval(45 * 60))
    }

    /// Foreground only: make the Dynamic Island state match `islandOn`.
    func ensureActivity() async {
        guard islandOn else {
            await endActivity()
            return
        }
        if let activity, activity.activityState == .active {
            await activity.update(content())
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for stale in Activity<StepsActivityAttributes>.activities {
            await stale.end(nil, dismissalPolicy: .immediate)
        }
        activity = try? Activity.request(attributes: StepsActivityAttributes(startOfDay: startOfToday),
                                         content: content(),
                                         pushType: nil)
    }

    func pushActivity() async {
        guard let activity else { return }
        guard activity.activityState == .active else {
            self.activity = nil
            return
        }
        await activity.update(content())
    }

    func endActivity() async {
        for a in Activity<StepsActivityAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    // MARK: - Background refresh backstop

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
