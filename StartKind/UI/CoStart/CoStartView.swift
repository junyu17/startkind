import SwiftUI

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
                if let room, let session {
                    CoStartRoomView(room: room, stepText: step.proposal.step, session: session, hostStep: step, isGuest: false) { outcome in
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
        .task {
            guard !didApplyInitialMode, let initialMode else { return }
            didApplyInitialMode = true
            await start(type: initialMode)
        }
    }

    private var modePicker: some View {
        ScrollView {
            VStack(spacing: Theme.spacing20) {
                VStack(spacing: Theme.spacing8) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, Theme.spacing24)
                    Text(verbatim: L("costart.subtitle"))
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(spacing: Theme.spacing8) {
                    Text(verbatim: L("costart.yourStep")).font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: step.proposal.step)
                        .font(.body).multilineTextAlignment(.center).padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
                }
                if let errorMessage {
                    KindBanner(text: errorMessage)
                        .accessibilityIdentifier("costart.error")
                }
                PrimaryButton("costart.aiQuiet", systemImage: "sparkles", enabled: !isStarting, accessibilityId: "costart.ai") {
                    Task { await start(type: .aiQuiet) }
                }
                PrimaryButton("costart.friend", systemImage: "link", enabled: !isStarting, accessibilityId: "costart.friend") {
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
                    .accessibilityIdentifier("costart.again")
                }
            }
            .padding()
        }
    }

    private func start(type: CoStartRoomType) async {
        guard !isStarting else { return }
        if type == .friendLink && !env.canCreateFriendCoStart {
            onFriendLimitReached?()
            return
        }
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }

        do {
            let result = try await env.startCoStart(type: type, step: step, stepText: step.proposal.step)
            room = result.room
            session = result.session
        } catch CoStartError.friendLimitReached {
            onFriendLimitReached?()
        } catch {
            errorMessage = L("costart.createError")
        }
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
                    CoStartRoomView(room: room, stepText: resolvedStepText, isGuest: true) { outcome in
                        Task { await env.endCoStartGuest(roomId: room.id, outcome: outcome) }
                        dismiss()
                    }
                } else {
                    joinForm
                }
            }
            .navigationTitle(L("costart.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("common.close")) { dismiss() } }
            }
        }
    }

    private var joinForm: some View {
        ScrollView {
            VStack(spacing: Theme.spacing16) {
                VStack(spacing: Theme.spacing8) {
                    Text(verbatim: L("costart.enterCode"))
                        .font(.headline)
                    Text(verbatim: roomCode)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("costart.code")
                    Text(verbatim: L("costart.guestSubtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.spacing24)

                TextField(L("costart.yourName"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("costart.guestname")
                TextField(L("costart.yourStep.optional"), text: $stepText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .accessibilityIdentifier("costart.gueststep")
                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                PrimaryButton("costart.join", systemImage: "arrow.right.circle.fill", enabled: !joining) {
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

    private func join() async {
        joining = true
        errorMessage = nil
        do {
            room = try await env.joinCoStartRoom(
                code: roomCode,
                stepText: resolvedStepText,
                displayName: name.isEmpty ? L("costart.friend") : name
            )
            if room == nil { errorMessage = L("costart.roomNotFound") }
        } catch {
            errorMessage = L("common.error")
        }
        joining = false
    }
}

/// The quiet room: 25-min countdown, your step, participants (polled), end check-in.
struct CoStartRoomView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    let room: CoStartRoomModel
    let stepText: String
    var session: TimerSessionModel? = nil
    var hostStep: NextStepModel? = nil
    let isGuest: Bool
    let onOutcome: (TimerOutcome) -> Void

    @State private var remaining = 25 * 60
    @State private var participants: [AppEnvironment.CoStartParticipantInfo] = []
    @State private var copied = false
    @State private var savedFriend = false

    var body: some View {
        VStack(spacing: Theme.spacing16) {
            Text(verbatim: L("costart.roomTitle"))
                .font(.title2).fontWeight(.bold).padding(.top, Theme.spacing16)

            VStack(spacing: Theme.spacing4) {
                Text(verbatim: L("costart.yourStep")).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: stepText).font(.subheadline).multilineTextAlignment(.center).padding(.horizontal)
            }

            participantsList

            Spacer()

            Text(verbatim: timeString(remaining))
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(remaining <= 0 ? Theme.accent : .primary)

            if room.roomType == .friendLink {
                inviteSection(inviteLink)
            }

            Spacer()

            PrimaryButton("timer.done", systemImage: "checkmark.circle.fill", accessibilityId: "costart.done") { onOutcome(.completed) }
            QuietButton("timer.makeSmaller", systemImage: "arrow.down.right", accessibilityId: "costart.makesmaller") { onOutcome(.paused) }
            QuietButton("timer.continueFive", systemImage: "plus", accessibilityId: "costart.continue5") { remaining += 300 }
                .padding(.bottom, Theme.spacing24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task { await pollParticipants() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            Task { await pollParticipants() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if remaining > 0 { remaining -= 1 }
        }
    }

    private var participantsList: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            ForEach(participants) { p in
                HStack(alignment: .top, spacing: Theme.spacing8) {
                    Image(systemName: "person.fill").foregroundStyle(Theme.accent).font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: p.displayName).font(.caption).fontWeight(.semibold)
                        if !p.statedStep.isEmpty {
                            Text(verbatim: p.statedStep).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var inviteLink: URL? {
        var c = URLComponents(string: "startkind://join")
        c?.queryItems = [URLQueryItem(name: "code", value: room.roomCode)]
        return c?.url
    }

    @ViewBuilder
    private func inviteSection(_ link: URL?) -> some View {
        VStack(spacing: Theme.spacing8) {
            Text(verbatim: L("costart.waitingForFriend"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let code = room.roomCode {
                Text(verbatim: code)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, Theme.spacing4)
                    .accessibilityIdentifier("costart.roomcode")
                Text(verbatim: L("costart.roomCodeHint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.spacing12) {
                if let link {
                    ShareLink(item: link) {
                        Label(L("costart.share"), systemImage: "square.and.arrow.up").font(.caption)
                    }
                }
                Button {
                    UIPasteboard.general.string = room.roomCode ?? link?.absoluteString
                    copied = true
                } label: {
                    Label(L("costart.copy"), systemImage: "doc.on.doc").font(.caption)
                }
            }
            if let partner = friendParticipant {
                Button {
                    env.savePreferredCoStarter(displayName: partner.displayName, roomCode: room.roomCode)
                    savedFriend = true
                } label: {
                    Label(L("costart.saveFriend"), systemImage: "person.crop.circle.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityIdentifier("costart.saveFriend")
            }
            if copied { Text(verbatim: L("costart.copied")).font(.caption2).foregroundStyle(Theme.accent) }
            if savedFriend { Text(verbatim: L("costart.friendSaved")).font(.caption2).foregroundStyle(Theme.accent) }
        }
    }

    private var friendParticipant: AppEnvironment.CoStartParticipantInfo? {
        participants.first { $0.displayName != L("costart.you") && $0.displayName != L("costart.ai") }
    }

    private func pollParticipants() async {
        participants = await env.fetchCoStartParticipants(roomId: room.id)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
