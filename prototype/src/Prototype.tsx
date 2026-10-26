import { useEffect, useRef, useState, type CSSProperties } from "react";
import { ArrowLeftIcon, ArrowRightIcon, CheckIcon, ChevronRightIcon, Cross2Icon, DownloadIcon, EnterFullScreenIcon, FileTextIcon, GearIcon, PauseIcon, PlayIcon, PlusIcon, ReaderIcon, ResetIcon, SpeakerOffIcon, TrackNextIcon, TrackPreviousIcon, DesktopIcon, MixerHorizontalIcon } from "@radix-ui/react-icons";
import { BottomSheet, KeyboardInput, KeyboardTextarea, MobileScroll, useKeyboard, useMobileDevice } from "./mobile";
import "./prototype.css";

type Script = { id: string; title: string; body: string };
type View = "home" | "prepare" | "read" | "floating";
type Settings = { font: number; speed: number; mirror: boolean; countdown: number };
const STORAGE = "jianzhou-prompter:prototype:v1";
const INITIAL: Script[] = [
  { id: "my-prompter", title: "为什么我要自己做提词器", body: "我拍视频的时候，最怕的不是忘词。\n\n而是刚找到状态，提词却没跟上。\n\n所以这一次，我想做一个真正顺手的工具。" },
  { id: "ai-tools", title: "AI 工具该怎么选", body: "选 AI 工具，先别急着看功能。\n\n先想一想，你每天反复做的事情是什么。\n\n找到一个具体任务，把它完整地做一遍。\n\n能帮你把这件事做顺的，才是适合你的工具。" },
];
const DEFAULTS: Settings = { font: 32, speed: 180, mirror: false, countdown: 3 };
function load() {
  try {
    const data = JSON.parse(localStorage.getItem(STORAGE) || "null");
    if (Array.isArray(data?.scripts) && data.scripts.length && data.scripts.every((s: Script) => typeof s.id === "string" && typeof s.title === "string" && typeof s.body === "string")) return { scripts: data.scripts as Script[], settings: { ...DEFAULTS, ...data.settings } as Settings };
  } catch { /* Start from examples when local storage is unavailable. */ }
  return { scripts: INITIAL, settings: DEFAULTS };
}
const count = (text: string) => [...text.replace(/\s/g, "")].length;
function duration(text: string, speed: number) { const sec = Math.ceil(count(text) / speed * 60); return sec < 60 ? `${sec} 秒` : `${Math.floor(sec / 60)} 分 ${sec % 60} 秒`; }
function sentences(text: string) { return (text.match(/[^。！？\n]+[。！？]?/gu) || []).map(x => x.trim()).filter(Boolean); }

export default function Prototype() {
  const [initial] = useState(load);
  const [scripts, setScripts] = useState<Script[]>(initial.scripts);
  const [settings, setSettings] = useState<Settings>(initial.settings);
  const [active, setActive] = useState(initial.scripts[0].id);
  const [view, setView] = useState<View>("home");
  const [mode, setMode] = useState<"overlay" | "practice">("overlay");
  const [sheet, setSheet] = useState<"settings" | "library" | "import" | "help" | null>(null);
  const [paste, setPaste] = useState("");
  const [importError, setImportError] = useState("");
  const [fileName, setFileName] = useState("");
  const [notice, setNotice] = useState("");
  const [playing, setPlaying] = useState(false);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [progress, setProgress] = useState(0);
  const [floatPosition, setFloatPosition] = useState({ x: 14, y: 92 });
  const drag = useRef<{ x: number; y: number; baseX: number; baseY: number } | null>(null);
  const lastProgress = useRef(0);
  const currentLine = useRef<HTMLButtonElement>(null);
  const keyboard = useKeyboard();
  const { device } = useMobileDevice();
  const script = scripts.find(s => s.id === active) || scripts[0];
  const lines = sentences(script.body);
  const total = count(script.body);
  let consumed = 0;
  const foundLine = lines.findIndex(line => { consumed += count(line); return consumed > progress; });
  const lineIndex = foundLine < 0 ? Math.max(0, lines.length - 1) : foundLine;
  const empty = !script.body.trim();
  const reading = view === "read" || view === "floating";

  useEffect(() => { try { localStorage.setItem(STORAGE, JSON.stringify({ scripts, settings })); } catch { setNotice("本次修改可继续使用，浏览器暂时无法保存到本地。"); } }, [scripts, settings]);
  useEffect(() => { if (!notice) return; const id = setTimeout(() => setNotice(""), 3500); return () => clearTimeout(id); }, [notice]);
  useEffect(() => {
    if (remaining === null) return;
    if (remaining <= 0) { setRemaining(null); setPlaying(true); return; }
    const id = setTimeout(() => setRemaining(n => n === null ? null : n - 1), 1000);
    return () => clearTimeout(id);
  }, [remaining]);
  useEffect(() => {
    if (!playing || !reading || !total) return;
    let frame: number;
    let previous = performance.now();
    const tick = (now: number) => {
      const next = Math.min(total, lastProgress.current + Math.min(0.1, (now - previous) / 1000) * settings.speed / 60);
      previous = now; lastProgress.current = next; setProgress(next);
      if (next >= total) { setPlaying(false); return; }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [playing, reading, total, settings.speed]);
  useEffect(() => { if (view === "read") currentLine.current?.scrollIntoView({ behavior: "smooth", block: "center" }); }, [lineIndex, view]);
  useEffect(() => {
    const hidden = () => { if (document.hidden) { setPlaying(false); setRemaining(null); } };
    document.addEventListener("visibilitychange", hidden);
    return () => document.removeEventListener("visibilitychange", hidden);
  }, []);

  function openSheet(next: "settings" | "library" | "import" | "help") { keyboard.hide(); setPlaying(false); setRemaining(null); setSheet(next); }
  function seek(value: number) { const next = Math.max(0, Math.min(total, value)); lastProgress.current = next; setProgress(next); }
  function updateScript(patch: Partial<Script>) { setScripts(items => items.map(item => item.id === script.id ? { ...item, ...patch } : item)); setPlaying(false); seek(0); }
  function navigate(next: View) { keyboard.hide(); setPlaying(false); setRemaining(null); setView(next); }
  function start(next: "read" | "floating") { navigate(next); if (progress >= total) seek(0); if (settings.countdown) setRemaining(settings.countdown); else setPlaying(true); }
  function skip(delta: number) { setRemaining(null); const next = Math.max(0, Math.min(lines.length - 1, lineIndex + delta)); seek(lines.slice(0, next).reduce((sum, item) => sum + count(item), 0)); }
  function toggle() { if (remaining !== null) { setRemaining(null); setPlaying(false); return; } if (progress >= total) seek(0); setPlaying(p => !p); }
  function selectScript(id: string) { keyboard.hide(); setActive(id); setProgress(0); lastProgress.current = 0; setPlaying(false); setRemaining(null); setSheet(null); }
  function createScript() { const next = { id: crypto.randomUUID(), title: "未命名口播", body: "" }; setScripts(items => [next, ...items]); selectScript(next.id); navigate("home"); }
  function importText(text: string, title: string) {
    if (!text.trim()) { setImportError("内容还是空的，先粘贴一段稿子。"); return; }
    const next = { id: crypto.randomUUID(), title: title.replace(/\.(txt|md)$/i, "") || "导入的口播", body: text.trim() };
    setScripts(items => [next, ...items]); selectScript(next.id); setPaste(""); setImportError(""); setFileName(""); navigate("home"); setNotice("稿子已导入，修改会自动保存在当前浏览器里。");
  }
  function exportScript() {
    const url = URL.createObjectURL(new Blob([`${script.title}\n\n${script.body}`], { type: "text/plain;charset=utf-8" }));
    const a = document.createElement("a"); a.href = url; a.download = `${script.title || "口播稿"}.txt`; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000); setNotice("已导出 TXT 稿件。");
  }
  const adjust = <>
    <label className="range-setting"><span>字号 <strong>{settings.font}</strong><small>看清楚，不用凑近</small></span><input data-scroll-drag="ignore" aria-label="字号" type="range" min="24" max="48" value={settings.font} onChange={e => setSettings(s => ({ ...s, font: +e.target.value }))} /><span className="range-ends"><span>小</span><span>大</span></span></label>
    <label className="range-setting"><span>语速 <strong>{settings.speed}</strong><small>字 / 分钟</small></span><input data-scroll-drag="ignore" aria-label="语速" type="range" min="60" max="300" step="10" value={settings.speed} onChange={e => setSettings(s => ({ ...s, speed: +e.target.value }))} /><span className="range-ends"><span>慢一点</span><span>快一点</span></span></label>
  </>;
  const transport = <div className="transport"><button className="icon-button" aria-label="上一句" onClick={() => skip(-1)}><TrackPreviousIcon /></button><button className="play-button" aria-label={remaining !== null ? "取消倒计时" : playing ? "暂停提词" : "播放提词"} onClick={toggle}>{remaining !== null ? <span>{remaining}</span> : playing ? <PauseIcon /> : <PlayIcon />}</button><button className="icon-button" aria-label="下一句" onClick={() => skip(1)}><TrackNextIcon /></button></div>;

  return <div className={`jz-app ${view === "read" ? "jz-reading" : ""}`}>
    <header className="jz-header">{view === "home" ? <><span className="brand"><ReaderIcon />见舟提词</span><button className="icon-button" aria-label="设置" onClick={() => openSheet("settings")}><GearIcon /></button></> : <><button className="icon-button" aria-label="返回" onClick={() => navigate(view === "prepare" ? "home" : "prepare")}><ArrowLeftIcon /></button><span className="header-title">{view === "prepare" ? "提词准备" : view === "floating" ? "悬浮效果演示" : script.title}</span><button className="icon-button" aria-label="调整提词" onClick={() => { setPlaying(false); setRemaining(null); openSheet("settings"); }}><MixerHorizontalIcon /></button></>}</header>
    {view === "home" && <MobileScroll className="jz-scroll"><main className="home-content">
      <h1>这次，想讲什么？</h1><p className="intro">稿子放这里，拍摄还用你熟悉的 App</p>
      <section className="script-editor" aria-label="口播稿件"><KeyboardInput className="script-title" aria-label="稿件标题" value={script.title} onChange={e => updateScript({ title: e.target.value })} onBlur={() => keyboard.hide()} /><KeyboardTextarea className="script-body" aria-label="稿件正文" placeholder="把想讲的话粘贴在这里……" value={script.body} onChange={e => updateScript({ body: e.target.value })} onBlur={() => keyboard.hide()} spellCheck={false} /><div className="editor-meta"><span>{total} 字 · 约 {duration(script.body, settings.speed)}</span><button className="icon-button" aria-label="全屏查看稿件" disabled={empty} onClick={() => navigate("read")}><EnterFullScreenIcon /></button></div></section>
      <div className="mode-switch" aria-label="提词模式"><button aria-pressed={mode === "overlay"} onClick={() => setMode("overlay")}><FileTextIcon />悬浮提词</button><button aria-pressed={mode === "practice"} onClick={() => setMode("practice")}><DesktopIcon />全屏练习</button></div>
      <button className="primary" disabled={empty} onClick={() => mode === "overlay" ? navigate("prepare") : start("read")}><span>{mode === "overlay" ? "准备悬浮提词" : "开始全屏练习"}</span><ArrowRightIcon /></button><button className="text-button import-action" onClick={() => { setImportError(""); openSheet("import"); }}>从文件导入</button>
      <section className="recent"><div className="section-heading"><span>最近使用</span><button className="text-button" onClick={() => openSheet("library")}>全部稿件</button></div>{scripts.filter(s => s.id !== script.id).slice(0, 2).map(s => <button className="script-row" key={s.id} onClick={() => selectScript(s.id)}><span>{s.title}</span><ChevronRightIcon /></button>)}<button className="new-script" onClick={createScript}><PlusIcon />新建一份稿子</button></section><button className="prototype-note" onClick={() => openSheet("help")}>交互原型 · 查看实际使用说明</button>
    </main></MobileScroll>}
    {view === "prepare" && <MobileScroll className="jz-scroll"><main className="prepare-content"><div className="eyebrow">{device.platform === "ios" ? "iPhone · 画中画提词" : "Android · 悬浮窗提词"}</div><h1>调到舒服，再开拍。</h1><div className="reading-preview" style={{ "--reading-font": `${settings.font}px` } as CSSProperties}><div style={{ transform: settings.mirror ? "scaleX(-1)" : undefined }}><p className="active-preview">{lines[0]}</p><p>{lines[1] || "文字会按你的设置往下走。"}</p></div><span className="preview-caption">阅读效果预览</span></div>{adjust}<p className="mode-description"><SpeakerOffIcon />匀速模式 · 不使用麦克风</p><button className="primary" disabled={empty} onClick={() => start("floating")}><span>演示悬浮提词</span><ArrowRightIcon /></button><button className="text-button wide" disabled={empty} onClick={() => start("read")}>先全屏练一遍</button><p className="honest-note">这是屏幕内的交互演示。切换到其他 App 后的悬浮和语音跟随，尚需原生版本真机验证。</p></main></MobileScroll>}
    {view === "read" && <><div className="reading-label"><span className="live-dot" />{remaining !== null ? `${remaining} 秒后开始` : progress >= total ? "这一遍讲完了" : playing ? "匀速提词中" : "已暂停 · 点句子定位"}<span>{Math.min(100, Math.round(progress / Math.max(1, total) * 100))}%</span></div><MobileScroll className="jz-scroll reading-scroll"><div className="reading-lines" style={{ fontSize: settings.font, transform: settings.mirror ? "scaleX(-1)" : undefined }}>{lines.map((line, i) => <button ref={i === lineIndex ? currentLine : undefined} key={i} className={`reading-line ${i === lineIndex ? "is-current" : i < lineIndex ? "is-read" : ""}`} onClick={() => { setPlaying(false); setRemaining(null); seek(lines.slice(0, i).reduce((sum, item) => sum + count(item), 0)); }}>{line}</button>)}</div></MobileScroll><footer className="read-footer"><div className="footer-speed"><span>匀速提词</span><button onClick={() => { setPlaying(false); openSheet("settings"); }}>{settings.speed} <small>字 / 分钟</small></button></div>{transport}<div className="reader-actions"><button className="text-button" onClick={() => { setPlaying(false); setRemaining(null); seek(0); }}><ResetIcon />从头再来</button><button className="text-button" onClick={() => navigate("prepare")}>调整悬浮<ArrowRightIcon /></button></div></footer></>}
    {view === "floating" && <main className="floating-stage"><div className="stage-explanation"><DesktopIcon /><h1>接下来，切换拍摄 App。</h1><p>这里仅演示悬浮窗的阅读与操作。<br />没有开启相机，也没有在跨 App 运行。</p><button className="text-button" onClick={() => openSheet("help")}>了解 iPhone 与安卓的区别<ChevronRightIcon /></button></div><section className="floating-window" aria-label="演示悬浮窗" style={{ left: floatPosition.x, top: floatPosition.y }}><div className="float-handle" onPointerDown={e => { drag.current = { x: e.clientX, y: e.clientY, baseX: floatPosition.x, baseY: floatPosition.y }; e.currentTarget.setPointerCapture(e.pointerId); }} onPointerMove={e => { if (!drag.current) return; const scale = e.currentTarget.getBoundingClientRect().width / e.currentTarget.offsetWidth; const bounds = e.currentTarget.closest(".floating-stage")!.getBoundingClientRect(); setFloatPosition({ x: Math.max(0, Math.min(bounds.width / scale - 298, drag.current.baseX + (e.clientX - drag.current.x) / scale)), y: Math.max(0, Math.min(bounds.height / scale - 280, drag.current.baseY + (e.clientY - drag.current.y) / scale)) }); }} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }}><span>拖动提词窗 · 演示</span><button className="icon-button" aria-label="关闭悬浮演示" onPointerDown={e => e.stopPropagation()} onClick={() => navigate("prepare")}><Cross2Icon /></button></div><div className="float-text" style={{ fontSize: Math.min(settings.font, 34), transform: settings.mirror ? "scaleX(-1)" : undefined }}><p>{lines[lineIndex]}</p><p>{lines[lineIndex + 1]}</p></div>{transport}<div className="float-status">{remaining !== null ? `${remaining} 秒后开始` : progress >= total ? "已到稿件末尾" : playing ? "匀速滚动中" : "已暂停"}</div></section><div className="stage-bottom"><p>{device.platform === "ios" ? "iPhone 的实际浮窗由系统画中画提供，外观与操作会受系统限制。" : "安卓原生版将单独验证悬浮权限和录像时的音频共享。"}</p><button className="secondary" onClick={() => navigate("prepare")}>回到提词准备</button></div></main>}
    <BottomSheet open={sheet === "settings"} onOpenChange={open => { if (!open) setSheet(null); }} title="按你的习惯来" description="设置会保存在这台设备的浏览器里。" snap={0.81}><div className="jz-sheet-content">{adjust}<div className="setting-row"><div><strong>镜像文字</strong><p>使用提词反射镜时开启</p></div><button className={`toggle ${settings.mirror ? "on" : ""}`} role="switch" aria-checked={settings.mirror} aria-label="镜像文字" onClick={() => setSettings(s => ({ ...s, mirror: !s.mirror }))}><span /></button></div><div className="setting-row"><div><strong>开始前倒计时</strong><p>给自己一点准备时间</p></div><div className="countdown-choices">{[0, 3, 5].map(n => <button key={n} aria-pressed={settings.countdown === n} onClick={() => setSettings(s => ({ ...s, countdown: n }))}>{n === 0 ? "关" : `${n}秒`}</button>)}</div></div><button className="secondary" onClick={exportScript}><DownloadIcon />导出当前稿件</button><button className="primary" onClick={() => setSheet(null)}>设置好了</button></div></BottomSheet>
    <BottomSheet open={sheet === "library"} onOpenChange={open => { if (!open) setSheet(null); }} title="我的稿件" description="保存在当前浏览器，重要稿件可以导出。"><div className="jz-sheet-content"><button className="secondary" onClick={createScript}><PlusIcon />新建稿件</button>{scripts.map(s => <button className="library-row" key={s.id} onClick={() => selectScript(s.id)}><FileTextIcon /><span><strong>{s.title || "未命名口播"}</strong><small>{count(s.body)} 字</small></span>{s.id === script.id ? <CheckIcon /> : <ChevronRightIcon />}</button>)}</div></BottomSheet>
    <BottomSheet open={sheet === "import"} onOpenChange={open => { if (!open) setSheet(null); }} title="把稿子带进来" description="支持 UTF-8 的 TXT、Markdown，或直接粘贴。" snap={0.85}><div className="jz-sheet-content"><label className="file-label"><FileTextIcon />{fileName || "选择 TXT / Markdown 文件"}<input aria-label="选择稿件文件" type="file" accept=".txt,.md,text/plain,text/markdown" onChange={async e => { const file = e.target.files?.[0]; if (!file) return; const text = await file.text(); if (text.includes("\uFFFD")) { setImportError("这个文件不是 UTF-8 编码，可以复制文字粘贴到下方。"); return; } setFileName(file.name); setPaste(text); setImportError(""); }} /></label><div className="or-divider">或粘贴稿件</div><KeyboardTextarea className="paste-input" aria-label="粘贴稿件" value={paste} onChange={e => { setPaste(e.target.value); setImportError(""); }} onBlur={() => keyboard.hide()} placeholder="长按粘贴，或者直接输入……" />{importError && <p role="alert" className="input-error">{importError}</p>}<button className="primary" onClick={() => importText(paste, fileName || "导入的口播")}>导入这份稿子</button></div></BottomSheet>
    <BottomSheet open={sheet === "help"} onOpenChange={open => { if (!open) setSheet(null); }} title="先把使用方式说清楚" description="这是界面与操作原型，不是已安装的原生提词器。" snap={0.78}><div className="jz-sheet-content help-content"><h3>这份原型可以体验什么？</h3><p>编辑与保存稿件、导入导出、字号与语速、匀速练习、重读定位，以及悬浮窗的屏幕内演示。</p><h3>拍摄继续用你熟悉的 App</h3><p>原生版优先验证这一流程。iPhone 采用画中画研究路线；安卓参考原生悬浮窗与无障碍服务的实现。</p><h3>语音跟随还没有接入</h3><p>跨 App 录像会涉及麦克风共享，必须在真实手机和拍摄 App 上分别测试。此处的播放只按设定语速滚动，不会请求麦克风。</p><button className="primary" onClick={() => setSheet(null)}>明白，继续体验</button></div></BottomSheet>
    {notice && <div className="jz-toast" role="status">{notice}</div>}
  </div>;
}
