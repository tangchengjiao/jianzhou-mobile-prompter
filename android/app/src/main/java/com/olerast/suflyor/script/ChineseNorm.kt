package com.olerast.suflyor.script

/** Mandarin comparison units, preserving original UTF-16 ranges for display. */
object ChineseNorm {
    val WORD = Regex("\\p{IsHan}|[A-Za-z]+|[0-9]+(?:\\.[0-9]+)?")
    val FILLERS = setOf("嗯", "呃", "啊")
    private val common = setOf("的", "了", "是", "我", "你", "在", "个", "这", "那", "就", "也", "和")
    data class Unit(val norm: String, val start: Int, val end: Int)

    fun normalize(raw: String): String = raw.lowercase().replace('两', '二').replace('〇', '零')
    fun units(text: String): List<Unit> = WORD.findAll(text).flatMap { match ->
        val raw = match.value
        val numeric = raw.firstOrNull()?.isDigit() == true
        val normalized = normalize(if (numeric) spokenNumber(raw) else raw)
        if (numeric) normalized.map { Unit(it.toString(), match.range.first, match.range.last + 1) }.asSequence()
        else sequenceOf(Unit(normalized, match.range.first, match.range.last + 1))
    }.toList()
    fun words(text: String): List<String> = units(text).map { it.norm }
    fun weight(norm: String): Float = when (norm) { in FILLERS -> 0f; in common -> 0.35f; else -> 1f }

    fun spokenNumber(raw: String): String {
        val parts = raw.split('.')
        val digits = "零一二三四五六七八九"
        fun readDigits(text: String) = text.mapNotNull { it.digitToIntOrNull()?.let(digits::get) }.joinToString("")
        fun underTenThousand(n: Int): String {
            val values = intArrayOf(1000, 100, 10, 1)
            val names = arrayOf("千", "百", "十", "")
            val result = StringBuilder()
            var pendingZero = false
            for (i in values.indices) {
                val unit = values[i]
                val d = n / unit % 10
                if (d > 0) {
                    if (pendingZero) { result.append('零'); pendingZero = false }
                    if (!(unit == 10 && d == 1 && result.isEmpty())) result.append(digits[d])
                    result.append(names[i])
                } else if (result.isNotEmpty() && n % unit != 0) pendingZero = true
            }
            return result.toString()
        }
        val whole = parts[0]
        val number = whole.toIntOrNull()
        var result = when {
            whole.length > 5 || (whole.length > 1 && whole.startsWith('0')) -> readDigits(whole)
            number == null || number == 0 -> "零"
            number >= 10000 -> {
                val rest = number % 10000
                digits[number / 10000] + "万" + if (rest > 0) (if (rest < 1000) "零" else "") + underTenThousand(rest) else ""
            }
            else -> underTenThousand(number)
        }
        if (parts.size > 1) result += "点" + readDigits(parts[1])
        return result
    }
}
