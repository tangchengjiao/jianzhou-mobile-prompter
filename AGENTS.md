# 见舟手机提词器

- 用户的目标是可自用的 iOS 与 Android 应用，主要在原有拍摄 App 中使用悬浮提词；不能用网页演示替代原生验收。
- 界面沿用 `design/03-writing-selected.png`，先编辑稿件，再进入提词准备；中文大字与简洁紫色控件优先。
- UTF-8；优先 pnpm；不增加摘要校验清单或大量罕见场景测试。
- `prototype/AGENTS.md` 只约束浏览器原型；原生实现位于 `ios/` 与 `android/`。
- Android 为 Suflyor 的 GPL-3.0 派生实现；保留上游来源与许可证。iOS 中保留 Reeb 的 MIT 声明。
- 发布遵从 `D:/见舟品牌与发布中心/统一发布标准.md` 和 `public/brand.json`；不要自行改写其他仓库或企业官网。
- 安装包放 Releases，私人稿件、设备运行数据、密钥和本机依赖不进入公开仓库。
- iPhone 安装已在 Windows + iPhone 13 / iOS 27.0.1 成功。后续安装/续签先读 `docs/07-iPhone自用安装.md`，复用 iLoader + 本机客户端信息适配的已验证路径；遇到新错误先读取完整错误，不让用户重复输密码，不重新冷启动 AltServer 全套流程。
