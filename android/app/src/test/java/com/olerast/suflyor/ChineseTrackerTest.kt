package com.olerast.suflyor

import com.olerast.suflyor.doc.Paragraph
import com.olerast.suflyor.doc.ScriptDocument
import com.olerast.suflyor.script.ChineseNorm
import com.olerast.suflyor.script.ScriptLayout
import com.olerast.suflyor.script.SpeechLang
import com.olerast.suflyor.track.ScriptTracker
import org.junit.Assert.*
import org.junit.Test

class ChineseTrackerTest {
    private fun doc(text: String) = ScriptDocument("中文试拍", "TEXT", listOf(Paragraph(text)))

    @Test fun chineseScriptIsDetectedWithoutSpaces() {
        assertEquals(SpeechLang.ZH, SpeechLang.detect(doc("用 AI 做内容，先把话说清楚。")))
        assertEquals(listOf("先", "讲", "清", "楚"), ChineseNorm.words("先讲清楚。"))
    }
    @Test fun spokenPricesAndWrittenNumbersAlignToOriginalRanges() {
        val written = ChineseNorm.units("先讲19.9元，再讲1980实战营。")
        val spoken = ChineseNorm.words("先讲十九点九元，再讲一千九百八十实战营。")
        assertEquals(spoken, written.map { it.norm })
        assertEquals(2, written[2].start)
        assertEquals(6, written[2].end)
    }
    @Test fun chineseLayoutPreservesCharacterLocationsAndSentenceAnchors() {
        val text = "先把话说清楚。再按自己的节奏讲。"
        val model = ScriptLayout.build(doc(text), phraseMode = false, lang = SpeechLang.ZH)
        assertEquals(text, model.displayText)
        assertTrue(model.tokens.first().anchor)
        val next = model.tokens.first { it.start == 7 }
        assertTrue(next.anchor)
        assertEquals("再", next.norm)
    }
    @Test fun chineseReadingMovesAndOffScriptHoldsPosition() {
        val model = ScriptLayout.build(doc("做内容先把话说清楚。看着镜头按自己的节奏讲。"), phraseMode = false, lang = SpeechLang.ZH)
        val tracker = ScriptTracker(model.tokens, SpeechLang.ZH)
        tracker.onHypothesis(ChineseNorm.words("做内容先把话说清楚"))
        tracker.onHypothesis(ChineseNorm.words("做内容先把话说清楚"))
        val before = tracker.position
        assertTrue("Chinese reading should move the tracker", before >= 7)
        tracker.onHypothesis(ChineseNorm.words("今天天气真不错我们去吃饭吧"))
        assertEquals(before, tracker.position)
    }
}
