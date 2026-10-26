package com.olerast.suflyor.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.TextUtils
import android.util.TypedValue
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.OrientationEventListener
import android.view.Surface
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.SeekBar
import android.widget.TextView
import androidx.annotation.StringRes
import com.olerast.suflyor.App
import com.olerast.suflyor.R
import com.olerast.suflyor.diag.DiagLog
import com.olerast.suflyor.session.SessionEngine

/**
 * The floating prompter. In portrait it hangs from the top edge: text right under the front camera, controls below.
 * Held sideways, it moves next to the lens and turns its text (camera apps keep their screen in portrait).
 * "Lock" lets touches pass through to the camera app; a small button next to the window unlocks it.
 * Hosted by the accessibility service (TYPE_ACCESSIBILITY_OVERLAY) or by the app (TYPE_APPLICATION_OVERLAY).
 */
class OverlayController(private val context: Context, private val windowType: Int) {
    /** Where the lens is and how the content must be turned. */
    private enum class Placement {
        PORTRAIT,

        /** Screen stays portrait, phone turned counter-clockwise: lens on the left, content turned +90°. */
        TURNED_LEFT,

        /** Screen stays portrait, phone turned clockwise: lens on the right, content turned −90°. */
        TURNED_RIGHT,

        /** The screen itself rotated to landscape, lens on the left / right edge. */
        SIDE_LEFT,
        SIDE_RIGHT,
    }

    private val app = App.instance
    private val wm = context.getSystemService(WindowManager::class.java)
    private val displays = context.getSystemService(DisplayManager::class.java)
    private val handler = Handler(Looper.getMainLooper())

    private var frame: RotatedFrame? = null
    private lateinit var params: WindowManager.LayoutParams
    private lateinit var panel: LinearLayout
    private lateinit var topSpacer: View
    private lateinit var prompter: PrompterView
    private lateinit var countdown: TextView
    private lateinit var controls: LinearLayout
    private lateinit var statusDot: View
    private lateinit var statusText: TextView
    private lateinit var level: LevelBar
    private lateinit var diag: TextView
    private lateinit var grabber: FrameLayout
    private lateinit var resizeHandle: View
    private lateinit var overflow: ImageView
    private var wideControls = emptyList<View>()
    private lateinit var pauseBtn: ImageView
    private lateinit var modeBtn: ImageView
    private lateinit var timedFallback: TextView

    /** "Aa" opens it under the buttons: text size, lines, background and speed, adjusted right over the camera. */
    private lateinit var tuneRow: View
    private val tuneValues = ArrayList<() -> Unit>()

    /** "Lines" means nothing sideways, where the text fills the window's height. */
    private lateinit var background: GradientDrawable

    private var bubble: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var locked = false

    private var placement = Placement.PORTRAIT
    private var physical = 0
    private var pendingPhysical = 0
    private var pendingSince = 0L
    private var orientationListener: OrientationEventListener? = null
    private var fontSp = app.settings.fontSp
    private var portraitY = app.settings.overlayY.coerceAtLeast(0)
    private val savedBounds = mutableMapOf<Placement, String>()
    private var safeTop = 0
    private var lastScript: Any? = null

    val isShowing: Boolean get() = frame != null

    private val listener: (SessionEngine.State) -> Unit = { render(it) }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) = Unit
        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) relayoutIfNeeded()
        }
    }

    private fun dp(v: Int): Int = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), context.resources.displayMetrics).toInt()

    @SuppressLint("ClickableViewAccessibility")
    fun show() {
        if (frame != null) return
        safeTop = portraitSafeTop()

        topSpacer = View(context)
        prompter = PrompterView(context).apply {
            setTextSizeSp(fontSp.toFloat())
            linesAbove = 0f
            wordHighlight = app.settings.wordHighlight
            onWordTap = { app.engine.jumpToToken(it) }
        }
        countdown = TextView(context).apply {
            setTextColor(PrompterView.ACCENT)
            textSize = 64f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        val textBox = FrameLayout(context).apply {
            addView(prompter, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
            addView(countdown, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        }

        statusDot = View(context).apply { background = GradientDrawable().apply { shape = GradientDrawable.OVAL } }
        statusText = TextView(context).apply {
            setTextColor(Color.argb(200, 255, 255, 255))
            textSize = 11f
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(6), 0, dp(4), 0)
        }
        level = LevelBar(context)
        pauseBtn = icon(R.drawable.ic_pause, R.string.common_cd_pause) { app.engine.togglePause() }
        modeBtn = icon(R.drawable.ic_mic, R.string.common_cd_scroll_mode) {
            app.engine.setScroll(app.engine.state.scroll.next())
        }
        val status = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(statusDot, LinearLayout.LayoutParams(dp(8), dp(8)))
                addView(statusText)
            })
            addView(level, LinearLayout.LayoutParams(dp(40), dp(3)).apply { topMargin = dp(4) })
        }
        val previous = icon(R.drawable.ic_up, R.string.common_cd_line_back) { app.engine.stepLine(-1) }
        val next = icon(R.drawable.ic_down, R.string.common_cd_line_forward) { app.engine.stepLine(1) }
        val lock = icon(R.drawable.ic_lock, R.string.overlay_cd_lock) { setLocked(true) }
        wideControls = listOf(previous, next, lock)
        overflow = icon(R.drawable.ic_more, R.string.library_cd_menu) {
            PopupMenu(context, overflow).apply {
                menu.add(R.string.common_cd_line_back).setOnMenuItemClickListener { app.engine.stepLine(-1); true }
                menu.add(R.string.common_cd_line_forward).setOnMenuItemClickListener { app.engine.stepLine(1); true }
                menu.add(R.string.overlay_cd_lock).setOnMenuItemClickListener { setLocked(true); true }
            }.show()
        }
        controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
            addView(status, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(modeBtn)
            addView(previous)
            addView(pauseBtn)
            addView(next)
            addView(textButton("Aa", R.string.overlay_cd_tune) { setTuneOpen(tuneRow.visibility != View.VISIBLE) })
            addView(lock)
            addView(overflow)
            addView(icon(R.drawable.ic_close, R.string.overlay_cd_close) { OverlayHost.stopSession(context) })
        }
        tuneRow = buildTuneRow()
        diag = TextView(context).apply {
            setTextColor(Color.argb(190, 170, 240, 190))
            textSize = 10f
            maxLines = 3
            setPadding(dp(16), 0, dp(12), dp(2))
            visibility = if (app.settings.showDiagnostics) View.VISIBLE else View.GONE
        }
        timedFallback = TextView(context).apply {
            text = context.getString(R.string.voice_use_timed)
            setTextColor(PrompterView.ACCENT)
            textSize = 12f
            gravity = Gravity.CENTER
            visibility = View.GONE
            background = ripple()
            setOnClickListener { app.engine.setScroll(SessionEngine.Scroll.AUTO) }
        }
        grabber = FrameLayout(context).apply {
            contentDescription = context.getString(R.string.overlay_cd_move)
            addView(View(context).apply {
                background = GradientDrawable().apply {
                    cornerRadius = dp(2).toFloat()
                    setColor(Color.argb(110, 255, 255, 255))
                }
            }, FrameLayout.LayoutParams(dp(40), dp(4), Gravity.CENTER))
            resizeHandle = object : View(context) {
                private val grip = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(120, 255, 255, 255)
                    strokeWidth = dp(1).toFloat()
                }
                override fun onDraw(canvas: Canvas) {
                    for (length in listOf(6, 11)) {
                        canvas.drawLine(width - dp(length).toFloat(), height - dp(5).toFloat(),
                            width - dp(5).toFloat(), height - dp(length).toFloat(), grip)
                    }
                }
            }.apply {
                contentDescription = context.getString(R.string.overlay_cd_resize)
            }
            addView(resizeHandle, FrameLayout.LayoutParams(dp(32), dp(24), Gravity.END or Gravity.BOTTOM))
        }

        background = GradientDrawable().apply { setColor(Color.argb(app.settings.overlayAlpha * 255 / 100, 8, 8, 10)) }
        panel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            this.background = this@OverlayController.background
            addView(topSpacer, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0))
            addView(textBox, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, prompterHeight()))
            addView(controls, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(44)))
            addView(tuneRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
            addView(diag, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
            addView(timedFallback, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(36)))
            addView(grabber, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(24)))
        }
        val root = RotatedFrame(context).apply {
            addView(panel, android.view.ViewGroup.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT))
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            layoutInDisplayCutoutMode = cutoutMode()
        }
        frame = root
        placement = computePlacement()
        applyPlacement()

        installDrag(grabber, resize = false)
        installDrag(status, resize = false)
        installDrag(controls, resize = false)
        installDrag(resizeHandle, resize = true)

        wm.addView(root, params)
        prompter.setScript(app.scripts.model)
        lastScript = app.scripts.model
        app.engine.addListener(listener)
        displays.registerDisplayListener(displayListener, handler)
        if (app.settings.autoRotate) startOrientationTracking()
    }

    fun hide() {
        app.engine.removeListener(listener)
        orientationListener?.disable()
        orientationListener = null
        runCatching { displays.unregisterDisplayListener(displayListener) }
        hideBubble()
        frame?.let { runCatching { wm.removeView(it) } }
        frame = null
    }

    // ---- placement ----------------------------------------------------------------------------------------------

    private fun startOrientationTracking() {
        orientationListener = object : OrientationEventListener(context) {
            override fun onOrientationChanged(deg: Int) {
                if (deg == ORIENTATION_UNKNOWN) return
                val snapped = when {
                    deg >= 330 || deg <= 30 -> 0
                    deg in 60..120 -> 90
                    deg in 240..300 -> 270
                    deg in 150..210 -> 180
                    else -> return
                }
                val now = SystemClock.uptimeMillis()
                if (snapped != pendingPhysical) {
                    pendingPhysical = snapped
                    pendingSince = now
                }
                if (snapped != physical && now - pendingSince >= 700) {
                    physical = snapped
                    relayoutIfNeeded()
                }
            }
        }.also { if (it.canDetectOrientation()) it.enable() }
    }

    private fun computePlacement(): Placement {
        val rotation = displays.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: Surface.ROTATION_0
        return when {
            rotation == Surface.ROTATION_90 -> Placement.SIDE_LEFT
            rotation == Surface.ROTATION_270 -> Placement.SIDE_RIGHT
            physical == 270 -> Placement.TURNED_LEFT
            physical == 90 -> Placement.TURNED_RIGHT
            else -> Placement.PORTRAIT
        }
    }

    private fun relayoutIfNeeded() {
        val root = frame ?: return
        val next = computePlacement()
        if (next != placement) DiagLog.i("Window: ${describe(next)}")
        placement = next
        applyPlacement()
        wm.updateViewLayout(root, params)
        if (locked) positionBubble()
    }

    private fun describe(p: Placement) = when (p) {
        Placement.PORTRAIT -> "portrait, text under the camera"
        Placement.TURNED_LEFT, Placement.TURNED_RIGHT -> "phone sideways, camera screen portrait — text turned toward the lens"
        Placement.SIDE_LEFT, Placement.SIDE_RIGHT -> "landscape screen — window next to the lens"
    }

    private fun screenSize(): Pair<Int, Int> {
        val bounds = if (Build.VERSION.SDK_INT >= 30) wm.currentWindowMetrics.bounds else null
        return (bounds?.width() ?: context.resources.displayMetrics.widthPixels) to
            (bounds?.height() ?: context.resources.displayMetrics.heightPixels)
    }

    private fun sideways() = placement == Placement.TURNED_LEFT || placement == Placement.TURNED_RIGHT
    private fun tuneExtra() = if (tuneRow.visibility == View.VISIBLE) dp(44) else 0
    private fun minimumSize(): Pair<Int, Int> {
        val textAndControls = dp(56 + if (locked) 0 else 44 + 24) + tuneExtra() +
            (if (placement == Placement.PORTRAIT) safeTop else 0) +
            (if (diag.visibility == View.VISIBLE) dp(44) else 0) +
            (if (timedFallback.visibility == View.VISIBLE) dp(36) else 0)
        return if (sideways()) textAndControls to dp(240) else dp(240) to textAndControls
    }

    /** Window size and position, content rotation, paddings that keep text clear of the camera cut-out. */
    private fun applyPlacement() {
        val root = frame ?: return
        val (screenW, screenH) = screenSize()
        val r = dp(22).toFloat()
        val textBox = prompter.parent as View
        val portrait = placement == Placement.PORTRAIT
        val basePadStart = dp(18)
        val basePadEnd = dp(14)

        root.angle = when (placement) {
            Placement.TURNED_LEFT -> 90
            Placement.TURNED_RIGHT -> -90
            else -> 0
        }
        panel.layoutParams = panel.layoutParams.apply {
            width = android.view.ViewGroup.LayoutParams.MATCH_PARENT
            height = android.view.ViewGroup.LayoutParams.MATCH_PARENT
        }
        textBox.layoutParams = (textBox.layoutParams as LinearLayout.LayoutParams).apply {
            height = 0
            weight = 1f
        }
        grabber.visibility = if (!locked) View.VISIBLE else View.GONE
        panel.setPadding(0, 0, 0, 0)
        prompter.setPadding(basePadStart, dp(4), basePadEnd, dp(2))
        topSpacer.layoutParams = topSpacer.layoutParams.apply { height = 0 }

        val defaults = when (placement) {
            Placement.PORTRAIT -> OverlayBounds(0, portraitY, screenW, prompterHeight() + dp(68) + (safeTop - portraitY).coerceAtLeast(0))
            Placement.TURNED_LEFT, Placement.TURNED_RIGHT -> OverlayBounds(0, 0, screenW, (screenH * 0.46f).toInt())
            Placement.SIDE_LEFT -> OverlayBounds(0, 0, (screenW * 0.46f).toInt(), screenH)
            Placement.SIDE_RIGHT -> OverlayBounds((screenW * 0.54f).toInt(), 0, (screenW * 0.46f).toInt(), screenH)
        }
        val base = OverlayBounds.restore(savedBounds[placement] ?: app.settings.overlayBounds(placement.name), screenW, screenH) ?: defaults
        val expanded = if (sideways()) base.copy(width = base.width + tuneExtra()) else base.copy(height = base.height + tuneExtra())
        val (minW, minH) = minimumSize()
        val bounds = expanded.fit(screenW, screenH, minW, minH)
        val wide = (if (sideways()) bounds.height else bounds.width) >= dp(344)
        wideControls.forEach { it.visibility = if (wide) View.VISIBLE else View.GONE }
        overflow.visibility = if (wide) View.GONE else View.VISIBLE
        params.gravity = Gravity.TOP or Gravity.LEFT
        params.x = bounds.x; params.y = bounds.y
        params.width = bounds.width; params.height = bounds.height
        background.cornerRadius = r
        if (portrait) {
            topSpacer.layoutParams = topSpacer.layoutParams.apply { height = (safeTop - params.y).coerceAtLeast(0) }
        } else if (placement == Placement.TURNED_LEFT) {
            prompter.setPadding(basePadStart + (safeTop - bounds.y).coerceAtLeast(0), dp(6), basePadEnd, dp(4))
        } else if (placement == Placement.TURNED_RIGHT) {
            prompter.setPadding(basePadStart, dp(6), basePadEnd + (safeTop - bounds.y).coerceAtLeast(0), dp(4))
        } else {
            val cut = sideCutout()
            if (placement == Placement.SIDE_LEFT && bounds.x < cut) panel.setPadding(cut - bounds.x, 0, 0, 0)
            if (placement == Placement.SIDE_RIGHT && bounds.x + bounds.width > screenW - cut) panel.setPadding(0, 0, cut, 0)
        }
        panel.requestLayout()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun installDrag(target: View, resize: Boolean) {
        var downX = 0f; var downY = 0f
        var start = OverlayBounds(0, 0, 0, 0)
        var gesturePlacement = placement
        target.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY
                    start = OverlayBounds(params.x, params.y, params.width, params.height)
                    gesturePlacement = placement
                }
                MotionEvent.ACTION_MOVE -> {
                    if (placement != gesturePlacement) return@setOnTouchListener true
                    val dx = (event.rawX - downX).toInt(); val dy = (event.rawY - downY).toInt()
                    val (w, h) = screenSize(); val (minW, minH) = minimumSize()
                    val next = if (resize) start.resize(dx, dy,
                        placement == Placement.TURNED_LEFT, placement == Placement.TURNED_RIGHT, w, h, minW, minH)
                    else start.copy(x = start.x + dx, y = start.y + dy).fit(w, h, minW, minH)
                    val base = if (sideways()) next.copy(width = next.width - tuneExtra()) else next.copy(height = next.height - tuneExtra())
                    savedBounds[placement] = base.encode(w, h)
                    applyPlacement()
                    frame?.let { wm.updateViewLayout(it, params) }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    savedBounds[gesturePlacement]?.let { app.settings.saveOverlayBounds(gesturePlacement.name, it) }
                }
            }
            true
        }
    }

    private fun portraitSafeTop(): Int {
        if (Build.VERSION.SDK_INT >= 30) {
            val insets = wm.currentWindowMetrics.windowInsets
                .getInsets(WindowInsets.Type.displayCutout() or WindowInsets.Type.statusBars())
            val v = maxOf(insets.top, insets.left, insets.right)
            if (v > 0) return v
        }
        val id = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) context.resources.getDimensionPixelSize(id) else dp(28)
    }

    private fun sideCutout(): Int {
        if (Build.VERSION.SDK_INT >= 30) {
            val insets = wm.currentWindowMetrics.windowInsets.getInsets(WindowInsets.Type.displayCutout())
            return maxOf(insets.left, insets.right)
        }
        return 0
    }

    // ---- lock ---------------------------------------------------------------------------------------------------

    private fun setLocked(value: Boolean) {
        val root = frame ?: return
        locked = value
        controls.visibility = if (value) View.GONE else View.VISIBLE
        if (value) tuneRow.visibility = View.GONE
        grabber.visibility = if (!value) View.VISIBLE else View.GONE
        params.flags = if (value) {
            params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        } else {
            params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        }
        // Plain overlays let touches through only when at most 80% opaque (Android 12+); accessibility ones always.
        if (windowType == WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY) params.alpha = if (value) 0.8f else 1f
        applyPlacement()
        wm.updateViewLayout(root, params)
        if (value) showBubble() else hideBubble()
        DiagLog.i(if (value) "Window locked: touches pass to the camera app" else "Window accepts touches again")
    }

    private fun showBubble() {
        if (bubble != null) return
        val size = dp(44)
        val view = FrameLayout(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(200, 8, 8, 10))
                setStroke(dp(1), Color.argb(90, 255, 255, 255))
            }
            addView(ImageView(context).apply {
                setImageResource(R.drawable.ic_lock_open)
                imageTintList = ColorStateList.valueOf(PrompterView.ACCENT)
                contentDescription = context.getString(R.string.overlay_cd_unlock)
            }, FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER))
            setOnClickListener { setLocked(false) }
        }
        val p = WindowManager.LayoutParams(
            size, size, windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            layoutInDisplayCutoutMode = cutoutMode()
        }
        bubble = view
        bubbleParams = p
        runCatching { wm.addView(view, p) }
        positionBubble()
    }

    private fun positionBubble() {
        val root = frame ?: return
        root.post {
            val view = bubble ?: return@post
            val p = bubbleParams ?: return@post
            val loc = IntArray(2)
            root.getLocationOnScreen(loc)
            val size = p.width
            when (placement) {
                Placement.SIDE_LEFT -> {
                    p.x = loc[0] + root.width + dp(6)
                    p.y = loc[1] + root.height - size - dp(24)
                }
                Placement.SIDE_RIGHT -> {
                    p.x = loc[0] - size - dp(6)
                    p.y = loc[1] + root.height - size - dp(24)
                }
                else -> {
                    p.x = loc[0] + root.width - size - dp(12)
                    p.y = loc[1] + root.height + dp(6)
                }
            }
            val (screenW, screenH) = screenSize()
            p.x = p.x.coerceIn(0, (screenW - size).coerceAtLeast(0))
            p.y = p.y.coerceIn(safeTop, (screenH - size).coerceAtLeast(safeTop))
            runCatching { wm.updateViewLayout(view, p) }
        }
    }

    private fun hideBubble() {
        bubble?.let { runCatching { wm.removeView(it) } }
        bubble = null
        bubbleParams = null
    }

    // ---- state --------------------------------------------------------------------------------------------------

    private fun render(s: SessionEngine.State) {
        if (frame == null) return
        if (lastScript !== app.scripts.model) {
            lastScript = app.scripts.model
            prompter.setScript(app.scripts.model)
        }
        prompter.setProgress(s.nextToken)
        if (s.countdown > 0) {
            countdown.text = s.countdown.toString()
            countdown.visibility = View.VISIBLE
        } else {
            countdown.visibility = View.GONE
        }
        val muted = s.silencedBySystem == true || s.digitalSilence
        level.setLevel(s.levelDb, muted)
        pauseBtn.setImageResource(if (s.paused) R.drawable.ic_play else R.drawable.ic_pause)
        pauseBtn.contentDescription = context.getString(if (s.paused) R.string.common_cd_resume else R.string.common_cd_pause)
        modeBtn.setImageResource(s.scroll.icon)
        val red = Color.rgb(255, 80, 80)
        val (color, label) = when {
            s.starting || s.loadingModel -> Color.GRAY to R.string.overlay_status_starting
            !s.listening -> Color.GRAY to R.string.overlay_status_stopped
            // A failed model or microphone must not look like "listening" while the text stands still.
            s.error != null -> red to R.string.overlay_status_error
            s.paused -> PrompterView.ACCENT to R.string.overlay_status_paused
            s.scroll == SessionEngine.Scroll.AUTO -> PrompterView.ACCENT to R.string.overlay_status_auto
            // Sound mode depends on hearing too: a silenced microphone must show before "by sound".
            s.silencedBySystem == true -> red to R.string.overlay_status_mic_busy
            s.autoFallback -> red to R.string.overlay_status_cant_hear
            s.scroll == SessionEngine.Scroll.SOUND -> PrompterView.ACCENT to R.string.overlay_status_sound
            else -> Color.rgb(70, 215, 120) to R.string.overlay_status_listening
        }
        (statusDot.background as GradientDrawable).setColor(color)
        statusText.text = context.getString(label)
        // The error text shows even with diagnostics off: the status row has room for one word only.
        val blockedInput = s.scroll != SessionEngine.Scroll.AUTO && (s.silencedBySystem == true || s.autoFallback || s.micFailed)
        val showDiag = app.settings.showDiagnostics || s.error != null || blockedInput
        val showFallback = blockedInput && !locked
        if (showFallback != (timedFallback.visibility == View.VISIBLE)) {
            timedFallback.visibility = if (showFallback) View.VISIBLE else View.GONE
            applyPlacement()
            frame?.let { wm.updateViewLayout(it, params) }
        }
        if (showDiag != (diag.visibility == View.VISIBLE)) {
            diag.visibility = if (showDiag) View.VISIBLE else View.GONE
            applyPlacement()
            frame?.let { wm.updateViewLayout(it, params) }
            if (locked) positionBubble()
        }
        if (!app.settings.showDiagnostics && blockedInput && s.error == null) {
            diag.text = context.getString(R.string.voice_busy_hint)
        } else if (!app.settings.showDiagnostics && s.error != null) {
            diag.text = s.error.message(context)
        } else if (showDiag) {
            val others = s.recordings.filter { !it.ours }
            diag.text = buildString {
                append(s.partial.ifEmpty { s.lastFinal }.takeLast(70))
                if (others.isNotEmpty()) append("\n").append(others.joinToString("; ") { it.describe() })
                s.error?.let { append("\n").append(it.message(context)) }
            }
        }
    }

    private fun buildTuneRow(): View {
        val s = app.settings
        val labels = listOf(R.string.overlay_tune_font, R.string.overlay_tune_lines,
            R.string.settings_opacity_title, R.string.overlay_tune_speed).map(context::getString)
        var selected = 2 // Opacity is immediately visible when Aa is opened.
        var refreshing = false
        val picker = TextView(context).apply {
            setTextColor(Color.WHITE); textSize = 11f; gravity = Gravity.CENTER
            maxLines = 1; background = ripple()
        }
        val slider = SeekBar(context).apply {
            progressTintList = ColorStateList.valueOf(PrompterView.ACCENT)
            thumbTintList = ColorStateList.valueOf(PrompterView.ACCENT)
            setPadding(dp(8), 0, dp(8), 0)
        }
        val valueView = TextView(context).apply {
            setTextColor(Color.WHITE); textSize = 12f; gravity = Gravity.CENTER
        }
        fun minimum() = when (selected) { 0 -> MIN_FONT_SP; 1 -> 1; 2 -> 0; else -> 60 }
        fun maximum() = when (selected) { 0 -> MAX_FONT_SP; 1 -> 8; 2 -> 100; else -> 260 }
        fun stepSize() = when (selected) { 0 -> 2; 3 -> 10; else -> 1 }
        fun value() = when (selected) { 0 -> fontSp; 1 -> s.overlayLines; 2 -> s.overlayAlpha; else -> s.autoScrollWpm }
        fun refresh() {
            refreshing = true
            picker.text = labels[selected] + " ▾"
            picker.contentDescription = context.getString(R.string.overlay_tune_choose, labels[selected])
            slider.contentDescription = labels[selected]
            slider.max = (maximum() - minimum()) / stepSize()
            slider.progress = (value() - minimum()) / stepSize()
            valueView.text = if (selected == 2) "${value()}%" else "${value()}"
            refreshing = false
        }
        fun adjust(next: Int) {
            val target = next.coerceIn(minimum(), maximum())
            when (selected) {
                0 -> changeFont(target - fontSp)
                1 -> changeLines(target - s.overlayLines)
                2 -> changeAlpha(target - s.overlayAlpha)
                else -> changeSpeed(target - s.autoScrollWpm)
            }
            refresh()
        }
        slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(view: SeekBar, progress: Int, fromUser: Boolean) {
                if (fromUser && !refreshing) adjust(minimum() + progress * stepSize())
            }
            override fun onStartTrackingTouch(view: SeekBar) = Unit
            override fun onStopTrackingTouch(view: SeekBar) = Unit
        })
        picker.setOnClickListener {
            PopupMenu(context, picker).apply {
                labels.forEachIndexed { index, label ->
                    menu.add(label).setOnMenuItemClickListener { selected = index; refresh(); true }
                }
            }.show()
        }
        fun step(label: String, @StringRes description: Int, direction: Int) = TextView(context).apply {
            text = label; contentDescription = context.getString(description)
            setTextColor(Color.WHITE); textSize = 18f; gravity = Gravity.CENTER; background = ripple()
            setOnClickListener { adjust(value() + direction * stepSize()) }
        }
        tuneValues += ::refresh
        refresh()
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
            visibility = View.GONE
            addView(picker, LinearLayout.LayoutParams(dp(82), dp(44)))
            addView(step("−", R.string.overlay_adjust_decrease, -1), LinearLayout.LayoutParams(dp(24), dp(44)))
            addView(slider, LinearLayout.LayoutParams(0, dp(44), 1f))
            addView(step("+", R.string.overlay_adjust_increase, 1), LinearLayout.LayoutParams(dp(24), dp(44)))
            addView(valueView, LinearLayout.LayoutParams(dp(40), dp(44)))
        }
    }

    private fun setTuneOpen(open: Boolean) {
        tuneRow.visibility = if (open) View.VISIBLE else View.GONE
        tuneValues.forEach { it() }
        applyPlacement()
        frame?.let { wm.updateViewLayout(it, params) }
        if (locked) positionBubble()
    }

    private fun changeLines(delta: Int) {
        val old = app.settings.overlayLines
        app.settings.overlayLines = (app.settings.overlayLines + delta).coerceIn(1, 8)
        val (w, h) = screenSize()
        val current = OverlayBounds.restore(savedBounds[placement] ?: app.settings.overlayBounds(placement.name), w, h)
        if (current != null && placement == Placement.PORTRAIT) {
            val lineHeight = PrompterView(context).apply { setTextSizeSp(fontSp.toFloat()) }.lineHeightPx
            val next = current.copy(height = current.height + lineHeight * (app.settings.overlayLines - old))
            savedBounds[placement] = next.encode(w, h)
            app.settings.saveOverlayBounds(placement.name, next.encode(w, h))
        }
        applyPlacement()
        frame?.let { wm.updateViewLayout(it, params) }
    }

    private fun changeAlpha(delta: Int) {
        app.settings.overlayAlpha = (app.settings.overlayAlpha + delta).coerceIn(0, 100)
        background.setColor(Color.argb(app.settings.overlayAlpha * 255 / 100, 8, 8, 10))
    }

    private fun changeSpeed(delta: Int) {
        app.settings.autoScrollWpm = (app.settings.autoScrollWpm + delta).coerceIn(60, 260)
    }

    private fun changeFont(delta: Int) {
        fontSp = (fontSp + delta).coerceIn(MIN_FONT_SP, MAX_FONT_SP)
        app.settings.fontSp = fontSp
        prompter.setTextSizeSp(fontSp.toFloat())
        applyPlacement()
        frame?.let { wm.updateViewLayout(it, params) }
    }

    /** ALWAYS exists from Android 11; on 10 SHORT_EDGES also lets the window reach under the camera cut-out at the top. */
    private fun cutoutMode(): Int = if (Build.VERSION.SDK_INT >= 30) {
        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
    } else {
        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
    }

    private companion object {
        /** The window sits over the camera preview: bigger text would cover the face. The full screen goes to 80. */
        const val MIN_FONT_SP = 14
        const val MAX_FONT_SP = 48
    }

    private fun prompterHeight(): Int {
        val probe = PrompterView(context).apply { setTextSizeSp(fontSp.toFloat()) }
        return probe.lineHeightPx * app.settings.overlayLines + dp(8)
    }

    private fun ripple() = context.obtainStyledAttributes(intArrayOf(android.R.attr.selectableItemBackgroundBorderless)).let {
        val d = it.getDrawable(0)
        it.recycle()
        d
    }

    private fun icon(res: Int, @StringRes description: Int, onClick: () -> Unit) = ImageView(context).apply {
        setImageResource(res)
        imageTintList = ColorStateList.valueOf(Color.WHITE)
        contentDescription = context.getString(description)
        scaleType = ImageView.ScaleType.CENTER
        background = ripple()
        layoutParams = LinearLayout.LayoutParams(dp(38), dp(40))
        setOnClickListener { onClick() }
    }

    private fun textButton(label: String, @StringRes description: Int, onClick: () -> Unit) = TextView(context).apply {
        text = label
        contentDescription = context.getString(description)
        setTextColor(Color.WHITE)
        textSize = 14f
        typeface = Typeface.DEFAULT_BOLD
        gravity = Gravity.CENTER
        background = ripple()
        layoutParams = LinearLayout.LayoutParams(dp(36), dp(40))
        setOnClickListener { onClick() }
    }
}

/** Thin level meter; red when Android is feeding us silence. */
class LevelBar(context: Context) : View(context) {
    private val bg = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(60, 255, 255, 255) }
    private val fg = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
    private var fraction = 0f
    private var muted = false

    fun setLevel(db: Float, muted: Boolean) {
        fraction = ((db + 60f) / 60f).coerceIn(0f, 1f)
        this.muted = muted
        invalidate()
    }

    override fun onDraw(canvas: android.graphics.Canvas) {
        val r = height / 2f
        canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), r, r, bg)
        fg.color = if (muted) Color.rgb(255, 80, 80) else Color.rgb(70, 215, 120)
        val w = if (muted) width.toFloat() else width * fraction
        if (w > 0f) canvas.drawRoundRect(0f, 0f, w, height.toFloat(), r, r, fg)
    }
}
