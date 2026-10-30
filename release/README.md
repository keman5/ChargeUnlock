# 电亮 PlugLit 发布

所有构建在本机通过根 `build.sh` 执行。发布私钥、证书和描述文件位于仓库外的 `~/.config/pluglit/signing/`，API 密钥存于 macOS 钥匙串。不要提交或上传这些私钥到官网。

## 命令

- `./build.sh website`：网站生成、链接与服务端验证。
- `./build.sh website-deploy`：本地构建后部署到 Cloudflare；可用 `WRANGLER_BIN` 指定已有 wrangler CLI 的 JS 入口。
- `./build.sh appstore-check`：自检、隐私清单、上架文案与在线 URL 检查、Apple 账户资源检查。
- `./build.sh appstore-archive`：Release 归档、签名验证并导出 App Store IPA，产物位于 `~/Library/Caches/ChargeUnlock/Release/`。
- `ASC_APP_ID=<真实AppID> ./build.sh appstore-upload`：先 dry-run，再上传并等待构建处理；**不自动发起审核**。

App Store 元数据存于 `metadata/app-info` 与 `metadata/version/0.4.0`。审核电话只写入忽略的 `release/contact.local.json`，不公开在官网或仓库。

## 密钥是什么、如何提供

1. App Store Connect → 用户和访问 → 集成 → App Store Connect API → 创建团队密钥。App Manager 可用于版本资料和构建管理；签名管理还需具备 Certificates, Identifiers & Profiles 权限。团队 API 密钥通常有跨 App 访问范围，应按需要分配权限。
2. 下载一次性的 `AuthKey_<KeyID>.p8`，存仓库外并 `chmod 600`。提供本机路径、Key ID、Issuer ID 即可，不要粘贴私钥。用 `asc auth login --private-key <路径> --key-id <ID> --issuer-id <Issuer> --network` 保存到本机钥匙串。
3. `.p8` 仅授权 Apple API。真正签名还需要 Apple Distribution 证书及其私钥，以及匹配 bundle ID 的 App Store provisioning profile；本项目使用本机生成的 CSR/私钥申请证书。
4. 若以后使用远程 CI，私钥/加密 p12 和独立密码分别放在 CI secret store，通过受控临时文件使用；不需要把签名密钥上传到官网或 VPS。当前全部在本机签名。

## 中国大陆与审核边界

- 运营者：吴凯；支持邮箱：feedback.pluglit@macseek.cc。Apple 团队和法律卖方是 wangwang yang，用户已确认取得账户持有人授权，并计划以吴凯申请的个体工商户主体办理 App 备案；待提供真实工商登记名称和备案结果后核对资料。
- 用户确认目前没有 App 备案号。必须通过合适的接入服务商办理适用的 App 备案，准备主体身份、负责人联系方式、App 名称、包标识、签名公钥/指纹、域名及服务接入信息等，以实际主管部门/服务商要求为准。网站备案号不能随意替代 App 备案号；不得填造假编号。
- Cloudflare 全球网络部署不代表已完成中国大陆备案，也不保证国内各网络可达。反馈数据可能存储在境外，已将自愿上传、用途、字段、保留与删除说明加入应用及官网；真实数据出境合规仍需结合运营主体和业务处理。若要求境内存储，需要改用符合要求的境内接入与备案方案。
- PiP 循环视频用于保持屏幕常亮仍有 Apple 2.5.4 后台用途、4.2 最小功能审核风险。已移除私有 suspend；不会通过隐藏功能、审核开关或虚假说明规避审核。
- EU 分发还需 Apple 账户持有人提供真实 DSA 交易商状态；不能替用户虚构法律身份。

官方依据：
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
- https://sparkle-project.org/（macOS 框架，不用于 iOS）

## 官网反馈运维

Cloudflare Worker `auv-pluglit`，D1 `pluglit-feedback`。仅后台账户可读反馈表；官网没有读取/列举反馈 API。用户凭随机 UUID 编号删除其在线记录。每 IP 每分钟限 10 次，JSON 96 KB 上限，诊断字段白名单，参数化 SQL，关闭 Worker 请求日志。每小时删除超过 30 天的记录（最长会有一个调度周期延迟）；Cloudflare 灾备保留依供应商策略。

读取反馈请在 Cloudflare D1 控制台运行限定范围的查询，避免将用户报告打印到公共日志。没有自动邮件转发；邮箱为用户自愿邮件联系的入口。上线测试只使用合成记录并删除。

## 当前发布状态（2026-10-31）

- App ID：6828947154；bundle ID：local.chargeunlock.ios；版本：0.4.0，最新本地构建 7。
- 协议阻塞已经解除。API 密钥在钥匙串；Apple Distribution 证书和 App Store profile 已创建，Release 本地签名、归档、导出成功。
- App Store 已保存中文名称/副标题/描述/关键词/支持与隐私网址、工具分类、4+ 年龄申报、无第三方内容、免费价格、审核联系资料与审核说明。初始版本不能填写 whatsNew；CLI 对此的警告不应通过伪造字段解决。
- 销售范围暂仅选择中国大陆，不自动扩展新地区；通过后手动发布。没有 App 备案号，未提交审核。
- 构建 6 曾上传但处理失败：Apple 错误 90534，拒绝 Xcode 27.2 (27B52) / iphoneos27.2 (24B8118)。Apple 官网已列出该正式版，但上传后端当前尚未接受；不能伪造 SDK 标识。构建 7 未重复上传同一不受支持工具链。
- 官方下载页同时列有 Xcode 27.1 (27A9275)，但本机 Edge 下载被 ERR_BLOCKED_BY_CLIENT 阻断。安装后用 `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer ./build.sh appstore-archive` 重建，勿全局替换当前开发工具链。重新上传需实际核验处理状态。
- 隐私三项数据用途已保存，用户于 2026-10-31 明确确认发布；最终发布回执见 VALIDATION.md。
- `./build.sh appstore-screenshots <SIMULATOR_UDID>` 从 Debug 页面入口捕获真实 UI，导出无透明 JPEG。模拟器不能展示有效 PiP；商店仅使用指南和反馈页，主屏“不支持 PiP”截图不上传。
- `./build.sh feedback-network-check` 向官网提交合成内容，验证 URLSession、重复重试与删除。不要用此脚本发送用户真实诊断资料。
