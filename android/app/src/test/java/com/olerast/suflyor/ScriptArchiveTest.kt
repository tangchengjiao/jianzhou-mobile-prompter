package com.olerast.suflyor

import com.olerast.suflyor.doc.ImportError
import com.olerast.suflyor.doc.ImportException
import com.olerast.suflyor.doc.MarkdownImporter
import com.olerast.suflyor.doc.ScriptArchive
import com.olerast.suflyor.doc.ScriptArchive.Entry
import com.olerast.suflyor.ui.toEditableText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.ByteArrayInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import java.util.zip.ZipInputStream

class ScriptArchiveTest {
    @Test
    fun editedChineseCorpusKeepsOriginalLineBreaksAndMarkdownAfterBackup() {
        val edited = "开场：  我想讲一句话。\n下一句，先停一停。\n\n**这是我改过的重点。**\n[停顿两秒]"
        val doc = MarkdownImporter.parse(edited, "我的口播 · 定稿").copy(sourceText = edited, speechLang = "zh")
        val entry = Entry(doc.title, doc.toEditableText(), doc.speechLang)
        val restored = ScriptArchive.read(archive(listOf(entry))).entries.single()
        assertEquals("我的口播 · 定稿", restored.title)
        assertEquals(edited, restored.text)
        assertEquals("zh", restored.speechLang)
    }

    private fun archive(scripts: List<Entry>): ByteArray =
        ByteArrayOutputStream().also { ScriptArchive.write(scripts, it) }.toByteArray()

    private fun zip(vararg entries: Pair<String, ByteArray>): ByteArray = ByteArrayOutputStream().also { out ->
        ZipOutputStream(out).use { z ->
            for ((name, data) in entries) {
                z.putNextEntry(ZipEntry(name))
                z.write(data)
                z.closeEntry()
            }
        }
    }.toByteArray()

    @Test
    fun roundTripKeepsTitlesTextLanguageAndOrder() {
        val scripts = listOf(
            Entry("Дрон для путешествий", "# Вступление\n\nСегодня **разберём**, как выбрать дрон.\n\n[пауза] И не переплатить."),
            Entry("Second", "Plain English text.", speechLang = "en"),
        )
        val bytes = archive(scripts)
        assertTrue(ScriptArchive.isArchive(bytes))
        val contents = ScriptArchive.read(bytes)
        assertEquals(scripts, contents.entries)
        assertEquals(0, contents.dropped)
        // What the app does with an entry: the Markdown parses back into the same document.
        assertEquals(3, MarkdownImporter.parse(contents.entries[0].text, "t").paragraphs.size)
    }

    @Test
    fun batchTextExportKeepsChineseWordingAndDuplicateTitlesInSeparateFiles() {
        val scripts = listOf(Entry("口播/调整版", "第一句。  \n\n**原样保留**。"), Entry("口播/调整版", "第二份改稿。"))
        val output = ByteArrayOutputStream()
        ScriptArchive.writeText(scripts, output)
        val files = linkedMapOf<String, String>()
        ZipInputStream(ByteArrayInputStream(output.toByteArray())).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                files[entry.name] = zip.readBytes().toString(Charsets.UTF_8)
            }
        }
        assertEquals(listOf("口播 调整版.txt", "口播 调整版 (2).txt"), files.keys.toList())
        assertEquals(scripts.map { it.title + "\n\n" + it.text }, files.values.toList())
    }

    @Test
    fun sameUnsafeAndHiddenTitlesGetDistinctVisibleNames() {
        val bytes = archive(
            listOf(Entry("a/b:c?", "one"), Entry("a/b:c?", "two"), Entry("", "three"), Entry("...", "four"), Entry(".NET notes", "five")),
        )
        val titles = ScriptArchive.read(bytes).entries.map { it.title }
        assertEquals(listOf("a b c", "a b c (2)", "script", "script (2)", "NET notes"), titles)
    }

    @Test
    fun officeDocumentsAndForeignZipsAreNotArchives() {
        assertFalse(ScriptArchive.isArchive(zip("word/document.xml" to "<w/>".toByteArray(), "notes.md" to "x".toByteArray())))
        assertFalse(ScriptArchive.isArchive(zip("mimetype" to "application/vnd.oasis.opendocument.text".toByteArray())))
        assertFalse(ScriptArchive.isArchive(zip("photo.jpg" to ByteArray(10))))
        assertFalse(ScriptArchive.isArchive("not a zip".toByteArray()))
    }

    @Test
    fun onlyTextFilesAreRead() {
        val bytes = zip(
            "folder/one.md" to "first".toByteArray(),
            "__MACOSX/folder/._one.md" to ByteArray(4),
            "picture.png" to ByteArray(100),
            "two.txt" to "second".toByteArray(),
        )
        assertEquals(listOf(Entry("one", "first"), Entry("two", "second")), ScriptArchive.read(bytes).entries)
    }

    @Test
    fun tooLongScriptIsDroppedAndCounted() {
        // 2 MB of spaces compresses to a few KB and is longer than any script the app takes.
        val bytes = zip("big.md" to ByteArray(2 * 1024 * 1024) { ' '.code.toByte() }, "ok.md" to "fine".toByteArray())
        val contents = ScriptArchive.read(bytes)
        assertEquals(listOf(Entry("ok", "fine")), contents.entries)
        assertEquals(1, contents.dropped)
    }

    @Test
    fun zipBombIsRefusedEvenInSkippedFiles() {
        // 40 MB of zeros in a file that is not a script still has to be inflated to be skipped.
        val bytes = zip("a.md" to "x".toByteArray(), "junk.bin" to ByteArray(40 * 1024 * 1024))
        val error = runCatching { ScriptArchive.read(bytes) }.exceptionOrNull()
        assertTrue("$error", error is ImportException && error.error == ImportError.ZipTooLarge)
    }
}
