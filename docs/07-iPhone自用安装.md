# iPhone 13 自用安装准备

目标手机：iPhone 13，用户提供的系统版本为 iOS 27.0.1。最新 iOS IPA 已编译和下载，但截至 2026-10-26，仍未在这台手机完成签名安装。当前实际阻碍是 Apple 登录错误 -80046；重复输入正确密码和验证码没有解决它。[AltStore 同类报告](https://github.com/altstoreio/AltStore/issues/1840)。

## 不买 Mac 的路径

由 GitHub 的 macOS 构建环境生成未签名 IPA，再用本人 Windows 电脑上的签名工具完成自用安装。不要求把应用上架，也不需要先买付费开发者会员；免费签名通常需要周期刷新。已在本机准备 iTunes、iCloud、Apple Mobile Device Support、AltServer 和 Sideloadly，且 USB 连接已被验证。

## 安装顺序

1. 按 [AltStore 官方 Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)准备 AltServer，以及该说明要求的 Apple 软件。已有环境可直接核对，不重复安装。
2. 用数据线连接 iPhone，解锁并信任这台电脑。按官方说明开启 Wi-Fi 同步，便于后续刷新。
3. 在自己的电脑上，通过 AltServer 选择安装 AltStore 到这台 iPhone，并自行输入本人 Apple ID。账号密码不需要发送到聊天或写进项目。
4. 按 iPhone 提示完成开发者模式或开发者信任设置。具体页面以手机显示为准。
5. 从 [iOS 实验版 Releases](https://github.com/tangchengjiao/jianzhou-mobile-prompter/releases/tag/ios-v0.1.0-preview.2)直接下载 `JianzhouPrompter-unsigned.ipa`，不要解压 IPA 本身。
6. AltStore 安装成功后，可将 IPA 放到 iPhone“文件”中，在 My Apps 页用加号导入。也可在 Windows 的 Sideloadly 中选择 IPA，使用自己的 Apple ID 签名。**当前两款工具都在登录阶段返回 -80046，故此步骤尚未完成**；使用新版 IPA 不会自行消除这个错误。
7. 打开见舟提词。先用全屏匀速阅读；启用全屏语音练习时再允许麦克风和语音识别。最后尝试系统画中画，并分别在常用拍摄应用中实际录制。

开源备选 [AltKeeper](https://github.com/BartolomeoRusso9/altkeeper) 已在这台 Windows 11 上完成 USB 配对并读取手机状态，但尚未用本人 Apple ID 完成签名安装；项目作者也未验证 Windows 11 的完整安装闭环。因此当前仍不能把它写成已解决 -80046 的方案。

## 需要本人确认的结果

- 应用能在手机打开，稿件可修改并保留。
- 当前字号在真实拍摄距离下看得清，暂停和重读容易操作。
- 系统中文端侧识别可用；如果显示不可用，先保留匀速提词并记录原因。
- 开拍、剪映或系统相机真正录像时，提词窗仍在，原视频有声音。
- 经过一段常见口播后，没有明显影响拍摄的发热或卡顿。

免费安装后的有效期与刷新规则见 [AltStore 官方说明](https://faq.altstore.io/altstore-classic/your-altstore)。若当前 AltStore 对 iOS 27.0.1 有兼容问题，需要按其官方支持状态处理，不能把编译成功当作安装兼容已经验证。
