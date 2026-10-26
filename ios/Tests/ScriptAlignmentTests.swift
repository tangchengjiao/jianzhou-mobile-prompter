import XCTest
@testable import JianzhouPrompter

final class ScriptAlignmentTests: XCTestCase {
    func testChineseWithoutSpacesUsesCharactersAndKeepsSourceOffsets() {
        let units = ScriptUnits("先停一下，再继续讲。")
        XCTAssertEqual(String(units.characters), "先停一下再继续讲")
        XCTAssertEqual(units.sourceOffsets[4], 5)
    }
    func testCommonPricesAndCourseNumbersHaveComparableSpokenForms() {
        XCTAssertEqual(String(ScriptUnits("19.9 元，1980 实战营").characters), String(ScriptUnits("十九点九元一千九百八十实战营").characters))
        let units = ScriptUnits("先讲19.9元")
        XCTAssertEqual(units.sourceOffsets[2], 2)
        XCTAssertEqual(units.sourceEnds[2], 6)
    }
    func testPartialTranscriptAdvancesAndOffScriptDoesNotMove() {
        let script = ScriptUnits("做内容先把话说清楚。看着镜头按自己的节奏讲。")
        let aligner = ScriptAligner(script: script)
        let first = aligner.align("做内容先把话说清楚", near: 0)
        XCTAssertTrue(first.matched)
        XCTAssertEqual(first.cursor, 9)
        let off = aligner.align("今天天气真不错我们去吃饭吧", near: first.cursor)
        XCTAssertFalse(off.matched)
        XCTAssertEqual(off.cursor, first.cursor)
    }
    func testRepeatingEarlierSentenceCanReturnToIt() {
        let script = ScriptUnits("做内容先把话说清楚。看着镜头按自己的节奏讲。")
        let match = ScriptAligner(script: script).align("做内容先把话说清楚", near: script.characters.count)
        XCTAssertTrue(match.matched)
        XCTAssertEqual(match.cursor, 9)
    }

    func testPartialWithOneRecognitionSubstitutionStillAdvances() {
        let script = ScriptUnits("我拍视频的时候最怕的不是忘词而是提词没有跟上。")
        let match = ScriptAligner(script: script).align("我拍视频的时侯", near: 0)
        XCTAssertTrue(match.matched)
        XCTAssertGreaterThanOrEqual(match.cursor, 7)
    }

    func testLaterParagraphCannotAutomaticallyJumpButManualSeekCanResumeThere() {
        let prefix = String(repeating: "甲", count: 350)
        let phrase = "把复杂的问题说清楚才是做内容的第一步"
        let script = ScriptUnits(prefix + phrase)
        let match = ScriptAligner(script: script).align(phrase, near: 0)
        XCTAssertFalse(match.matched)
        XCTAssertEqual(match.cursor, 0)
        let manual = ScriptAligner(script: script).align(phrase, near: prefix.count)
        XCTAssertTrue(manual.matched)
        XCTAssertEqual(manual.cursor, script.characters.count)
    }

    func testThreeCharacterPartialDoesNotWaitForSentenceEnd() {
        let match = ScriptAligner(script: ScriptUnits("我拍视频的时候先把想讲的话说清楚")).align("我拍视", near: 0)
        XCTAssertTrue(match.matched)
        XCTAssertEqual(match.cursor, 3)
    }
}
