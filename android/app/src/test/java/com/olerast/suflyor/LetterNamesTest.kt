package com.olerast.suflyor

import com.olerast.suflyor.doc.Paragraph
import com.olerast.suflyor.doc.ScriptDocument
import com.olerast.suflyor.script.ScriptLayout
import com.olerast.suflyor.script.ScriptModel
import com.olerast.suflyor.script.TextNorm
import com.olerast.suflyor.script.biasWords
import com.olerast.suflyor.speech.hotwordList
import com.olerast.suflyor.track.ScriptTracker
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Names of programs written in Cyrillic, as in a script about the author's projects: letter names through hyphens
 * ("Би-ту-би", "Эй-Ай") or glued ("БиТуБи"), and a name the recognizer hears with reduced vowels ("Олераст").
 * The heard lines are what the small Russian model printed for them in the simulation of 2026-10-21.
 */
class LetterNamesTest {
    private fun model(vararg lines: String): ScriptModel =
        ScriptLayout.build(ScriptDocument("t", "test", lines.map { Paragraph(it) }), phraseMode = true)

    private fun script(projects: String) = model(
        "Привет, на связи Олераст, и сегодня разберём, как я работаю с нейросетями.",
        "Это мои $projects проекты.",
        "Каждый из них я собрал за выходные и проверил на себе.",
    )

    /** Reads the first line exactly, then [heard] for the second; returns how many words the tracker lags behind. */
    private fun lagAfterSecondLine(m: ScriptModel, heard: String): Int {
        val words = m.tokens.filter { it.spoken }.map { it.norm }
        val t = ScriptTracker(m.tokens)
        val history = mutableListOf<String>()
        val secondLine = words.indexOf("каждый")
        for (w in words.take(words.indexOf("это")) + TextNorm.words(heard)) {
            history += w
            t.onHypothesis(history.takeLast(16))
        }
        return secondLine - t.position
    }

    @Test
    fun hyphenatedLetterNamesHeardGlued() {
        val m = script("Би-ту-би Эй-Ай СааС")
        assertEquals(0, lagAfterSecondLine(m, "это мои битуби эйай саас проекты"))
    }

    @Test
    fun hyphenatedLetterNamesHeardWithWrongVowels() {
        val m = script("Би-ту-би Эй-Ай СааС")
        assertEquals(0, lagAfterSecondLine(m, "это мои би тубе эй ай саас проекты"))
    }

    @Test
    fun gluedLetterNamesHeardApart() {
        val m = script("БиТуБи ЭйАй СааС")
        assertEquals(0, lagAfterSecondLine(m, "это мои би ту би эй ай саас проекты"))
        assertEquals(0, lagAfterSecondLine(m, "это мои би тубе эйай саас проекты"))
    }

    @Test
    fun regroupsHeardWordsBothWays() {
        val chains = mapOf("битуби" to listOf("би", "ту", "би"), "биту" to listOf("би", "ту"), "туби" to listOf("ту", "би"))
        val hyphenated = setOf("это", "мои", "би", "ту")
        assertEquals("это мои би ту би".split(" "), TextNorm.regroupLetterNames("это мои битуби".split(" "), hyphenated, chains))
        // The last word is still being spoken: "биту" of "битуби".
        assertEquals("это мои би ту".split(" "), TextNorm.regroupLetterNames("это мои биту".split(" "), hyphenated, chains))
        val glued = setOf("это", "мои", "битуби")
        assertEquals("это мои битуби".split(" "), TextNorm.regroupLetterNames("это мои би ту би".split(" "), glued, emptyMap()))
        assertEquals("это мои битуби".split(" "), TextNorm.regroupLetterNames("это мои би тубе".split(" "), glued, emptyMap()))
        // Script words are never glued together: "и я" stays two words even if "ия" were a script word.
        assertEquals("и я".split(" "), TextNorm.regroupLetterNames("и я".split(" "), setOf("и", "я", "ия"), emptyMap()))
    }

    @Test
    fun letterChainsAreMarkedAndBiased() {
        val m = model("Это мои Би-ту-би Эй-Ай СааС проекты, кто-то скажет, что из-за них кое-где шумно.")
        val chained = m.tokens.filter { it.hyphenNext }.map { it.norm }
        assertEquals(listOf("би", "ту", "эй"), chained)
        val bias = m.biasWords()
        assertTrue(bias.containsAll(listOf("битуби", "эйай", "саас", "проекты")))
        assertFalse(bias.any { it in setOf("ктото", "изза", "коегде") })
        val hotwords = hotwordList(m.lang, bias).split("/")
        assertTrue(hotwords.containsAll(listOf("битуби", "эйай")))
    }

    @Test
    fun reducedVowelsMatch() {
        assertTrue(TextNorm.similarity("алираст", "олераст") >= ScriptTracker.MATCH_SIM)
        assertTrue(TextNorm.similarity("маскве", "москве") >= ScriptTracker.MATCH_SIM)

        val m = script("Би-ту-би Эй-Ай СааС")
        val words = m.tokens.filter { it.spoken }.map { it.norm }
        val t = ScriptTracker(m.tokens)
        val history = words.take(words.indexOf("олераст")).toMutableList()
        t.onHypothesis(history)
        history += "алираст"
        t.onHypothesis(history)
        assertEquals(words.indexOf("олераст") + 1, t.position)
    }

    @Test
    fun ordinaryWordsDoNotMatchThroughVowels() {
        // One reduced vowel plus another letter ("палата"/"полета", "береза"/"бирюза"), short words, other letters.
        val pairs = listOf(
            "палата" to "полета", "береза" to "бирюза", "ровно" to "равна", "сам" to "сом", "дам" to "дом",
            "молоко" to "малина", "голова" to "солома",
        )
        for ((a, b) in pairs) {
            assertTrue("$a/$b", TextNorm.similarity(a, b) < ScriptTracker.MATCH_SIM)
        }
    }
}
