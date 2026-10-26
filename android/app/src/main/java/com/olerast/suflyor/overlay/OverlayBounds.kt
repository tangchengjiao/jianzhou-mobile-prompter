package com.olerast.suflyor.overlay

import kotlin.math.roundToInt

/** Physical screen coordinates, independent of the rotation of the text inside the window. */
data class OverlayBounds(val x: Int, val y: Int, val width: Int, val height: Int) {
    fun fit(screenW: Int, screenH: Int, minW: Int, minH: Int): OverlayBounds {
        val w = width.coerceIn(minW.coerceAtMost(screenW), screenW)
        val h = height.coerceIn(minH.coerceAtMost(screenH), screenH)
        return OverlayBounds(x.coerceIn(0, screenW - w), y.coerceIn(0, screenH - h), w, h)
    }

    /** Keep the opposite corner anchored when the resize handle rotates to the left or top. */
    fun resize(dx: Int, dy: Int, fromLeft: Boolean, fromTop: Boolean,
               screenW: Int, screenH: Int, minW: Int, minH: Int): OverlayBounds {
        val w = (width + if (fromLeft) -dx else dx)
            .coerceIn(minW.coerceAtMost(screenW), if (fromLeft) x + width else screenW - x)
        val h = (height + if (fromTop) -dy else dy)
            .coerceIn(minH.coerceAtMost(screenH), if (fromTop) y + height else screenH - y)
        return OverlayBounds(if (fromLeft) x + width - w else x,
            if (fromTop) y + height - h else y, w, h)
    }

    fun encode(screenW: Int, screenH: Int): String =
        listOf(x.toFloat() / screenW, y.toFloat() / screenH,
            width.toFloat() / screenW, height.toFloat() / screenH).joinToString(",")

    companion object {
        fun restore(value: String?, screenW: Int, screenH: Int): OverlayBounds? {
            val parts = value?.split(',')?.map { it.toFloatOrNull() ?: return null } ?: return null
            if (parts.size != 4) return null
            return OverlayBounds((parts[0] * screenW).roundToInt(), (parts[1] * screenH).roundToInt(),
                (parts[2] * screenW).roundToInt(), (parts[3] * screenH).roundToInt())
        }
    }
}
