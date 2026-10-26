import XCTest
@testable import JianzhouPrompter

final class ScriptFollowingSessionTests: XCTestCase {
    func testPhraseFromLaterParagraphDoesNotSkipUnreadText() {
        let intro = "今天先讲第一点"
        let unread = "这一段还没有读完我们先看一个具体例子再解释为什么要这样做"
        let later = "把复杂的问题说清楚才是做内容的第一步"
        let script = ScriptUnits(intro + unread + later)
        var follower = ScriptFollowingSession(); follower.reset(at: intro.count)
        let result = follower.follow(later, script: script, near: intro.count)
        XCTAssertFalse(result.matched)
        XCTAssertEqual(result.cursor, intro.count)
    }

    func testDuplicateHypothesesDoNotWalkIntoRepeatedWordingBelow() {
        let phrase = "先把事情讲清楚"
        let script = ScriptUnits(phrase + "这是中间的解释" + phrase)
        var follower = ScriptFollowingSession(); follower.reset(at: 0)
        let first = follower.follow(phrase, script: script, near: 0)
        XCTAssertEqual(first.cursor, phrase.count)
        var cursor = first.cursor
        for hypothesis in [phrase, phrase + "。", phrase, phrase + "！"] {
            cursor = follower.follow(hypothesis, script: script, near: cursor).cursor
            XCTAssertEqual(cursor, phrase.count)
        }
    }

    func testSameLengthRecognitionRevisionsDoNotAddForwardDistance() {
        let phrase = "先把事情讲清楚"
        let script = ScriptUnits(phrase + "这是中间的解释" + phrase)
        var follower = ScriptFollowingSession(); follower.reset(at: 0)
        var cursor = 0
        for hypothesis in [phrase, "先把事请讲清楚", phrase, "先把事情讲清处"] {
            cursor = follower.follow(hypothesis, script: script, near: cursor).cursor
            XCTAssertEqual(cursor, phrase.count)
        }
    }

    func testContinuousReadingAndANewRecognitionTaskKeepFollowing() {
        let first = "我拍视频的时候先把想讲的话说清楚"
        let second = "然后看着镜头按照自己的节奏继续讲"
        let script = ScriptUnits(first + second)
        var follower = ScriptFollowingSession(); follower.reset(at: 0)
        var cursor = 0
        for count in [5, 10, first.count] {
            let match = follower.follow(String(first.prefix(count)), script: script, near: cursor)
            XCTAssertTrue(match.matched)
            cursor = match.cursor
            XCTAssertEqual(cursor, count)
        }
        follower.reset(at: cursor)
        let match = follower.follow(String(second.prefix(6)), script: script, near: cursor)
        XCTAssertTrue(match.matched)
        XCTAssertEqual(match.cursor, first.count + 6)
    }
}
