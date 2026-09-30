import Foundation
@preconcurrency import Vision
import CoreGraphics

protocol AdminQuickReaderOCRRequestPerforming: Sendable {
    func performTextRecognition(
        image: CGImage,
        recognitionLanguages: [String],
        completion: @Sendable @escaping (Result<String, Error>) -> Void
    )
}

protocol AdminQuickReaderTextRecognizing: Sendable {
    func recognizeText(from image: CGImage, language: String) async throws -> String
}

private final class AdminQuickReaderOCRCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private let completion: @Sendable (Result<String, Error>) -> Void

    init(completion: @Sendable @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
    }

    func complete(with result: Result<String, Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()
        completion(result)
    }
}

struct VisionAdminQuickReaderOCRRequestPerformer: Sendable, AdminQuickReaderOCRRequestPerforming {
    func performTextRecognition(
        image: CGImage,
        recognitionLanguages: [String],
        completion: @Sendable @escaping (Result<String, Error>) -> Void
    ) {
        let completionGate = AdminQuickReaderOCRCompletionGate(completion: completion)

        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    completionGate.complete(with: .failure(error))
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                completionGate.complete(with: .success(lines.joined(separator: "\n")))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages

            do {
                let handler = VNImageRequestHandler(cgImage: image)
                try handler.perform([request])
            } catch {
                completionGate.complete(with: .failure(error))
            }
        }
    }
}

struct VisionAdminQuickReaderOCRService: Sendable, AdminQuickReaderTextRecognizing {
    private let performer: AdminQuickReaderOCRRequestPerforming

    init(performer: AdminQuickReaderOCRRequestPerforming = VisionAdminQuickReaderOCRRequestPerformer()) {
        self.performer = performer
    }

    func recognizeText(from image: CGImage, language: String) async throws -> String {
        let recognitionLanguages = Self.recognitionLanguages(for: language)
        return try await withCheckedThrowingContinuation { continuation in
            let completionGate = AdminQuickReaderOCRCompletionGate { result in
                continuation.resume(with: result)
            }
            performer.performTextRecognition(
                image: image,
                recognitionLanguages: recognitionLanguages
            ) { result in
                completionGate.complete(with: result)
            }
        }
    }

    static func recognitionLanguages(for language: String) -> [String] {
        switch ContentLanguage(language) {
        case .zhHans: return ["zh-Hans", "en-US"]
        case .zhHant: return ["zh-Hant", "en-US"]
        case .ja: return ["ja-JP", "en-US"]
        case .ko: return ["ko-KR", "en-US"]
        case .en: return ["en-US"]
        }
    }
}
