package com.olerast.suflyor.script

import java.text.Normalizer
import kotlin.math.abs

/**
 * Word normalization and fuzzy comparison tuned for Russian speech recognition output. English speech uses
 * [EnglishNorm]; [SpeechLang] picks one. Everything here is Russian behaviour and must not change for English's sake.
 */
object TextNorm {
    /** Letters, digits and combining marks (stress marks like "замо́к" stay inside the word). */
    val WORD = Regex("[\\p{L}\\p{N}\\p{M}]+")

    /**
     * Function words. The Latin entries at the end are never reached: [normalizeWord] transliterates Latin before the
     * lookup ("the" becomes "те"). They stay so Russian weights stay exactly as they are; English stop words live in
     * [EnglishNorm.STOP].
     */
    private val STOP = setOf(
        "и", "в", "во", "не", "на", "я", "что", "с", "со", "а", "это", "как", "то", "по", "но", "к", "ко", "у",
        "из", "за", "о", "об", "же", "так", "вы", "мы", "он", "она", "оно", "они", "ты", "его", "ее", "их", "им",
        "ей", "мне", "меня", "мой", "моя", "мое", "мои", "бы", "ли", "да", "нет", "от", "до", "для", "при", "про",
        "без", "над", "под", "все", "вот", "там", "тут", "уже", "еще", "или", "если", "чем", "тоже", "ну", "есть",
        "был", "была", "было", "были", "быть", "этот", "эта", "эти", "тот", "та", "те", "вас", "нас", "вам", "нам",
        "the", "a", "an", "and", "of", "to", "in", "is", "it", "on", "for", "at", "by",
    )

    /** Hesitations that speech recognizers emit and that never appear in a script. */
    val FILLERS = setOf("э", "ээ", "эээ", "эм", "эмм", "мм", "ммм", "хм", "ага", "угу")

    fun normalizeWord(raw: String): String {
        val sb = StringBuilder(raw.length)
        for (ch in Normalizer.normalize(raw, Normalizer.Form.NFC)) {
            val type = Character.getType(ch)
            if (type == Character.NON_SPACING_MARK.toInt() || type == Character.ENCLOSING_MARK.toInt() ||
                type == Character.COMBINING_SPACING_MARK.toInt()
            ) continue
            val c = ch.lowercaseChar()
            sb.append(if (c == 'ё') 'е' else c)
        }
        val s = sb.toString()
        return if (s.any { it in 'a'..'z' }) translit(s) else s
    }

    fun words(text: String): List<String> =
        WORD.findAll(text).map { normalizeWord(it.value) }.filter { it.isNotEmpty() }.toList()

    fun isNumber(norm: String): Boolean = norm.isNotEmpty() && norm.all { it.isDigit() }

    /** How much a matched word proves the position: function words prove little, long words a lot, numbers nothing. */
    fun weight(norm: String, wasLatin: Boolean = false): Float = when {
        isNumber(norm) -> 0f
        norm in STOP -> 0.2f
        norm.length <= 2 -> 0.3f
        norm.length == 3 -> 0.6f
        wasLatin -> 0.5f
        else -> 1f
    }

    fun similarity(a: String, b: String): Float {
        if (a == b) return 1f
        if (a.isEmpty() || b.isEmpty()) return 0f
        val minLen = minOf(a.length, b.length)
        val maxLen = maxOf(a.length, b.length)
        if (maxLen <= 2) return 0f
        var p = 0
        while (p < minLen && a[p] == b[p]) p++
        // Russian endings: "сделал"/"сделали", "дома"/"домой".
        if (p >= 5) return 0.92f
        if (minLen >= 4 && p >= 4 && p >= minLen - 2) return 0.88f
        if (minLen >= 4 && p >= 3 && p >= minLen - 1) return 0.8f
        if (a.length == b.length && a.length >= REDUCED_MIN_LEN) reducedSimilarity(a, b)?.let { return it }
        return 1f - levenshtein(a, b).toFloat() / maxLen
    }

    /** Words this long are rarely two different words apart by unstressed vowels alone. */
    private const val REDUCED_MIN_LEN = 6

    /** Unstressed о and а, е and и sound the same: the recognizer hears "алираст" for "Олераст". */
    private fun reducedPair(x: Char, y: Char): Boolean =
        (x == 'о' && y == 'а') || (x == 'а' && y == 'о') || (x == 'е' && y == 'и') || (x == 'и' && y == 'е')

    /**
     * Two words of the same length that differ only in reduced vowels ([reducedPair]), each swap costing half a
     * letter: "алираст"/"олераст" 0.86. Null if any other letter differs ("палата"/"полета" stays at 0.67).
     */
    private fun reducedSimilarity(a: String, b: String): Float? {
        var swaps = 0
        for (k in a.indices) {
            if (a[k] == b[k]) continue
            if (!reducedPair(a[k], b[k])) return null
            swaps++
        }
        return 1f - 0.5f * swaps / a.length
    }

    /**
     * Recognized words regrouped to fit a script that spells letter names ("Би-ту-би" as "би ту би", or glued
     * "БиТуБи" as "битуби"): the recognizer prints either form whatever the script says.
     * - A heard word that is not a script word but a glued run of a hyphen chain (exactly, or one letter off) is split
     *   into the chain's parts: "битуби" becomes "би ту би", "туби" becomes "ту би".
     * - Two to four heard short words, none of them a script word, that glued give a script word (exactly, or one
     *   letter off from five letters on) become that word: "би ту би" and "би тубе" become "битуби".
     * @param chains every glued run of two or more parts of the script's hyphen chains, with its parts.
     */
    fun regroupLetterNames(hyp: List<String>, vocab: Set<String>, chains: Map<String, List<String>>): List<String> {
        if (hyp.size < 2 && chains.isEmpty()) return hyp
        var out: MutableList<String>? = null
        var i = 0
        while (i < hyp.size) {
            val w = hyp[i]
            if (w in vocab) {
                out?.add(w)
                i++
                continue
            }
            val parts = if (w.length >= 4) chains[w] ?: chains.entries.firstOrNull { nearGlued(w, it.key) }?.value else null
            if (parts != null) {
                if (out == null) out = hyp.subList(0, i).toMutableList()
                out += parts
                i++
                continue
            }
            val joined = joinAt(hyp, i, vocab)
            if (joined != null) {
                if (out == null) out = hyp.subList(0, i).toMutableList()
                out += joined.first
                i += joined.second
                continue
            }
            out?.add(w)
            i++
        }
        return out ?: hyp
    }

    /** The script word that two to four heard short words starting at [i] spell together, and how many words that is. */
    private fun joinAt(hyp: List<String>, i: Int, vocab: Set<String>): Pair<String, Int>? {
        for (n in minOf(4, hyp.size - i) downTo 2) {
            val run = hyp.subList(i, i + n)
            // Letter names are short; the last one may be heard with a wrong vowel ("тубе").
            if (run.withIndex().any { (k, p) -> p.length > (if (k == n - 1) 4 else 3) || p in vocab || p.any { it !in 'а'..'я' } }) continue
            val glued = run.joinToString("")
            if (glued.length < 4) continue
            if (glued in vocab) return glued to n
            if (glued.length < 5) continue
            val near = vocab.firstOrNull { nearGlued(glued, it) && it.length >= 5 }
            if (near != null) return near to n
        }
        return null
    }

    /** Same length or one letter more or less, at most one edit apart. */
    private fun nearGlued(a: String, b: String): Boolean =
        abs(a.length - b.length) <= 1 && a[0] == b[0] && b.length >= 4 && levenshtein(a, b) <= 1

    fun levenshtein(a: String, b: String): Int {
        var prev = IntArray(b.length + 1) { it }
        var cur = IntArray(b.length + 1)
        for (i in 1..a.length) {
            cur[0] = i
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                cur[j] = minOf(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            val t = prev
            prev = cur
            cur = t
        }
        return prev[b.length]
    }

    private val DIGRAPHS = listOf(
        "tion" to "шн", "sch" to "ш", "igh" to "ай", "you" to "ю", "sh" to "ш", "ch" to "ч", "th" to "т",
        "ph" to "ф", "ck" to "к", "qu" to "кв", "kh" to "х", "zh" to "ж", "ts" to "ц", "oo" to "у", "ee" to "и",
        "ea" to "и", "ou" to "ау", "ay" to "ей", "ey" to "ей", "ai" to "ей", "oa" to "о", "ew" to "ью", "ow" to "оу",
        "yo" to "йо", "yu" to "ю", "ya" to "я", "wh" to "в", "gh" to "г",
    )
    private val SINGLE = mapOf(
        'a' to "а", 'b' to "б", 'c' to "к", 'd' to "д", 'e' to "е", 'f' to "ф", 'g' to "г", 'h' to "х", 'i' to "и",
        'j' to "дж", 'k' to "к", 'l' to "л", 'm' to "м", 'n' to "н", 'o' to "о", 'p' to "п", 'q' to "к", 'r' to "р",
        's' to "с", 't' to "т", 'u' to "у", 'v' to "в", 'w' to "в", 'x' to "кс", 'y' to "и", 'z' to "з",
    )

    /**
     * Rough Latin-to-Cyrillic reading so "YouTube" can match what a Russian recognizer hears ("ютуб").
     * Only for Latin words in Russian scripts; an English script is normalized by [EnglishNorm] without it.
     */
    fun translit(latin: String): String {
        var s = latin
        if (s.length > 3 && s.endsWith("e") && s[s.length - 2] !in "aeiouy") s = s.dropLast(1)
        val sb = StringBuilder()
        var i = 0
        outer@ while (i < s.length) {
            for ((from, to) in DIGRAPHS) {
                if (s.startsWith(from, i)) {
                    sb.append(to)
                    i += from.length
                    continue@outer
                }
            }
            val ch = s[i]
            sb.append(SINGLE[ch] ?: ch.toString())
            i++
        }
        return sb.toString()
    }
}
