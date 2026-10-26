"""Apply the native fork's Chinese strings without changing format arguments."""
from pathlib import Path
import xml.etree.ElementTree as ET
import re

ROOT = Path(__file__).resolve().parents[1] / "android/app/src/main/res/values"
TEXT = {
    "rehearsal_status_error": "暂时无法跟读，请查看提示", "rehearsal_status_sound": "声音启停 · %1$d 字/分",
    "backup_saved": "已备份 %1$d 份稿件", "backup_failed": "备份失败：%1$s", "backup_restored": "已恢复 %1$d 份稿件。", "backup_skipped": "已略过空稿或超长稿件：%1$d 份。",
    "editor_stats": "%1$s · 约 %2$s · %3$d 字/分", "journal_crash_title": "上次运行意外结束", "journal_crash_hint": "记录仅保存在本机，用于排查运行问题。", "journal_crash_share": "导出这份记录",
    "mirror_off": "关闭", "mirror_horizontal": "水平", "mirror_vertical": "垂直", "mirror_both": "水平与垂直",
    "speed_value": "%1$d 字/分", "rehearsal_view": "阅读设置", "scroll_mode_voice": "语音", "scroll_mode_auto": "匀速", "scroll_mode_sound": "声音启停", "speed_unit": "字 / 分钟",
    "app_name": "见舟提词",
    "a11y_label": "见舟提词：悬浮与语音",
    "a11y_description": "在拍摄时显示悬浮提词，并尝试保持语音跟随。仅在提词运行期间处理声音、应用切换事件和已配置的遥控按键，不读取屏幕文字。实际麦克风共享效果需要在你的手机和拍摄应用中验证。",
    "common_cd_back": "返回", "common_cd_restart": "从头开始", "common_cd_line_back": "上一句", "common_cd_line_forward": "下一句",
    "common_cd_pause": "暂停", "common_cd_resume": "继续", "common_cd_scroll_mode": "提词模式：语音、匀速或声音启停",
    "common_cancel": "取消", "common_delete": "删除", "common_untitled": "未命名口播", "format_typed": "文本", "format_sample": "示例",
    "key_action_pause": "暂停 / 继续", "key_action_back": "上一句", "key_action_forward": "下一句",
    "camera_target_camera": "系统相机", "camera_target_window_only": "只开浮窗，手动切换拍摄应用",
    "start_problem_no_host": "请开启见舟提词无障碍服务，或允许显示在其他应用上层。",
    "start_problem_window_failed": "未能显示提词窗，请检查无障碍服务或悬浮权限。",
    "speech_lang_auto": "跟随稿件语言", "speech_lang_zh": "简体中文", "settings_speech_lang_name_zh": "中文",
    "library_title": "我的稿件", "library_search_hint": "找一份稿子", "library_search_empty": "没有找到这份稿子",
    "library_cd_add": "添加稿件", "library_add_title": "准备一份稿子", "library_add_file": "从文件导入",
    "library_add_paste": "粘贴剪贴板文字", "library_add_paste_hint": "从常用写稿应用复制后粘贴", "library_add_write": "自己写一份", "library_add_write_hint": "输入或粘贴想讲的话",
    "library_setup_title": "准备配合拍摄应用使用", "library_setup_progress": "已完成 %1$d / %2$d 项：检查麦克风与悬浮服务",
    "editor_title_new": "这次，想讲什么？", "editor_title_edit": "修改稿件", "editor_action_done": "保存", "editor_hint_title": "稿件标题",
    "editor_hint_text": "把想讲的话放在这里。每个段落另起一行。", "editor_syntax_help": "**重点** · # 标题 · [提示] 仅显示，不参与跟读",
    "rehearsal_status_starting": "正在准备…", "rehearsal_status_idle": "尚未开始", "rehearsal_status_paused": "已暂停",
    "rehearsal_status_auto": "匀速 · %1$d 字/分", "rehearsal_status_mic_busy": "麦克风被其他应用占用",
    "rehearsal_status_fallback": "暂时没听到声音，已保持当前位置", "rehearsal_status_listening": "正在跟读",
    "journal_title": "运行记录", "journal_clip_label": "见舟提词运行记录", "journal_toast_copied": "记录已复制", "journal_cd_copy": "复制", "journal_share_title": "导出运行记录", "journal_cd_share": "分享", "journal_cd_clear": "清空",
    "stepper_cd_decrease": "减小%1$s", "stepper_cd_increase": "增大%1$s", "settings_title": "按你的习惯来", "settings_action_allow": "允许", "settings_action_open": "打开",
    "settings_section_readiness": "拍摄前准备", "settings_mic_title": "麦克风", "settings_mic_hint": "语音模式需要允许在使用期间录音",
    "settings_a11y_title": "悬浮与语音服务", "settings_a11y_not_running": "已开启但未运行，可关闭后重新开启",
    "settings_a11y_hint": "用于悬浮显示和录像时的语音共享，需在本机验证实际效果。",
    "settings_a11y_restricted": "若开关无法开启：设置 → 应用 → %1$s → 右上菜单 → 允许受限设置。",
    "settings_app_info": "应用信息", "settings_notifications_title": "运行通知", "settings_notifications_hint": "提词运行时显示通知，可以随时停止。",
    "settings_section_voice": "语音跟随", "settings_speech_lang_auto_hint": "按稿件选择语言，当前为%1$s",
    "settings_speech_lang_name_ru": "俄语", "settings_speech_lang_name_en": "英语", "settings_lead_title": "阅读提前量",
    "settings_lead_hint": "在已识别位置前方显示多少个字", "settings_highlight_title": "突出下一个字", "settings_highlight_hint": "关闭时突出当前阅读行",
    "settings_hotwords_title": "稿件词表提示", "settings_hotwords_hint": "中文实验模型暂未启用词表提示。",
    "settings_section_text": "文字排版", "settings_phrase_title": "按短句显示", "settings_phrase_hint": "按标点拆成适合一口气说完的短句",
    "settings_max_words_title": "每行长度", "settings_max_words_value": "最多 %1$d", "settings_font_title": "字号",
    "settings_section_tile": "快捷开关", "settings_tile_hint": "下拉快捷设置，点击见舟提词即可在当前应用上显示稿件；再次点击停止。",
    "settings_tile_add": "添加到快捷设置", "settings_tile_manual": "完全下拉快捷设置 → 编辑 → 将见舟提词拖到上方。",
    "settings_tile_added": "已添加快捷开关", "settings_tile_already_added": "快捷开关已经存在",
    "settings_section_keys": "遥控与按键", "settings_keys_title": "使用按键控制", "settings_keys_hint": "支持音量键、蓝牙遥控、翻页器和键盘。",
    "settings_volume_keys_title": "接管音量键", "settings_volume_keys_hint": "如果用音量键启动拍摄，请关闭此项，避免冲突。",
    "settings_key_waiting": "请按下遥控器上的按键…", "settings_key_none": "尚未分配", "settings_key_assign": "分配按键", "settings_keys_reset": "恢复默认按键",
    "settings_section_overlay": "镜头旁的提词窗", "settings_rotate_title": "随横向拍摄调整", "settings_rotate_hint": "横放手机时，文字转到镜头旁。",
    "settings_lines_title": "浮窗行数", "settings_opacity_title": "背景不透明度", "settings_opacity_hint": "调低后可以透过浮窗看到取景画面。",
    "settings_diag_title": "显示运行状态", "settings_diag_hint": "显示识别内容和音频占用状态，便于试拍检查。",
    "settings_section_autoscroll": "匀速与声音启停", "settings_wpm_title": "语速", "settings_wpm_hint": "中文字/分钟，用于匀速提词和时长估算。",
    "settings_countdown_title": "开始前倒计时", "settings_countdown_off": "关闭", "settings_countdown_value": "%1$d 秒", "settings_countdown_hint": "开始前留出准备时间",
    "settings_section_mic": "音频输入", "settings_audio_source": "麦克风来源", "settings_source_speech": "语音识别", "settings_source_standard": "系统默认", "settings_source_raw": "原始声音",
    "settings_sample_rate": "采样率", "settings_rate_khz": "%1$d kHz", "settings_section_about": "关于与运行记录", "settings_language_title": "应用语言", "settings_language_value": "简体中文",
    "settings_log_hint": "查看麦克风和识别的实际运行情况", "settings_about_version": "见舟提词 %1$s · 基于 Suflyor 改编 · sherpa-onnx 中文/英文语音实验版",
    "library_save_failed": "稿件保存失败：%1$s", "script_copy_title": "%1$s（副本）", "script_cd_share": "分享文字", "script_cd_duplicate": "复制稿件", "script_share_title": "导出稿件",
    "settings_section_fullscreen": "全屏阅读", "settings_mirror_title": "镜像文字", "settings_section_scripts": "稿件备份",
    "settings_backup_title": "备份全部稿件", "settings_backup_hint": "每份稿件保存为 Markdown，再打成压缩包。", "settings_restore_title": "从备份恢复", "settings_restore_hint": "添加备份中的稿件，保留现有内容。",
    "settings_link_site": "上游项目介绍", "settings_link_code": "上游开源代码", "settings_link_issue": "上游问题反馈", "settings_link_issue_hint": "如需研究上游问题，可以附上运行记录。",
    "settings_link_donate": "支持上游作者", "settings_link_donate_hint": "打开上游项目的支持页面", "settings_about_license": "本 Android 版本为 Suflyor 的 GPL-3.0 派生实现。",
    "settings_section_advanced": "更多设置", "settings_sum_ready_all": "准备项已开启，录像效果仍需试拍", "settings_sum_ready_part": "已完成 %1$d / %2$d 项，点击继续",
    "settings_sum_overlay": "%1$d 行 · 字号 %2$d · 背景 %3$d%%", "settings_sum_fullscreen": "字号 %1$d · 镜像：%2$s", "settings_sum_voice": "语音语言：%1$s",
    "settings_sum_timed": "%1$d 字/分 · 倒计时：%2$s", "settings_sum_text_phrases": "按短句显示，每行参考 %1$d 个字", "settings_sum_text_paragraphs": "保留稿件段落",
    "settings_sum_keys_on": "已开启", "settings_sum_keys_off": "已关闭", "settings_sum_scripts": "导出或恢复全部稿件", "settings_sum_advanced": "音频来源、采样率与运行状态", "settings_sum_about": "版本 %1$s · 运行记录 · 开源来源",
    "settings_overlay_page_hint": "悬浮时也可点击 Aa 调整，不必离开拍摄应用。", "settings_fullscreen_page_hint": "用于全屏练习，或放在提词反射镜下阅读。",
    "settings_mirror_pick_hint": "选择在反射镜里能正常阅读的方向。", "settings_speech_lang_default_title": "默认语音语言", "settings_speech_lang_default_hint": "单份稿件没有指定语言时使用。",
    "settings_timed_page_hint": "用于匀速、声音启停和时长估算。", "settings_scripts_page_hint": "稿件列表的菜单中也可备份。",
    "script_lang_chip": "语言：%1$s", "script_lang_sheet_title": "这份稿件的语音语言", "script_lang_sheet_hint": "中文按字定位，英文按单词定位。",
    "script_lang_follow": "跟随默认设置（当前%1$s）", "script_speed_sheet_title": "匀速提词语速", "script_speed_sheet_hint": "用于匀速、声音启停和时长估算。",
    "library_cd_menu": "更多", "library_add_archive": "从备份恢复", "library_add_archive_hint": "选择之前导出的稿件压缩包",
    "overlay_cd_lock": "锁定浮窗，让触摸穿透到相机", "overlay_cd_close": "关闭提词", "overlay_cd_unlock": "解锁提词窗",
    "overlay_status_starting": "准备中", "overlay_status_stopped": "已停止", "overlay_status_paused": "已暂停", "overlay_status_auto": "匀速",
    "overlay_status_mic_busy": "麦克风占用", "overlay_status_cant_hear": "暂未听到", "overlay_status_listening": "跟读中", "overlay_status_error": "发生错误", "overlay_status_sound": "声音启停",
    "overlay_toast_closed_a11y_off": "悬浮服务已关闭，提词窗已停止。", "tile_label": "见舟提词", "tile_subtitle_listening": "提词运行中",
    "notification_channel_session": "提词运行状态", "notification_session_title": "见舟提词运行中", "notification_session_text": "悬浮提词已开启", "notification_action_stop": "停止",
    "session_error_asr_failed": "语音模型加载失败：%1$s", "session_error_rate_unsupported": "麦克风不支持 %1$d Hz", "session_error_recorder_create": "无法创建音频输入：%1$s",
    "session_error_recorder_init": "麦克风未就绪，请检查录音权限。", "session_error_record_start": "无法开始音频输入：%1$s", "session_error_mic_busy": "麦克风正在被其他应用使用。", "session_error_mic_read": "音频读取错误：%1$d",
    "key_name_volume_up": "音量加", "key_name_volume_down": "音量减", "key_name_space": "空格", "key_name_dpad_center": "方向键确认", "key_name_next_track": "下一首", "key_name_previous_track": "上一首", "key_name_headset": "耳机按键", "key_name_fast_forward": "快进", "key_name_rewind": "快退", "key_name_gamepad_a": "手柄 A",
    "overlay_cd_tune": "调整字号、行数、背景和语速", "overlay_tune_font": "字号", "overlay_tune_lines": "行数", "overlay_tune_background": "背景", "overlay_tune_speed": "语速",
    "import_error_empty_file": "文件是空的", "import_error_file_too_big": "文件超过 %1$d MB，请确认选择的是稿件。", "import_error_text_file_too_big": "文本文件过大，请分成几份稿件。",
    "import_error_legacy_doc": "暂不支持旧版 DOC，请另存为 DOCX 或 TXT。", "import_error_encrypted": "文档已加密，请先在原应用中解除密码。", "import_error_unknown_zip": "这不是 DOCX 或 ODT 文档。",
    "import_error_no_text": "没有找到可导入的文字", "import_error_not_text": "这不是文本文件", "import_error_pasted_too_long": "内容过长，请拆成几份稿件。",
    "import_error_text_too_long_count": "内容约 %1$d 千字，当前支持最多 %2$d 千字。", "import_error_text_too_long_max": "当前支持最多 %1$d 千字。", "import_error_not_rtf": "这不是 RTF 文档",
    "import_error_zip_too_many_files": "压缩包中的文件过多", "import_error_zip_too_large": "解压后的内容过大", "import_error_unsafe": "文档结构无法读取", "import_error_not_docx": "无法读取 Word 文档内容", "import_error_not_odt": "无法读取 ODT 文档内容",
    "import_error_pdf_unsupported": "当前安卓版本暂不能直接读取 PDF，请改用 TXT 或 DOCX。", "import_error_pdf_password": "PDF 已加密", "import_error_pdf_scan": "这份 PDF 没有文字层，请先复制文字或转成文本。",
    "import_error_open_failed": "文件无法打开", "import_error_read_failed": "读取失败：%1$s", "import_error_generic": "导入失败", "import_warning_pdf_paragraphs": "已按 PDF 文本重建段落，请检查断句。",
    "import_title_shared": "收到的稿件", "import_title_clipboard": "剪贴板稿件", "import_opening": "正在打开…", "import_nothing": "没有可导入的内容", "import_clipboard_empty": "剪贴板没有文字",
    "main_mic_blocked": "请在应用权限中允许麦克风", "main_open_app_failed": "无法打开%1$s，可以手动切换。", "main_no_words": "稿件中还没有可朗读的文字",
    "script_cd_edit": "修改稿件", "script_stats": "· %1$s · %2$s · %3$s", "script_setup_mic": "语音模式需要允许麦克风",
    "script_setup_a11y": "开启悬浮与语音服务后，再验证录像时是否能同时跟读。", "script_action_overlay": "准备悬浮提词", "script_action_rehearse": "全屏练习",
    "script_delete_title": "删除这份稿件？", "script_delete_message": "将从稿库删除“%1$s”，原始文件会保留。", "sample_title": "为什么我要自己做提词器",
    "sample_script": "我拍视频的时候，最怕的不是忘词。\\n\\n而是刚找到状态，提词却没跟上。\\n\\n所以这一次，我想做一个真正顺手的工具。\\n\\n你可以停一下，也可以从这一句重新开始。",
}

def main():
    changed = 0
    for path in ROOT.glob("strings*.xml"):
        tree = ET.parse(path)
        for node in tree.getroot():
            name = node.attrib.get("name", "")
            if node.tag == "string" and name in TEXT:
                before = "".join(node.itertext())
                after = TEXT[name]
                args = lambda value: sorted(re.findall(r"%\d*\$?[dsf]", value))
                if args(before) != args(after):
                    raise ValueError(f"Format arguments differ for {name}")
                node.text = after
                changed += 1
            elif node.tag == "plurals" and name in {"words_count", "settings_lead_value"}:
                for item in node:
                    item.text = "%d 字"
        ET.indent(tree, space="    ")
        tree.write(path, encoding="utf-8", xml_declaration=True)
    print(f"Applied {changed} Chinese string resources.")

if __name__ == "__main__":
    main()
