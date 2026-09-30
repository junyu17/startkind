import Foundation
import Speech
import AVFoundation

enum SpeechError: LocalizedError, Equatable {
    case notAuthorized, microphoneNotAuthorized, notAvailable, engineFailure

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return L("error.speech.notAuthorized")
        case .microphoneNotAuthorized: return L("error.speech.microphoneNotAuthorized")
        case .notAvailable: return L("error.speech.notAvailable")
        case .engineFailure: return L("error.speech.engineFailure")
        }
    }
}

/// System speech-to-text for voice capture, using on-device processing when available.
@MainActor
final class SpeechService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var isMicrophoneAuthorized = false
    @Published var transcript = ""
    @Published private(set) var lastError: SpeechError?

    private let audioEngine = AVAudioEngine()
    private var preferredLocale: Locale
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var startToken = UUID()
    private var hasRecognizedTextThisSession = false

    init(locale: Locale = .current) {
        preferredLocale = Self.normalizedLocale(for: locale)
    }

    /// Build the recognizer only once speech access has actually been granted.
    /// One created earlier — while authorization was still `.notDetermined` —
    /// keeps reporting `isAvailable == false` after the grant, which made the
    /// first tap after authorising silently do nothing.
    private func makeRecognizer() -> SFSpeechRecognizer? {
        if let recognizer, recognizer.isAvailable { return recognizer }
        guard let candidate = SFSpeechRecognizer(locale: preferredLocale), candidate.isAvailable else {
            return nil
        }
        recognizer = candidate
        return candidate
    }

    func updateLocale(_ languageOrLocale: String) {
        preferredLocale = Self.normalizedLocale(for: Locale(identifier: languageOrLocale))
        recognizer = nil
    }

    func refreshAuthorizationState() {
        isAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        isMicrophoneAuthorized = AVAudioApplication.shared.recordPermission == .granted
    }

    func start() async throws {
        guard !isListening && !isPreparing else { return }
        stopInternal()
        lastError = nil
        isPreparing = true
        let token = UUID()
        startToken = token
        defer {
            if startToken == token {
                isPreparing = false
            }
        }
        do {
            try await ensureAuthorization()
            guard startToken == token else { return }
            guard let recognizer = makeRecognizer() else {
                throw SpeechError.notAvailable
            }
            guard configureAudioSession() else {
                throw SpeechError.notAvailable
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            transcript = ""
            hasRecognizedTextThisSession = false

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw SpeechError.notAvailable
            }
            // This helper is nonisolated so AVAudioEngine never inherits
            // SpeechService's MainActor isolation for its realtime callback.
            Self.installAudioTap(on: inputNode, request: request)
            tapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            task = recognizer.recognitionTask(with: request, resultHandler: handleRecognition)
            guard startToken == token else { return }
            isListening = true
        } catch let error as SpeechError {
            stopInternal()
            throw error
        } catch {
            stopInternal()
            throw SpeechError.engineFailure
        }
    }

    /// Creates the AVAudioEngine callback outside SpeechService's global actor.
    /// AVFoundation invokes this block on a realtime queue, where touching a
    /// MainActor-isolated closure would trigger Swift's isolation assertion.
    private nonisolated static func installAudioTap(
        on inputNode: AVAudioInputNode,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            request.append(buffer)
        }
    }

    private func ensureAuthorization() async throws {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let finalSpeechStatus: SFSpeechRecognizerAuthorizationStatus
        if speechStatus == .notDetermined {
            finalSpeechStatus = await requestSpeechAuthorization()
        } else {
            finalSpeechStatus = speechStatus
        }
        isAuthorized = finalSpeechStatus == .authorized
        guard isAuthorized else { throw SpeechError.notAuthorized }

        let recordPermission = AVAudioApplication.shared.recordPermission
        let microphoneGranted: Bool
        if recordPermission == .undetermined {
            microphoneGranted = await requestMicrophoneAuthorization()
        } else {
            microphoneGranted = recordPermission == .granted
        }
        isMicrophoneAuthorized = microphoneGranted
        guard microphoneGranted else { throw SpeechError.microphoneNotAuthorized }
    }

    private nonisolated func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            return session.isInputAvailable
        } catch {
            return false
        }
    }

    /// Nonisolated recognition handler. SFSpeech may call this on a background
    /// queue, so it must not be MainActor-isolated; it hops to MainActor to
    /// update transcript and stop state.
    internal func receiveRecognition(text: String?, isFinal: Bool, hasError: Bool) {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            transcript = text
            hasRecognizedTextThisSession = true
            lastError = nil
        } else if hasError && !hasRecognizedTextThisSession {
            lastError = .engineFailure
        }
        if (hasError || isFinal) && (isListening || isPreparing) {
            stopInternal()
        }
    }

    nonisolated private func handleRecognition(_ result: SFSpeechRecognitionResult?, error: Error?) {
        // Extract Sendable values on the calling queue; the result itself is not Sendable.
        let text = result?.bestTranscription.formattedString
        let isFinal = result?.isFinal ?? false
        let hasError = error != nil
        Task { @MainActor in
            self.receiveRecognition(text: text, isFinal: isFinal, hasError: hasError)
        }
    }

    func stop() {
        stopInternal()
    }

    /// Reset transcript without stopping the engine (used after submitting text).
    func clearTranscript() {
        transcript = ""
    }

    private func stopInternal() {
        startToken = UUID()
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        isPreparing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func normalizedLocaleIdentifier(for locale: Locale) -> String {
        switch ContentLanguage(locale.identifier) {
        case .zhHans: return "zh-CN"
        case .zhHant: return "zh-TW"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .en: return "en-US"
        }
    }

    private static func normalizedLocale(for locale: Locale) -> Locale {
        Locale(identifier: normalizedLocaleIdentifier(for: locale))
    }
}
