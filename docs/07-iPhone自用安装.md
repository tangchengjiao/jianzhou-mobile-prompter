# iPhone 自用安装：已成功的方法与踩坑

2026-10-26，Windows 电脑 + iPhone 13 / iOS 27.0.1 已完成见舟提词的签名安装。手机安装列表读到 0.1.0、构建 3；开发者模式开启，用户已打开应用并实际测试系统画中画。此记录优先于先前“尚未安装”的排错说明。

## 下次直接走这条路径

1. 连接 iPhone，解锁并信任电脑。现有 iTunes / Apple Mobile Device 驱动工作正常就继续使用，不重新安装一整套依赖。
2. 打开桌面的“见舟提词安装与续签”。快捷方式会启动本机版本信息适配脚本和已安装的 iLoader。当前本机脚本位于 `D:/DevCaches/jianzhou-mobile/iloader/`，不含账号密码。
3. iLoader 的 Anisette 自定义服务器使用 `http://127.0.0.1:48219`。先确认适配脚本运行，再登录。
4. Apple 账号密码、验证码只在本机 iLoader 窗口输入。“保存凭据”不勾选。登录成功后，在设备列表选连接的 iPhone，点“导入 IPA”，选择本次发布的未签名包。IPA 不解压。
5. 首装时，手机“设置 → 隐私与安全性 → 开发者模式”开启，按提示重启，再确认开启。然后在“设置 → 通用 → VPN 与设备管理 → 开发者 App”下信任自己的 Apple 账号；出现“允许并重新启动”就按屏幕完成。
6. 更新时继续用同一个 Apple 账号覆盖安装，保留应用内稿件。先导出重要稿件，不通过删除旧 App 来解决登录报错。
7. 以手机安装列表中的版本、手机实际打开首页为安装证据。导入 IPA、电脑显示编译成功或出现桌面快捷方式都不是安装成功的证据。

当前 IPA 下载入口见仓库 README。免费开发签名通常为 7 天，需要本人周期续签；桌面快捷方式仅在打开时工作，没有另建后台监控。

## 两个错误不能混着处理

| 现象 | 本次证据 | 有效处理 |
| --- | --- | --- |
| AltServer、Sideloadly 验证码后报 `-80046` | 两款工具均失败；换一个 IPA 不能消除 | 停止反复登录，改查认证协议与客户端信息 |
| iLoader 2.4.0 报 `-23782`，称需要 macOS 10.13 或更新 | 当时两个候选服务器都实际返回 macOS 10.12.6 | 适配返回的客户端版本信息；不用因此要求用户买 Mac、改密码或重装手机 |
| iLoader MSI 返回 1619 / 1603 | 本机 MSI 路线失败 | 同一官方版本的 EXE 安装程序成功 |
| 手机提示“不受信任的开发者” | 此时包已安装，开发者模式也已开启 | 在手机完成开发者信任，不需要重输 Apple 密码 |

## 本次版本信息适配怎样生效

公开脚本为 [scripts/ios_client_info_bridge.py](../scripts/ios_client_info_bridge.py)。依赖 Python 和 aiohttp，仅监听本机 `127.0.0.1:48219`。

```powershell
python -m pip install aiohttp
python scripts/ios_client_info_bridge.py
```

脚本对 `/v3/client_info` 使用当前 SideStore / SideInstaller 同类修复采用的 macOS 26.6 客户端描述；其余 Anisette 请求仍转发到 `new.ani.sidestore.io`。iLoader 的 Apple 账号登录请求直接发往 Apple，脚本没有账号登录接口，不记录请求正文，也不保存密码、验证码或配对数据。

本次先验证了版本信息请求返回 200、预配 WebSocket 能收到正常的标识符请求，再用窗口中已有的登录信息重试一次；随后 iLoader 登录成功、签名安装成功。不是“连续多试几次碰巧成功”。

将来出现不同错误时，先读完整错误和公开的客户端元数据。脚本中的版本描述和上游服务可能随工具更新而变化；本次经验不能变成“以后任何错误都重置或反复登录”。Apple 认证正常后可优先采用工具的新修复版本。

## 原始参考

- [iLoader 官方发布](https://github.com/nab138/iloader/releases/tag/v2.4.0)：本次使用的官方 EXE。
- [iLoader 同类 -23782 报告](https://github.com/nab138/iloader/issues/1032)。
- [SideInstaller 修复说明](https://github.com/FrizzleM/SideInstaller/blob/main/CHANGELOG.md)：1.6.1 解释了旧 macOS 描述与 -23782，以及 Mac Anisette 与 -80046 的关系。
- [客户端描述来源](https://github.com/FrizzleM/SideInstaller/blob/main/ios-app/PairingTargets.swift)：SideStoreAnisetteHandoff。
- [Apple 开发者模式说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。

## 安装和功能验收分开

安装已成功。系统画中画能打开不等于跨 App 语音跟随成立。系统画中画由 iOS 控制位置、尺寸和不透明视频窗口；本项目在该模式使用匀速。需要一边录像一边跟读、提词框能放中间时，用户已同意采用 App 内拍摄，通过同一个采集会话把声音送给录像与识别。新功能必须另做真机成片、声音及跟读验收。
