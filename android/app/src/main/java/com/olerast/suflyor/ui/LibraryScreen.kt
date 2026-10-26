package com.olerast.suflyor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.TextButton
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.olerast.suflyor.App
import com.olerast.suflyor.R
import com.olerast.suflyor.data.ScriptRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    readiness: Readiness,
    onOpen: (String) -> Unit,
    onSettings: () -> Unit,
    onFixReadiness: () -> Unit,
    onPickFile: () -> Unit,
    onPaste: () -> Unit,
    onWrite: () -> Unit,
    onBackup: () -> Unit,
    onExportSelected: (Set<String>) -> Unit,
    onRestore: () -> Unit,
) {
    val app = App.instance
    var query by remember { mutableStateOf("") }
    var showAdd by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }
    var selecting by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf(emptySet<String>()) }
    val items = app.scripts.items.filter { query.isBlank() || it.title.contains(query.trim(), ignoreCase = true) }

    Box(Modifier.fillMaxSize().background(Palette.Bg)) {
        LazyColumn(
            Modifier.fillMaxSize().statusBarsPadding(),
            contentPadding = PaddingValues(bottom = 120.dp),
        ) {
            item {
                Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.library_title),
                        style = MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = { selecting = !selecting; selected = emptySet() }) {
                        Text(stringResource(if (selecting) R.string.common_cancel else R.string.library_export_batch))
                    }
                    IconButton(onClick = onSettings) {
                        Ic(R.drawable.ic_settings, stringResource(R.string.settings_title), tint = Palette.TextSecondary)
                    }
                    Box {
                        IconButton(onClick = { showMenu = true }) {
                            Ic(R.drawable.ic_more, stringResource(R.string.library_cd_menu), tint = Palette.TextSecondary)
                        }
                        DropdownMenu(
                            expanded = showMenu,
                            onDismissRequest = { showMenu = false },
                            containerColor = Palette.SurfaceHigh,
                        ) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.settings_backup_title)) },
                                leadingIcon = { Ic(R.drawable.ic_file, null, tint = Palette.TextSecondary, size = 20.dp) },
                                onClick = {
                                    showMenu = false
                                    onBackup()
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.settings_restore_title)) },
                                leadingIcon = { Ic(R.drawable.ic_replay, null, tint = Palette.TextSecondary, size = 20.dp) },
                                onClick = {
                                    showMenu = false
                                    onRestore()
                                },
                            )
                        }
                    }
                }
            }
            if (!readiness.overlayVoice) {
                item { ReadinessBanner(readiness, onFixReadiness) }
            }
            item {
                Row(
                    Modifier.padding(horizontal = 16.dp, vertical = 12.dp).fillMaxWidth().height(48.dp)
                        .clip(RoundedCornerShape(16.dp)).background(Palette.Surface).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Ic(R.drawable.ic_search, null, tint = Palette.TextMuted, size = 20.dp)
                    Spacer(Modifier.width(10.dp))
                    Box(Modifier.weight(1f)) {
                        if (query.isEmpty()) {
                            Text(
                                stringResource(R.string.library_search_hint),
                                color = Palette.TextMuted,
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it },
                            singleLine = true,
                            textStyle = MaterialTheme.typography.bodyLarge.copy(color = Palette.Text),
                            cursorBrush = SolidColor(Palette.Accent),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
            if (selecting) {
                item {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                        val all = items.isNotEmpty() && items.all { it.id in selected }
                        Checkbox(checked = all, onCheckedChange = { checked ->
                            val visible = items.map { it.id }.toSet()
                            selected = if (checked) selected + visible else selected - visible
                        })
                        Text(stringResource(R.string.library_export_select_all), modifier = Modifier.weight(1f))
                        Text(stringResource(R.string.library_export_count, selected.size), color = Palette.TextSecondary)
                    }
                }
            }
            items(items, key = { it.id }) { meta ->
                ScriptCard(meta, current = meta.id == app.scripts.currentId,
                    selected = if (selecting) meta.id in selected else null,
                    onClick = {
                        if (selecting) selected = if (meta.id in selected) selected - meta.id else selected + meta.id
                        else onOpen(meta.id)
                    })
            }
            if (items.isEmpty()) {
                item {
                    Text(
                        stringResource(R.string.library_search_empty),
                        color = Palette.TextMuted,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(24.dp),
                    )
                }
            }
        }

        if (selecting) {
            Button(
                onClick = { onExportSelected(selected) }, enabled = selected.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = Palette.Accent, contentColor = Palette.OnAccent),
                modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(20.dp).fillMaxWidth().height(52.dp),
            ) { Text(stringResource(R.string.library_export_action, selected.size)) }
        } else Box(
            Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(20.dp).size(62.dp)
                .clip(RoundedCornerShape(20.dp)).background(Palette.Accent).clickable { showAdd = true },
            contentAlignment = Alignment.Center,
        ) { Ic(R.drawable.ic_plus, stringResource(R.string.library_cd_add), tint = Palette.OnAccent, size = 30.dp) }
    }

    if (showAdd) {
        ModalBottomSheet(onDismissRequest = { showAdd = false }, containerColor = Palette.Surface, contentColor = Palette.Text) {
            Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.library_add_title),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
                )
                SheetAction(
                    R.drawable.ic_file,
                    stringResource(R.string.library_add_file),
                    stringResource(R.string.library_add_file_formats),
                ) {
                    showAdd = false
                    onPickFile()
                }
                SheetAction(
                    R.drawable.ic_paste,
                    stringResource(R.string.library_add_paste),
                    stringResource(R.string.library_add_paste_hint),
                ) {
                    showAdd = false
                    onPaste()
                }
                SheetAction(
                    R.drawable.ic_edit,
                    stringResource(R.string.library_add_write),
                    stringResource(R.string.library_add_write_hint),
                ) {
                    showAdd = false
                    onWrite()
                }
                SheetAction(
                    R.drawable.ic_replay,
                    stringResource(R.string.library_add_archive),
                    stringResource(R.string.library_add_archive_hint),
                ) {
                    showAdd = false
                    onRestore()
                }
            }
        }
    }
}

@Composable
private fun ScriptCard(meta: ScriptRepository.Meta, current: Boolean, selected: Boolean? = null, onClick: () -> Unit) {
    val wpm = App.instance.settings.autoScrollWpm
    val secs = if (wpm > 0) (meta.words * 60 + wpm - 1) / wpm else 0
    Card(Modifier.padding(horizontal = 16.dp, vertical = 5.dp).fillMaxWidth(), onClick = onClick) {
        Row(Modifier.padding(horizontal = 18.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            if (selected != null) {
                Checkbox(checked = selected, onCheckedChange = { onClick() })
                Spacer(Modifier.width(6.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(meta.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Text(
                    "${formatLabel(meta.format)} · ${wordsLabel(meta.words)} · ≈${formatDuration(secs)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Palette.TextSecondary,
                )
            }
            if (current && selected == null) StatusDot(Palette.Accent)
        }
    }
}

@Composable
private fun SheetAction(icon: Int, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.SurfaceHigh).clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Ic(icon, null, tint = Palette.Accent)
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Palette.TextSecondary)
        }
    }
}

@Composable
private fun ReadinessBanner(readiness: Readiness, onSetup: () -> Unit) {
    Card(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth(), onClick = onSetup) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(Palette.AccentSoft), contentAlignment = Alignment.Center) {
                Ic(R.drawable.ic_layers, null, tint = Palette.Accent, size = 22.dp)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.library_setup_title), style = MaterialTheme.typography.titleMedium)
                Text(
                    stringResource(R.string.library_setup_progress, readiness.doneCount, readiness.total),
                    style = MaterialTheme.typography.bodyMedium,
                    color = Palette.TextSecondary,
                )
            }
        }
    }
}
