# 开源来源与许可

本 Android 原生版本是 [Suflyor](https://github.com/olerast67/voice-teleprompter-android) 的派生实现，保留 GPL-3.0 许可证全文于 `LICENSE`。本项目改动包括中文语言/数字规范化、中文稿件位置映射、中文界面、配色、应用标识、语音资源和默认拍摄行为。

- sherpa-onnx 1.13.8：Apache-2.0，来源为 [官方发行](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.8)。AAR 内 ONNX Runtime 等组件保留各自许可证；sherpa-onnx 的构建依赖以该发行源码为准，其中包含 GPL-3.0 的 espeak-ng 相关代码。
- 中文/英文流式 Zipformer 小模型：来源为 [sherpa 官方模型文档](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html#sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16-bilingual-chinese-english)及其指向的官方发行资源。它是语音实验候选；在对外分发含该模型的安装包前仍需核对原模型的许可材料，不把框架许可证自动套用到权重上。
- AndroidX/Jetpack Compose、Kotlin、Material 图标等保留各自 Apache-2.0 许可。

目前仅本地开发和个人自用实验，未发布到 GitHub 或应用市场。
