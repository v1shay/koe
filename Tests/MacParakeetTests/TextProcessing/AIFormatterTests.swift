import XCTest
@testable import MacParakeetCore

final class AIFormatterTests: XCTestCase {
    func testDefaultPromptExplicitlyResolvesSpokenSelfCorrections() {
        let prompt = AIFormatter.defaultPromptTemplate

        XCTAssertTrue(prompt.contains("Resolve spoken self-corrections"))
        XCTAssertTrue(prompt.contains("keep the final intended wording"))
        XCTAssertTrue(prompt.contains("I mean"))
    }

    func testEverySmartDefaultResolvesSpokenSelfCorrections() {
        XCTAssertFalse(AIFormatterSmartDefaults.categoryDefaults.isEmpty)
        XCTAssertTrue(AIFormatterSmartDefaults.categoryDefaults.allSatisfy {
            $0.promptTemplate.contains("Resolve spoken self-corrections")
        })
    }
}
