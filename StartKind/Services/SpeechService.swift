import Foundation
import Speech
import AVFoundation

enum SpeechError: LocalizedError {
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

/// On-device speech-to-text for voice capture. Uses the Speech framework with
/// on-device recognition where supported so Free voice input works offline.
@MainActor
final class SpeechService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var isMicrophoneAuthorized = false
    @Published var transcript = ""

    private let audioEngine = AVAudioEngine()
    private let preferredLocale: Locale
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        preferredLocale = locale
    }

    /// Build the recognizer only once speech access has actually been granted.
    /// One created earlier — while authorization was still `.notDetermined` —
    /// keeps reporting `isAvailable == false` after the grant, which made the
    /// first tap after authorising silently do nothing.
    private func makeRecognizer() -> SFSpeechRecognizer? {
        if let recognizer, recognizer.isAvailable { return recognizer }
        let candidates = [preferredLocale, Locale(identifier: "en-US")]
        for locale in candidates {
            if let candidate = SFSpeechRecognizer(locale: locale), candidate.isAvailable {
                recognizer = candidate
                return candidate
            }
        }
        return nil
    }

    func refreshAuthorizationState() {
        isAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        isMicrophoneAuthorized = AVAudioApplication.shared.recordPermission == .granted
    }

    func start() async throws {
        try await ensureAuthorization()
        guard let recognizer = makeRecognizer() else {
            throw SpeechError.notAvailable
        }
        guard configureAudioSession() else { throw SpeechError.notAvailable }

        task?.cancel()
        task = nil
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw SpeechError.notAvailable
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechError.engineFailure
        }

        task = recognizer.recognitionTask(with: request, resultHandler: handleRecognition)
        isListening = true
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
    nonisolated private func handleRecognition(_ result: SFSpeechRecognitionResult?, error: Error?) {
        // Extract Sendable values on the calling queue; the result itself is not Sendable.
        let text = result?.bestTranscription.formattedString
        let isFinal = result?.isFinal ?? false
        let hasError = error != nil
        Task { @MainActor in
            if let text { self.transcript = text }
            if hasError || isFinal { self.stopInternal() }
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
