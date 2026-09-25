import CoreGraphics
import XCTest
@testable import StartKind

final class AdminQuickReaderOCRServiceTests: XCTestCase {
    private func makeTinyImage() -> CGImage {
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testRecognizeTextUsesEnUSLanguage() async throws {
        let performer = StubVisionRequester(result: "First line\nSecond line")
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        let text = try await service.recognizeText(from: makeTinyImage(), language: "en")

        XCTAssertEqual(text, "First line\nSecond line")
        XCTAssertEqual(performer.recordedLanguages, ["en-US"])
    }

    func testRecognizeTextUsesChinesePlusEnglishLanguage() async throws {
        let performer = StubVisionRequester(result: "第一行\n第二行")
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        _ = try await service.recognizeText(from: makeTinyImage(), language: "zh-Hans")

        XCTAssertEqual(performer.recordedLanguages, ["zh-Hans", "en-US"])
    }

    func testRecognizeTextUsesJapanesePlusEnglishLanguage() async throws {
        let performer = StubVisionRequester(result: "一行目\n二行目")
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        _ = try await service.recognizeText(from: makeTinyImage(), language: "ja")

        XCTAssertEqual(performer.recordedLanguages, ["ja-JP", "en-US"])
    }

    func testRecognizeTextCompletesWhenCallbackIsOffMainThread() async throws {
        let performer = StubVisionRequester(result: "From background callback")
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        let text = try await service.recognizeText(from: makeTinyImage(), language: "en")

        XCTAssertEqual(text, "From background callback")
        XCTAssertTrue(performer.didCompleteOffMainQueue)
    }

    func testRecognizeTextReturnsEmptyOutput() async throws {
        let performer = StubVisionRequester(result: "")
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        let text = try await service.recognizeText(from: makeTinyImage(), language: "en")

        XCTAssertTrue(text.isEmpty)
    }

    func testRecognizeTextPropagatesPerformerErrors() async {
        let expectedError = TestOCRServiceError.simulated
        let performer = StubVisionRequester(result: expectedError)
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        do {
            _ = try await service.recognizeText(from: makeTinyImage(), language: "en")
            XCTFail("Expected OCR to fail")
        } catch {
            XCTAssertEqual((error as? TestOCRServiceError), expectedError)
        }
    }

    func testRecognizeTextIgnoresDuplicateCallbacks() async throws {
        let performer = StubVisionRequester(results: [
            .success("First callback"),
            .failure(TestOCRServiceError.simulated)
        ])
        let service = VisionAdminQuickReaderOCRService(performer: performer)

        let text = try await service.recognizeText(from: makeTinyImage(), language: "en")

        XCTAssertEqual(text, "First callback")
    }
}

private final class StubVisionRequester: AdminQuickReaderOCRRequestPerforming, @unchecked Sendable {
    private let lockQueue = DispatchQueue(label: "admin-reader-stub")
    private let results: [Result<String, Error>]
    private var recordedLanguagesValue: [String] = []
    private var didCompleteOffMainQueueValue = false

    init(result: String) {
        self.results = [.success(result)]
    }

    init(result: Error) {
        self.results = [.failure(result)]
    }

    init(results: [Result<String, Error>]) {
        self.results = results
    }

    func performTextRecognition(
        image: CGImage,
        recognitionLanguages: [String],
        completion: @Sendable @escaping (Result<String, Error>) -> Void
    ) {
        lockQueue.sync {
            recordedLanguagesValue = recognitionLanguages
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.lockQueue.sync {
                self.didCompleteOffMainQueueValue = !Thread.isMainThread
            }
            for result in self.results {
                completion(result)
            }
        }
    }

    var recordedLanguages: [String] {
        lockQueue.sync { self.recordedLanguagesValue }
    }

    var didCompleteOffMainQueue: Bool {
        lockQueue.sync { self.didCompleteOffMainQueueValue }
    }
}

private enum TestOCRServiceError: Error {
    case simulated
}
