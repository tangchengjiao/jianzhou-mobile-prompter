# 见舟提词 · Android 原生版（开发中）

基于 [Suflyor](https://github.com/olerast67/voice-teleprompter-android) 的 Android 原生实现改编，保留 GPL-3.0 许可证和作者来源。当前正在加入中文语音、中文字符定位与见舟的交互风格。

应用标识为 `com.jianzhou.prompter`，Debug 版另加 `.debug`；不会覆盖上游 Suflyor。内部代码包名保留以便跟进上游实现。

构建需要 JDK 17、Android SDK 36 和 Gradle 9.1。`local.properties` 只配置本机 SDK 路径，不进入源码。准备语音文件后执行：

```powershell
python ../scripts/prepare_android_speech.py --cache D:/DevCaches/jianzhou-mobile/downloads
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:testDebugUnitTest --tests '*Chinese*'
```

语音资源需要 sherpa-onnx 1.13.8 AAR 和中文/英文小型 Zipformer int8 模型。文件不混进源码历史，不包含原项目的俄文和英文独立模型。相关开源来源和许可见 `THIRD_PARTY_NOTICES.md`。

这是本项目原生开发的一部分，编译通过也不代表目标拍摄 App 中的语音跟随已经实测。

Windows 的目录含中文时，可以将构建输出放到英文路径，避免旧 JDK 的测试类路径问题：

```powershell
.\gradlew.bat -PjianzhouBuildRoot=D:/DevCaches/jianzhou-mobile/build :app:testDebugUnitTest --tests com.olerast.suflyor.ChineseTrackerTest
.\gradlew.bat -PjianzhouBuildRoot=D:/DevCaches/jianzhou-mobile/build :app:assemblePreview
```

Preview 使用优化配置，并用本机调试签名签署，供个人实验；不是正式发布签名版本。最低 Android 10，当前打包 arm64-v8a。
