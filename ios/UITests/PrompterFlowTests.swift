import XCTest

final class PrompterFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testEditingPersistsAndPreparationIsReachable() {
        let app = XCUIApplication()
        app.launch()
        let body = app.textViews["稿件正文"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        body.tap()
        body.typeText("\n\n这是一次试拍。")
        let done = app.buttons["完成输入"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        app.buttons["prepare-prompt"].tap()
        XCTAssertTrue(app.navigationBars["提词准备"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["启动系统画中画"].exists)
        app.terminate()
        app.launch()
        let restored = app.textViews["稿件正文"]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue((restored.value as? String ?? "").contains("这是一次试拍"))
    }

    func testCountdownCanBeCancelledDuringReading() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["prepare-prompt"].waitForExistence(timeout: 15))
        app.buttons["prepare-prompt"].tap()
        app.buttons["先全屏练一遍"].tap()
        let play = app.buttons["播放提词"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let cancel = app.buttons["取消倒计时"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        let paused = app.staticTexts["已暂停 · 点句子定位"]
        XCTAssertTrue(paused.exists)
    }

    func testSaveCopyShowsEditedWordingAndExportOpensFiles() {
        let app = XCUIApplication()
        app.launch()
        let body = app.textViews["稿件正文"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        let wording = body.value as? String ?? ""
        app.buttons["保存副本"].tap()
        XCTAssertTrue(app.textFields["稿件标题"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textFields["稿件标题"].value as? String ?? "").contains(" · "))
        XCTAssertEqual(app.textViews["稿件正文"].value as? String ?? "", wording)
        app.buttons["导出 TXT"].tap()
        // The Files picker lives in a separate process on iOS 27. XCTest can tap its visible Save
        // control on the fixed iPhone 13 simulator, while querying its accessibility tree stalls.
        Thread.sleep(forTimeInterval: 1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 338, dy: 85)).tap()
        let saved = app.alerts["稿件已导出"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        saved.buttons["知道了"].tap()
        XCTAssertTrue(app.buttons["导出 TXT"].waitForExistence(timeout: 5))
    }
}
