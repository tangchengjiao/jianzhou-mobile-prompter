# 见舟提词 · iOS 原生实验工程

当前为原生源码与最小技术实验，尚未由 Xcode 编译，尚未在 iPhone 验证，未生成可安装 IPA。

## 已有源码

- SwiftUI 稿件入口：编辑、本地稿库、UTF-8 TXT/Markdown 导入、TXT 导出。
- 全屏提词：字号/语速、镜像、倒计时、暂停、上一句/下一句、点句定位。
- 原生 AVKit sample-buffer 画中画：真实文字帧、启动状态、系统播放/暂停/跳转、本次实验记录。
- 中文全屏语音练习：探测 `zh-CN` 端侧识别能力，不支持时给出原因；不会静默切换在线收费接口。
- 中文字符定位：原稿 UTF-16 映射、数字读法归一化、局部模糊匹配、重读定位。

PiP 采用不占麦克风的匀速模式。跨 App 语音跟随并未实现为可用承诺；这是后续真机实验的核心边界。当前也没有应用内相机。

## 在 Mac 构建

需要 Xcode 16+ 与 XcodeGen。最低系统暂定 iOS 17，待确认用户手机系统后调整。

```bash
cd ios
xcodegen generate
open JianzhouPrompter.xcodeproj
```

在 Xcode 中为 `JianzhouPrompter` 选择自己的 Team 和唯一 Bundle Identifier，连接 iPhone 后 Run。仓库不包含开发者账号、证书或签名材料。

模拟器编译和单元测试示例（设备名按本机 Xcode 的可用列表选择）：

```bash
xcodebuild -project JianzhouPrompter.xcodeproj -scheme JianzhouPrompter -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project JianzhouPrompter.xcodeproj -scheme JianzhouPrompter -destination 'platform=iOS Simulator,name=iPhone 16' test
```

命令是交接说明，不是已经执行的结果。Windows 语法检查不能替代这些步骤。

## 真机实验

1. 首先不启用语音：进入“准备悬浮提词”，保持预览可见，启动系统画中画。
2. 依次切换开拍、剪映和系统相机，真正录制短片；分别记录窗口存活、滚动和原视频声音。
3. 在提词器里查看“本次画中画记录”，把实际使用的手机、iOS、拍摄 App 版本和接麦方式一起记录。
4. 返回全屏阅读，打开“语音跟读（本机练习）”，允许权限后，用中文口播测试停顿、改口和重读。
5. 先完成常见 5 分钟口播，再决定是否扩展长录制。

## 开源来源

画中画结构参考并改编自 [Reeb](https://github.com/aiwithenoch/reebopensource) 的 `PipController.swift`、`PipFrameRenderer.swift`。保留 MIT 作者声明和完整许可证于 `ThirdParty/Reeb-LICENSE.txt`。中文布局和识别定位使用本项目实现，不携带 Reeb 的英文 Whisper 模型。
