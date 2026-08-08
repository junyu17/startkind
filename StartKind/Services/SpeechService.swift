import Foundation
import Speech
import AVFoundation

enum SpeechError: LocalizedError {
    case notAuthorized, notAvailable, engineFailure

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Microphone or speech recognition permission was not granted."
        case .notAvailable: return "Speech recognition isn't available right now."
        case .engineFailure: return "Couldn't start the audio engine."
        }
    }
}

/// On-device speech-to-text for voice capture. Uses the Speech framework with
/// on-device recognition where supported so Free voice input works offline.
@MainActor
final class SpeechService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isAuthorized = false
    @Published var transcript = ""

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    nonisolated func requestAuthorization() {
        // Use the completion-handler form directly (the async bridge is not
        // available in this toolchain). The handler runs on a background queue,
        // so it must be nonisolated and hop to MainActor to update state.
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = (status == .authorized)
            }
        }
    }

    func start() throws {
        guard isAuthorized, let recognizer, recognizer.isAvailable else {
            throw SpeechError.notAvailable
        }
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
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
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
    }
}
