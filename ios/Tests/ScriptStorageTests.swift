import Foundation
import XCTest
@testable import JianzhouPrompter

final class ScriptStorageTests: XCTestCase {
    @MainActor func testEditedChineseCopyKeepsItsWordingAndSelectionAfterRelaunch() {
        let suite = "jianzhou.prompter.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = PrompterModel(defaults: defaults)
        model.update(title: "我的口播", text: "开场：  这段我改过。\n\n第二段，停一下。")
        let original = model.selected
        model.saveCopy()
        XCTAssertNotEqual(model.selected.id, original.id)
        XCTAssertEqual(model.selected.text, original.text)
        model.update(text: "副本的新一句。")

        let restored = PrompterModel(defaults: defaults)
        XCTAssertEqual(restored.scripts.count, 2)
        XCTAssertEqual(restored.selected.text, "副本的新一句。")
        XCTAssertEqual(restored.scripts.first(where: { $0.id == original.id })?.text, original.text)
        restored.select(original)
        XCTAssertEqual(PrompterModel(defaults: defaults).selected.id, original.id)
    }

    @MainActor func testExportSnapshotKeepsTheEditedTextAndSafeFilename() {
        let script = PromptScript(title: "我的/口播", text: "第一句。  \n\n**修改后的重点**。")
        let snapshot = PromptExport(script: script, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snapshot.text, "我的/口播\n\n第一句。  \n\n**修改后的重点**。")
        XCTAssertTrue(snapshot.filename.hasPrefix("我的 口播-"))
        XCTAssertTrue(snapshot.filename.hasSuffix(".txt"))
        XCTAssertFalse(snapshot.filename.contains("/"))
    }

    func testExportWritesReadableCopiesWithoutOverwriting() throws {
        let documents = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: documents) }
        let snapshot = PromptExport(script: PromptScript(title: "调过的口播", text: "第一句，保留原来的停顿。"))
        let first = try PromptFileStore.write(snapshot, in: documents)
        let second = try PromptFileStore.write(snapshot, in: documents)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), snapshot.text)
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), snapshot.text)
    }
}
