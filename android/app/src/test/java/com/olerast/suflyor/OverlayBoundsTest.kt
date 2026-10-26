package com.olerast.suflyor

import com.olerast.suflyor.overlay.OverlayBounds
import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayBoundsTest {
    @Test fun shrinksBothDimensionsAndKeepsControlsOnScreen() {
        val initial = OverlayBounds(20, 40, 360, 320)
        assertEquals(OverlayBounds(20, 40, 260, 220), initial.resize(-100, -100, false, false, 400, 800, 240, 180))
        assertEquals(OverlayBounds(20, 40, 240, 180), initial.resize(-500, -500, false, false, 400, 800, 240, 180))
        assertEquals(OverlayBounds(20, 40, 380, 760), initial.resize(900, 900, false, false, 400, 800, 240, 180))
    }

    @Test fun rotatedHandlesAnchorTheirOppositeCorner() {
        val initial = OverlayBounds(80, 100, 300, 400)
        assertEquals(OverlayBounds(130, 100, 250, 450), initial.resize(50, 50, true, false, 600, 900, 180, 240))
        assertEquals(OverlayBounds(80, 150, 350, 350), initial.resize(50, 50, false, true, 600, 900, 180, 240))
    }

    @Test fun restoredSizeAndMovementStayInsideTheDisplay() {
        val saved = OverlayBounds(40, 80, 280, 300)
        assertEquals(saved, OverlayBounds.restore(saved.encode(400, 800), 400, 800))
        assertEquals(OverlayBounds(80, 160, 560, 600), OverlayBounds.restore(saved.encode(400, 800), 800, 1600))
        assertEquals(OverlayBounds(120, 500, 280, 300), saved.copy(x = 350, y = 750).fit(400, 800, 240, 180))
    }
}
