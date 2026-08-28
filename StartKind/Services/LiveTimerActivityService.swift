import Foundation

#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

@MainActor
final class LiveTimerActivityService {
    #if canImport(ActivityKit)
    private var activity: Activity<StartKindTimerAttributes>?
    private var stepText = ""
    #endif

    func start(step: NextStepModel, plannedMinutes: Int) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = StartKindTimerAttributes(title: step.title)
        stepText = step.proposal.step
        let state = StartKindTimerAttributes.ContentState(
            step: stepText,
            endsAt: Date().addingTimeInterval(TimeInterval(plannedMinutes * 60))
        )
        do {
            if #available(iOS 16.2, *) {
                activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            activity = nil
        }
        #endif
    }

    /// Keep the Lock Screen countdown in step with the in-app timer after the
    /// user extends it or pauses it.
    func update(remainingSeconds: Int, isPaused: Bool) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let remaining = max(0, remainingSeconds)
        let state = StartKindTimerAttributes.ContentState(
            step: stepText,
            endsAt: Date().addingTimeInterval(TimeInterval(remaining)),
            pausedSecondsRemaining: isPaused ? remaining : nil
        )
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
        #endif
    }

    func end() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        self.activity = nil
        stepText = ""
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
