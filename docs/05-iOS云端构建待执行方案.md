# iOS 云端构建方案（未执行）

当前已经准备原生 SwiftUI/AVKit/Speech 源码、XcodeGen 工程和四项中文定位测试。Windows 只能做语法与文件检查；要得到真实的 iPhone 编译结果，需要 macOS/Xcode。

已准备的执行文件：`.github/workflows/ios-native.yml`。它只接受手动触发，不会因每次改稿或提交自动运行。

## 具体将执行什么

1. 在 macOS 标准 GitHub-hosted runner 上生成 Xcode 工程。
2. 编译面向 iPhone 的 Release 应用，不使用开发者证书。
3. 在 iPhone 模拟器运行中文归一化和定位单元测试。
4. 成功后打出未签名 IPA，保存日志，构建产物保留三天。

这个 IPA 不是点击即可安装的商店包。后续仍需用本人 Apple ID 的自用签名方式安装；可研究 Windows + AltStore 的流程，免费签名通常需要周期刷新。构建不需要把 Apple ID 密码交给本项目或写进仓库。

## 仓库与额度

需要用户决定是否允许创建新的 GitHub 构建仓库。当前尚未创建、上传或触发。

- 若选择公开源码仓库：标准 GitHub-hosted runner 的 Actions 使用按 GitHub 官方规则免费；仅上传项目源码、公开设计资料与说明，不上传私人稿件、设备数据或凭据。
- 若选择私有仓库：先检查账号 Actions 额度和限制；未核对前不承诺免费，也不擅自启用付费额度。
- 若暂不创建：保留已准备工程，等有可用 Mac 后构建。

来源：[GitHub Actions 计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)。这份方案解决的是构建环境，不代表 iPhone 真机悬浮或语音跟随已经验证。
