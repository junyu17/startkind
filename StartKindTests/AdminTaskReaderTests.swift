import XCTest
@testable import StartKind

final class AdminTaskReaderTests: XCTestCase {
    let reader = AdminTaskReader()

    func testExtractsAmountAndType() {
        let result = reader.parse(text: "Your bill of $129.50 is due 12/15/2026", language: "en")
        XCTAssertEqual(result.artifactType, .bill)
        XCTAssertNotNil(result.amount)
        XCTAssertTrue(result.amount!.contains("129"))
    }

    func testExtractsDueDate() {
        let result = reader.parse(text: "Amount $50 due 12/15/2026", language: "en")
        XCTAssertNotNil(result.dueDate)
    }

    func testExtractsPhone() {
        let result = reader.parse(text: "Call the clinic at 555-123-4567", language: "en")
        XCTAssertNotNil(result.contact)
        XCTAssertTrue(result.contact!.contains("555"))
    }

    func testExtractsURL() {
        let result = reader.parse(text: "Pay at https://pay.example.com/bill", language: "en")
        XCTAssertNotNil(result.linkOrPhone)
        XCTAssertTrue(result.linkOrPhone!.contains("example.com"))
    }

    func testExtractsEmailContact() {
        let result = reader.parse(text: "Reply to support@acme.com about your bill", language: "en")
        XCTAssertNotNil(result.contact)
        XCTAssertTrue(result.contact!.contains("acme.com"))
    }

    func testDetectsInsuranceType() {
        let result = reader.parse(text: "Your insurance claim policy", language: "en")
        XCTAssertEqual(result.artifactType, .insurance)
    }

    func testMissingDueDateReported() {
        let result = reader.parse(text: "insurance claim policy number", language: "en")
        XCTAssertTrue(result.missingInfo.contains(where: { $0.lowercased().contains("due") }))
    }

    func testProducesOneNextStep() {
        let result = reader.parse(text: "bill $50", language: "en")
        XCTAssertFalse(result.oneNextStep.step.isEmpty)
        XCTAssertFalse(result.oneNextStep.stopCondition.isEmpty)
    }

    func testConfidenceInRange() {
        let result = reader.parse(text: "bill $50 due 1/1/2026 call 555-555-5555", language: "en")
        XCTAssertTrue((0...1).contains(result.confidence))
    }

    func testMissingInfoForBillWithoutAmount() {
        let result = reader.parse(text: "your bill is due soon", language: "en")
        XCTAssertTrue(result.missingInfo.contains(where: { $0.lowercased().contains("amount") }))
    }
}
