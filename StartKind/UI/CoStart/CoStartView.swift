import SwiftUI
import UIKit

private struct CoStartStageMarker: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("costart.stage")
    }
}

/// Co-start entry: pick AI quiet co-start or invite a friend (25 min).
struct CoStartView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let step: NextStepModel
    var initialMode: CoStartRoomType? = nil
    var onFriendLimitReached: (() -> Void)? = nil

    @State private var room: CoStartRoomModel?
    @State private var session: TimerSessionModel?
    @State private var didApplyInitialMode = false
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let room {
                    CoStartRoomView(
                        room: room,
                        stepText: step.proposal.step,
                        session: session,
                        hostStep: step,
                        isGuest: false,
                        onStart: { beginCoStart(room) },
                        onLeave: { await leaveCoStart(room) }
                    ) { outcome in
                        guard let session else { return }
                        env.endCoStart(room: room, session: session, outcome: outcome, step: step)
                        dismiss()
                    }
                } else {
                    modePicker
                }
            }
            .navigationTitle(L("costart.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if room == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("common.close")) { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(room != nil)
        .task {
            guard !didApplyInitialMode, let initialMode else { return }
            didApplyInitialMode = true
            await start(type: initialMode)
        }
    }

    private var modePicker: some View {
        ScrollView {
            VStack(spacing: Theme.spacing20) {
                CoStartStageMarker(text: L("costart.stage.createOrJoin"))

                VStack(spacing: Theme.spacing8) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, Theme.spacing8)
                    Text(verbatim: L("costart.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: Theme.spacing8) {
                    Text(verbatim: L("costart.yourStep"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: step.proposal.step)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
                }
                if let errorMessage {
                    KindBanner(text: errorMessage, tone: .warning)
                        .accessibilityIdentifier("costart.error")
                }
                PrimaryButton(
                    "costart.aiQuiet",
                    systemImage: "sparkles",
                    enabled: !isStarting,
                    busy: isStarting,
                    accessibilityId: "costart.ai"
                ) {
                    Task { await start(type: .aiQuiet) }
                }
                PrimaryButton(
                    "costart.friend",
                    systemImage: "link",
                    enabled: !isStarting,
                    busy: isStarting,
                    accessibilityId: "costart.friend"
                ) {
                    Task { await start(type: .friendLink) }
                }
                if let preferred = env.coStartContinuity.preferred {
                    Button {
                        Task { await start(type: .friendLink) }
                    } label: {
                        Label(L("costart.again", preferred.displayName), systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled(isStarting)
                    .accessibilityIdentifier("costart.again")
                }
            }
            .padding()
        }
    }

    private func start(type: CoStartRoomType) async {
        guard !isStarting else { return }
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }

        do {
            room = try await env.startCoStart(type: type, step: step, stepText: step.proposal.step)
        } catch CoStartError.friendLimitReached {
            onFriendLimitReached?()
        } catch APIError.network {
            // A generic "couldn't start" here sent people hunting for a bug in
            // the room; the usual cause is simply no route to the backend.
            errorMessage = L("costart.offline")
        } catch {
            errorMessage = L("costart.createError")
        }
    }

    private func beginCoStart(_ room: CoStartRoomModel) {
        guard session == nil else { return }
        session = env.beginCoStart(room: room, step: step)
    }

    private func leaveCoStart(_ room: CoStartRoomModel) async {
        await env.leaveCoStart(room: room, isGuest: false)
        dismiss()
    }
}

/// Guest join entry for the 6-digit room code flow.
struct CoStartCodeGuestJoinView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let roomCode: String

    @State private var name = ""
    @State private var stepText = ""
    @State private var joining = false
    @State private var errorMessage: String?
    @State private var room: CoStartRoomModel?

    var body: some View {
        NavigationStack {
            Group {
                if let room {
                    CoStartRoomView(
                        room: room,
                        stepText: resolvedStepText,
                        isGuest: true,
                        onLeave: {
                            await env.leaveCoStart(room: room, isGuest: true)
                            dismiss()
                        }
                    ) { outcome in
                        Task {
                            await env.endCoStartGuest(roomId: room.id, outcome: outcome)
                        }
                        dismiss()
                    }
                } else {
                    joinForm
                }
            }
            .navigationTitle(L("costart.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if room == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("common.close")) { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(room != nil)
    }

    private var joinForm: some View {
        ScrollView {
            VStack(spacing: Theme.spacing16) {
                CoStartStageMarker(text: L("costart.stage.createOrJoin"))

                VStack(spacing: Theme.spacing8) {
                    Text(verbatim: L("costart.enterCode"))
                        .font(.headline)
                    Text(verbatim: roomCode)
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("costart.code")
                    Text(verbatim: L("costart.guestSubtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.spacing8)

                TextField(L("costart.yourName"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityIdentifier("costart.guestname")
                TextField(L("costart.yourStep.optional"), text: $stepText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityIdentifier("costart.gueststep")
                if let errorMessage {
                    KindBanner(text: errorMessage, tone: .warning)
                        .accessibilityIdentifier("costart.join.error")
                }
                PrimaryButton(
                    "costart.join",
                    systemImage: "arrow.right.circle.fill",
                    enabled: !joining,
                    busy: joining,
                    accessibilityId: "costart.join"
                ) {
                    Task { await join() }
                }
            }
            .padding()
        }
    }

    private var resolvedStepText: String {
        let trimmed = stepText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("costart.defaultGuestStep") : trimmed
    }

    private var resolvedDisplayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? env.preferredGuestDisplayName : trimmed
    }

    private func join() async {
        guard !joining else { return }
        joining = true
        errorMessage = nil
        defer { joining = false }

        do {
            room = try await env.joinCoStartRoom(
                code: roomCode,
                stepText: resolvedStepText,
                displayName: resolvedDisplayName
            )
            if room == nil { errorMessage = L("costart.roomNotFound") }
        } catch {
            errorMessage = L("common.error")
        }
    }
}

/// The co-start room: waiting/ready is explicit, and the 25-minute countdown
/// exists only after the local Start action.
struct CoStartRoomView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    let room: CoStartRoomModel
    let stepText: String
    var session: TimerSessionModel? = nil
    var hostStep: NextStepModel? = nil
    let isGuest: Bool
    let onStart: () -> Void
    let onLeave: () async -> Void
    let onOutcome: (TimerOutcome) -> Void

    @State private var flowState: CoStartFlowState
    @State private var participants: [AppEnvironment.CoStartParticipantInfo] = []
    @State private var copied = false
    @State private var savedFriend = false
    @State private var isLeaving = false
    @State private var participantStatusUnavailable = false
    @State private var didEnd = false

    init(
        room: CoStartRoomModel,
        stepText: String,
        session: TimerSessionModel? = nil,
        hostStep: NextStepModel? = nil,
        isGuest: Bool,
        onStart: @escaping () -> Void = {},
        onLeave: @escaping () async -> Void = {},
        onOutcome: @escaping (TimerOutcome) -> Void
    ) {
        self.room = room
        self.stepText = stepText
        self.session = session
        self.hostStep = hostStep
        self.isGuest = isGuest
        self.onStart = onStart
        self.onLeave = onLeave
        self.onOutcome = onOutcome
        _flowState = State(
            initialValue: CoStartFlowState(
                roomType: room.roomType,
                participantCount: room.roomType == .friendLink ? 1 : 2,
                durationSeconds: max(1, room.durationMinutes * 60),
                started: session != nil
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing16) {
                CoStartStageMarker(text: stageTitle)

                Text(verbatim: L("costart.roomTitle"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                tinyStepSection
                participantStatus
                participantsList

                if room.roomType == .friendLink && flowState.stage != .focus {
                    inviteSection(inviteLink)
                }

                if room.roomType == .friendLink {
                    Text(verbatim: L("costart.syncNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stageContent
            }
            .padding(Theme.spacing16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .task { await pollParticipants() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            guard room.roomType == .friendLink else { return }
            Task { await pollParticipants() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            flowState.tick()
        }
    }

    private var stageTitle: String {
        switch flowState.stage {
        case .waiting: return L("costart.stage.waiting")
        case .ready: return L("costart.stage.ready")
        case .focus: return L("costart.stage.focus")
        }
    }

    private var tinyStepSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            Text(verbatim: L("costart.yourStep"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: stepText)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("costart.step")
    }

    private var participantStatusText: String {
        if participantStatusUnavailable {
            return L("costart.participantStatusUnavailable")
        }
        switch flowState.stage {
        case .waiting:
            return L("costart.waitingForParticipant")
        case .ready:
            if room.roomType == .aiQuiet { return L("costart.quietReady") }
            return isGuest ? L("costart.guestReady") : L("costart.friendReady")
        case .focus:
            return L("costart.focusStatus")
        }
    }

    private var participantStatus: some View {
        HStack(alignment: .top, spacing: Theme.spacing8) {
            Image(systemName: flowState.stage == .waiting ? "person.2" : "person.2.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(verbatim: L("costart.participantStatus"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(verbatim: participantStatusText)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: L("costart.participants.count", flowState.participantCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("costart.participantStatus")
    }

    private var participantsList: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            if room.roomType == .aiQuiet {
                participantRow(displayName: L("costart.you"), statedStep: stepText, id: "local-you")
                participantRow(
                    displayName: L("costart.ai"),
                    statedStep: L("costart.aiQuietPresence"),
                    id: "local-ai"
                )
            } else if participants.isEmpty {
                Text(verbatim: L("costart.participants.pending"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(participants) { participant in
                    participantRow(participant)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("costart.participants")
    }

    private func participantRow(_ participant: AppEnvironment.CoStartParticipantInfo) -> some View {
        participantRow(
            displayName: participant.displayName,
            statedStep: participant.statedStep,
            id: participant.id
        )
    }

    private func participantRow(displayName: String, statedStep: String, id: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing8) {
            Image(systemName: "person.fill")
                .foregroundStyle(Theme.accent)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                if !statedStep.isEmpty {
                    Text(verbatim: statedStep)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .id(id)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch flowState.stage {
        case .waiting, .ready:
            VStack(spacing: Theme.spacing12) {
                PrimaryButton(
                    "costart.start25",
                    systemImage: "play.fill",
                    enabled: flowState.canStart,
                    accessibilityId: "costart.start25"
                ) {
                    startFocus()
                }
                leaveButton
            }
        case .focus:
            VStack(spacing: Theme.spacing12) {
                Text(verbatim: timeString(flowState.remainingSeconds))
                    .font(.system(.largeTitle, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(flowState.remainingSeconds <= 0 ? Theme.accent : .primary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("costart.countdown")

                PrimaryButton(
                    "timer.done",
                    systemImage: "checkmark.circle.fill",
                    enabled: !didEnd,
                    accessibilityId: "costart.done"
                ) {
                    finish(.completed)
                }
                QuietButton(
                    "timer.makeSmaller",
                    systemImage: "arrow.down.right",
                    accessibilityId: "costart.makesmaller"
                ) {
                    finish(.paused)
                }
                QuietButton(
                    "timer.continueFive",
                    systemImage: "plus",
                    accessibilityId: "costart.continue5"
                ) {
                    flowState.add(minutes: 5)
                }
            }
        }
    }

    private var leaveButton: some View {
        Button {
            guard !isLeaving else { return }
            isLeaving = true
            Task {
                await onLeave()
                isLeaving = false
            }
        } label: {
            HStack(spacing: Theme.spacing8) {
                if isLeaving { ProgressView().controlSize(.small) }
                Text(verbatim: L("costart.leave"))
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .disabled(isLeaving)
        .accessibilityIdentifier("costart.leave")
    }

    private var inviteLink: URL? {
        guard let code = room.roomCode else { return nil }
        var components = URLComponents(string: "startkind://join")
        components?.queryItems = [URLQueryItem(name: "code", value: code)]
        return components?.url
    }

    /// What the invite sends: the room code and the App Store link for someone
    /// without the app, plus the scheme link that opens the room for someone who
    /// has it.
    private func inviteMessage(code: String, link: URL) -> String {
        L("costart.invite.message", code, AppStoreLinks.shareURL("invite").absoluteString, link.absoluteString)
    }

    @ViewBuilder
    private func inviteSection(_ link: URL?) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("costart.roomCode"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let code = room.roomCode {
                Text(verbatim: code)
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("costart.roomcode")
                Text(verbatim: L("costart.roomCodeHint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.spacing8) {
                if let link, let code = room.roomCode {
                    ShareLink(item: inviteMessage(code: code, link: link)) {
                        Label(L("costart.share"), systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("costart.share")
                }
                Button {
                    UIPasteboard.general.string = room.roomCode ?? link?.absoluteString
                    copied = true
                } label: {
                    Label(L("costart.copy"), systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityIdentifier("costart.copy")
            }
            if !isGuest, let partner = friendParticipant {
                Button {
                    env.savePreferredCoStarter(displayName: partner.displayName, roomCode: room.roomCode)
                    savedFriend = true
                } label: {
                    Label(L("costart.saveFriend"), systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityIdentifier("costart.saveFriend")
            }
            if copied {
                Text(verbatim: L("costart.copied"))
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }
            if savedFriend {
                Text(verbatim: L("costart.friendSaved"))
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }
        }
        .accessibilityIdentifier("costart.invite")
    }

    private var friendParticipant: AppEnvironment.CoStartParticipantInfo? {
        participants.first {
            $0.displayName != L("costart.you") &&
            $0.displayName != L("costart.ai") &&
            $0.displayName != L("costart.host")
        }
    }

    private func startFocus() {
        guard flowState.canStart, !didEnd else { return }
        flowState.start()
        onStart()
    }

    private func finish(_ outcome: TimerOutcome) {
        guard !didEnd else { return }
        didEnd = true
        onOutcome(outcome)
    }

    private func pollParticipants() async {
        guard room.roomType == .friendLink else { return }
        guard let fetched = await env.fetchCoStartParticipants(roomId: room.id) else {
            participantStatusUnavailable = true
            return
        }
        participants = fetched
        participantStatusUnavailable = false
        flowState.updateParticipantCount(fetched.count)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
