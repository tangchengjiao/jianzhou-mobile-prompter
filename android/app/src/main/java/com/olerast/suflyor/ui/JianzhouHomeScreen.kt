package com.olerast.suflyor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.olerast.suflyor.App
import com.olerast.suflyor.R
import com.olerast.suflyor.doc.MarkdownImporter
import com.olerast.suflyor.doc.Paragraph
import com.olerast.suflyor.doc.ScriptDocument
import com.olerast.suflyor.script.ChineseNorm
import kotlinx.coroutines.delay
import kotlin.math.ceil

/** Native script-first entry following the selected Jianzhou concept. */
@Composable
fun JianzhouHomeScreen(
    onPrepare: () -> Unit,
    onPractice: () -> Unit,
    onLibrary: () -> Unit,
    onImport: () -> Unit,
    onSettings: () -> Unit,
    onExport: () -> Unit,
    onSaveCopy: () -> Unit,
) {
    val app = App.instance
    val id = app.scripts.currentId
    val document = app.scripts.document
    val title = rememberSaveable(id) { mutableStateOf(document.title) }
    val body = rememberSaveable(id) { mutableStateOf(document.toEditableText()) }
    var practice by rememberSaveable { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val units = remember(body.value) { ChineseNorm.words(body.value).size }
    val seconds = ceil(units * 60.0 / app.settings.autoScrollWpm).toInt()
    var saveStatus by remember(id) { mutableStateOf("已保存到本机") }

    fun save() {
        val stored = id?.let { app.scripts.documentOf(it) } ?: document
        if (title.value == stored.title && body.value == stored.toEditableText()) {
            saveStatus = "已保存到本机"
            return
        }
        val next = MarkdownImporter.parse(body.value, title.value.ifBlank { "未命名口播" })
            .copy(title = title.value.ifBlank { "未命名口播" }, format = document.format,
                speechLang = document.speechLang, sourceText = body.value)
        val saved = if (id != null) app.scripts.update(id, next) else app.scripts.add(next) != null
        saveStatus = if (saved) "已保存到本机" else "保存失败，请导出备份"
    }
    LaunchedEffect(id, title.value, body.value) {
        saveStatus = "正在保存…"
        delay(350)
        save()
    }
    DisposableEffect(id) { onDispose { save() } }
    val currentSave by rememberUpdatedState { save() }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE) currentSave()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    fun leave(action: () -> Unit) { focus.clearFocus(); save(); action() }

    Column(
        Modifier.fillMaxSize().background(Palette.Bg).statusBarsPadding()
            .navigationBarsPadding().imePadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 22.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 23.dp), verticalAlignment = Alignment.CenterVertically) {
            Ic(R.drawable.ic_text, null, tint = Palette.Accent, size = 25.dp)
            Text("见舟提词", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp).weight(1f))
            TextButton(onClick = { leave(onSettings) }) { Text("设置") }
        }
        Text("这次，想讲什么？", fontSize = 29.sp, lineHeight = 38.sp, fontWeight = FontWeight.Bold)
        Text("稿子放这里，拍摄还用你熟悉的 App", fontSize = 14.sp, color = Palette.TextMuted, modifier = Modifier.padding(top = 7.dp, bottom = 20.dp))
        Column(
            Modifier.fillMaxWidth().background(Palette.Surface, RoundedCornerShape(20.dp))
                .border(1.dp, Palette.Outline, RoundedCornerShape(20.dp)).padding(19.dp),
        ) {
            BasicTextField(
                value = title.value, onValueChange = { title.value = it }, singleLine = true,
                textStyle = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.Text),
                cursorBrush = SolidColor(Palette.Accent),
                modifier = Modifier.fillMaxWidth().semantics { contentDescription = "稿件标题" },
            )
            Box(Modifier.padding(top = 20.dp).height(215.dp)) {
                if (body.value.isEmpty()) Text("把想讲的话粘贴在这里……", color = Palette.TextMuted, fontSize = 16.sp)
                BasicTextField(
                    value = body.value, onValueChange = { body.value = it },
                    textStyle = TextStyle(fontSize = 16.sp, lineHeight = 26.sp, color = Palette.Text),
                    cursorBrush = SolidColor(Palette.Accent),
                    modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).semantics { contentDescription = "稿件正文" },
                )
            }
            HorizontalDivider(color = Palette.Outline)
            Row(Modifier.fillMaxWidth().padding(top = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("$units 字 · 约 $seconds 秒", fontSize = 12.sp, color = Palette.TextMuted, modifier = Modifier.weight(1f))
                TextButton(onClick = { if (units > 0) leave(onPractice) }, enabled = units > 0) { Text("试读") }
            }
            Text(saveStatus, fontSize = 11.sp, color = Palette.TextMuted)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onClick = { leave(onSaveCopy) }, enabled = units > 0) { Text("保存副本") }
                TextButton(onClick = { leave(onExport) }, enabled = body.value.isNotBlank()) { Text("导出 TXT") }
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 18.dp)
                .background(Palette.SurfaceHigh, RoundedCornerShape(16.dp)).padding(4.dp),
        ) {
            listOf(false to "悬浮提词", true to "全屏练习").forEach { (value, label) ->
                TextButton(
                    onClick = { focus.clearFocus(); practice = value },
                    modifier = Modifier.weight(1f).background(if (practice == value) Palette.AccentSoft else Palette.SurfaceHigh, RoundedCornerShape(12.dp)),
                ) { Text(label, color = if (practice == value) Palette.Accent else Palette.TextSecondary, fontWeight = FontWeight.SemiBold) }
            }
        }
        Button(
            onClick = { leave(if (practice) onPractice else onPrepare) }, enabled = units > 0,
            shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth().height(55.dp),
        ) { Text(if (practice) "开始全屏练习" else "准备悬浮提词", fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
        TextButton(onClick = { leave(onImport) }, modifier = Modifier.align(Alignment.CenterHorizontally).padding(vertical = 8.dp)) { Text("从文件导入") }
        HorizontalDivider(color = Palette.Outline, modifier = Modifier.padding(top = 7.dp))
        Row(Modifier.fillMaxWidth().padding(top = 5.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("最近使用", color = Palette.TextMuted, fontSize = 13.sp, modifier = Modifier.weight(1f))
            TextButton(onClick = { leave(onLibrary) }) { Text("全部稿件", fontSize = 12.sp) }
        }
        app.scripts.items.filter { it.id != id }.take(2).forEach { meta ->
            Text(meta.title, fontSize = 15.sp, modifier = Modifier.fillMaxWidth().clickable { leave { app.scripts.select(meta.id) } }.padding(vertical = 16.dp))
            HorizontalDivider(color = Palette.Outline)
        }
        TextButton(onClick = { leave { app.scripts.add(ScriptDocument("未命名口播", ScriptDocument.FORMAT_TEXT, listOf(Paragraph("")))) } }) { Text("＋ 新建一份稿子") }
        Text("原生实验版 · 拍摄应用兼容性需真机试拍", fontSize = 10.sp, color = Palette.TextMuted, modifier = Modifier.padding(bottom = 24.dp))
    }
}
