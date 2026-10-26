# iOS 云端构建方案与执行记录

当前已准备原生 SwiftUI/AVKit/Speech 源码、XcodeGen 工程和四项中文定位测试。用户已明确授权公开源码并使用标准免费构建；[仓库](https://github.com/tangchengjiao/jianzhou-mobile-prompter)已创建。[第二次云端构建](https://github.com/tangchengjiao/jianzhou-mobile-prompter/actions/runs/40251322918)已整体成功，包含 iPhone 设备架构编译、模拟器测试和未签名 IPA 打包。该次构建使用原先的 macOS 15 工具链；确认目标手机为 iPhone 13 / iOS 27.0.1 后，工作流已调整为 Xcode 27，后续会单独验证该目标。

后续 [Xcode 27 构建](https://github.com/tangchengjiao/jianzhou-mobile-prompter/actions/runs/40254472312)已整体成功，增加 iPhone 13 / iOS 27 模拟器的编辑保存与阅读操作测试，以及原生首页截图。未签名 IPA 和截图已发布到 [iOS 实验版 Releases](https://github.com/tangchengjiao/jianzhou-mobile-prompter/releases/tag/ios-v0.1.0-preview.1)，并取回本机。尚未在目标手机签名安装或录像。

执行文件：`.github/workflows/ios-native.yml`。接受手动触发，也会在默认开发分支的 iOS 源码或该工作流发生变更时运行；Android 修改不触发它。

## 具体将执行什么

1. 在 macOS 标准 GitHub-hosted runner 上生成 Xcode 工程。
2. 编译面向 iPhone 的 Release 应用，不使用开发者证书。
3. 在 iPhone 模拟器运行中文归一化和定位单元测试。
4. 成功后打出未签名 IPA，保存日志，构建产物保留三天。

这个 IPA 不是点击即可安装的商店包。后续仍需用本人 Apple ID 的自用签名方式安装；可研究 Windows + AltStore 的流程，免费签名通常需要周期刷新。构建不需要把 Apple ID 密码交给本项目或写进仓库。

## 仓库与额度

用户已经选择公开源码仓库，源码已上传并触发构建。下列为原先提供的方案及费用边界，后续不用重复询问同一次仓库创建授权。

- 若选择公开源码仓库：标准 GitHub-hosted runner 的 Actions 使用按 GitHub 官方规则免费；仅上传项目源码、公开设计资料与说明，不上传私人稿件、设备数据或凭据。
- 若选择私有仓库：先检查账号 Actions 额度和限制；未核对前不承诺免费，也不擅自启用付费额度。
- 若暂不创建：保留已准备工程，等有可用 Mac 后构建。

来源：[GitHub Actions 计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)。这份方案解决的是构建环境，不代表 iPhone 真机悬浮或语音跟随已经验证。
