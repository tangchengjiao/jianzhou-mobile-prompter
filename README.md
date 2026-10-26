# 见舟提词 · 手机端

面向中文口播的个人提词工具：编辑稿件、全屏练习，并研究配合现有拍摄应用使用的悬浮提词。

**[直接下载 Android APK](https://github.com/tangchengjiao/jianzhou-mobile-prompter/releases/download/v0.1.0-preview.4/JianzhouPrompter-Android-0.1.0-preview.4.apk)** · **[直接下载 iPhone 未签名 IPA](https://github.com/tangchengjiao/jianzhou-mobile-prompter/releases/download/ios-v0.1.0-preview.6/JianzhouPrompter-unsigned.ipa)** · [安装与验证说明](docs/06-原生实验版安装与验证.md)

| 平台 | 当前阶段 | 使用条件 |
| --- | --- | --- |
| Android | Preview 4：单行悬浮栏、透明度滑条、稿件勾选批量导出；98 项测试通过，真实录像待验收 | Android 10+、arm64；约 90 MB，内含离线语音模型 |
| iPhone / iPad | 构建 6 已覆盖安装：收紧跨段定位、同一识别修订不重复推进；录像时默认只留停止键。保留即时预览及镜像设置；17 项单元测试和 3 项操作回归通过，真实跟读待复测 | iOS 17+；iPhone 13 / iOS 27.0.1 安装方法已沉淀 |
| 交互原型 | 可在电脑预览 iPhone / Pixel 操作流程 | 浏览器原型不具备原生跨 App 悬浮能力 |

先做好本人拍摄时的阅读体验：无需账户与会员，稿件保存在本机；原生悬浮能力和录音共享按手机及拍摄应用实际验证，不承诺“任何 App 都能语音跟随”。

## 当前交付

- [研究与技术决策](docs/01-研究与技术决策.md)：桌面源码分析、开源比较、苹果与安卓能力边界、REA 调研。
- [产品需求与交互](docs/02-产品需求与交互.md)：首版范围、页面、中文跟读策略、拍摄时的操作。
- [开发与真机验证计划](docs/03-开发与真机验证计划.md)：先验证核心用法，再完成双端；安装方式和验收标准。
- [原生实验版安装与验证](docs/06-原生实验版安装与验证.md)：安装、实际测试范围和下一步。
- [iPhone 真机试拍步骤](docs/09-iPhone真机试拍.md)：安装后的稿件、语音练习和真实录像检查。
- [iPhone 跟拍改进](docs/11-iOS跟拍改进.md)：跟读停滞原因、自动预览、取景与成片镜像，以及本轮验证范围。
- [iPhone 防误跳与拍摄界面](docs/12-iOS误跳与拍摄界面.md)：构建 6 的连续定位、手动定位和录制中隐藏工具。
- [安卓本次更新](docs/08-安卓试用反馈与更新.md)：悬浮窗宽高与位置、稿件保存/导出，以及与开拍同时收音的无障碍设置。
- [iOS 原生工程](ios/)：SwiftUI / AVKit / Speech，与构建说明。
- [Android 原生工程](android/)：基于 Suflyor 改编的中文离线实验版。
- `design/`：三张界面设计。用户已选择第三张作为交互原型基础。
- `prototype/`：以第三张设计为基础的交互原型。它用于确认操作流程，不能代表原生画中画或麦克风共享已经验证。

## 产品路线

1. 稿件编辑、字体与速度、全屏练习、悬浮准备的可操作原型。
2. iOS 最小画中画实验，分别配合开拍、剪映和系统相机验证。安卓同时按原生无障碍悬浮窗方案设计。
3. 中文语音识别与稿件定位实验；以用户本人实际口播的表现决定默认参数。
4. iOS 原生自用版本，再完成 Android 自用版本与安装说明。

所有“可以悬浮”“能够跟读”的结论须写清楚平台、拍摄 App 和验证状态。网页内模拟悬浮窗不算跨应用能力。

## 本地开发

交互原型使用 Product Design 的移动设备模板，含 iPhone / Pixel 预览。采用 pnpm。

```powershell
cd prototype
pnpm install
pnpm dev --host 127.0.0.1 --port 4186
pnpm build
```

原生应用分别使用 SwiftUI / AVKit 和 Kotlin / Compose。Android 已有用户初测反馈与新版 APK；iOS 未签名 IPA 已发布，仍需自用签名。两端的完整录像体验尚待真机验收。

## 开源来源

Android 基于 [Suflyor](https://github.com/olerast67/voice-teleprompter-android) 的 GPL-3.0 原生实现改编，增加中文识别适配、中文数字与位置映射、中文界面和个人拍摄默认设置。iOS 画中画结构改编自 [Reeb](https://github.com/aiwithenoch/reebopensource) 的 MIT 实现，并参考 [Open Prompter](https://github.com/lelanddutcher/open-prompter) 的语音与阅读设计。保留对应作者和许可证。

本项目以 GPL-3.0 提供；第三方代码和语音模型保留各自许可，详见各原生工程中的说明。Android 语音资源通过脚本从官方源准备，不进入源码仓库。

<!-- JIANZHOU-CONTACT-QR:START -->
## 联系二维码

| 微信 | 抖音 | 视频号 | 公众号 |
| :---: | :---: | :---: | :---: |
| <img src="https://hualian-ai.pages.dev/assets/contact/wechat-qr.png" alt="见舟微信二维码" width="160"> | <img src="https://hualian-ai.pages.dev/assets/contact/douyin-qr.png" alt="见舟抖音二维码" width="160"> | <img src="https://hualian-ai.pages.dev/assets/contact/channels-qr.png" alt="见舟AI赋能视频号二维码" width="160"> | <img src="https://hualian-ai.pages.dev/assets/contact/official-account-qr.jpg" alt="公众号二维码" width="160"> |
| `DST10209` | `74683161410` | 见舟AI赋能 | 扫码关注 |
<!-- JIANZHOU-CONTACT-QR:END -->

<!-- JIANZHOU-PUBLIC-INFO:START -->
## 企业服务与联系

**华链 AI** · 企业 AI 业务落地与内生能力建设

培训与 FDE 培养 · 场景验证 · 智能体定制 · 企业实施 · 产品应用支持

[华链 AI 官网](https://hualian-ai.pages.dev) · [企业服务](https://hualian-ai.pages.dev/services/) · [服务参考价](https://hualian-ai.pages.dev/pricing/) · [企业宣传册](https://hualian-ai.pages.dev/downloads/company-brochure.pdf) · [合作咨询](https://hualian-ai.pages.dev/contact/)

咨询联系人：**见舟** · 微信：**`DST10209`**

<img src="https://hualian-ai.pages.dev/assets/contact/wechat-qr.png" alt="见舟微信二维码" width="200">
<!-- JIANZHOU-PUBLIC-INFO:END -->
