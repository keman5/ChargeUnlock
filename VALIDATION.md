# 电亮 PlugLit 发布验收 · 2026-10-31

## 提审后的本地界面调整（尚未上传）

- 隐私政策与使用条款共用阅读页增加章节字重、行距、段落间距和可读宽度；支持实时字体大小变化及链接识别，法律正文未删改。
- 浅色主题橙色从 `#C44E00` 调亮为 `#D65B00`。关于页删除本地充电说明及重复外链提示；首页移除重复锁屏说明卡，相关使用限制仍在指南与条款中。
- Xcode 27.1 经根 `build.sh simulator-install` 完成四组测试、媒体检查、模拟器构建和安装；检查浅色隐私页、浅/深色条款页、动态字体及关于页。截图：`release/evidence/privacy-ui.png`、`terms-ui.png`、`about-clean-ui.png`。
- 本轮没有真机安装、官网发布或替换已提交审核的构建 8。后续发布需递增构建号并重新归档。

## 最新真机安装（08:09 Asia/Shanghai）

- 使用 Xcode 27.1，通过 `./build.sh ios-install 00008150-0018398021EB401C B3ZTS6G82B` 将最新源码的开发签名版覆盖安装到 iPhone 17；测试、真机构建、签名验证、安装及启动均成功。
- 从设备读取确认 `local.chargeunlock.ios` 的版本为 0.4.0、构建号 8。未卸载应用；本次仅验证安装与启动，没有重新执行完整充电/PiP/锁屏回归。

## 最终提交回执（01:46 Asia/Shanghai，优先于以下历史记录）

- Xcode 27.1 (27A9275) 独立安装完成；Apple 应用签名、Gatekeeper 及首次运行状态检查通过，未切换全局 Xcode。
- 使用该工具链经根 `build.sh` 完成测试、Release 归档、签名验证、导出及上传。实际 IPA 为 0.4.0 (8)、iphoneos27.1 (24A94232)，包括最新关于页面与圆圈信息图标。
- Build `9237d43f-9ed0-4c82-bf24-e326afb419b4` 处理成功并关联；`asc validate --ipa` 零阻断。隐私页已发布，147 销售地区不含 CHN 与欧盟 27 国，保持手动发布。
- Submission `53810495-9c0a-4c0e-97a6-c1ac7664b268` 已于 `2026-10-30T17:46:35.911Z` 正式提交，Apple 状态 `WAITING_FOR_REVIEW`。证据：`release/evidence/submission-0.4.0-8.json`。
- 初次最终验证发生网络超时，检查已有唯一 READY_FOR_REVIEW 草稿后沿用同一草稿提交成功；未创建重复审核请求。
- 本轮未重新安装到真机或执行完整 PiP 插拔电回归。尚未审核通过或上架，PiP 用途相关审核风险仍由 Apple 判定。

## 本轮更新：海外首发与关于页（优先于下方先前记录）

- 用户授权先不在中国大陆上架，并确认先排除缺少 DSA 资料的欧盟 27 国。Apple API 回读及 Edge 页面均验证 147 地区可用 / 28 地区未供应；选定地区不再包含 TRADER_STATUS_NOT_PROVIDED。仍是手动发布，未实际销售。
- 关于页版本号改为检查更新上方的独立同布局列表行；删除原版本页脚的所有说明。源码构建号 8。`./build.sh simulator` 所含四组测试与模拟器编译通过；安装后直接打开 about 入口，截图核验通过，证据 `release/evidence/about-version-row.png`。
- 新增 `./build.sh xcode-install <完整xip绝对路径>`，静态 shell 语法检查与不完整下载拒绝自检通过；尚无完整下载，未执行实际安装。
- 当前商店资料验证唯一阻断为缺少有效关联构建；旧 IPA 只用于核验设备类型，不是本次待上传成品。Xcode 27.1 下载尚未完成，自动化 `xcode-27-1-pluglit` 每小时检查并接续本轮已授权安装、重建、上传和提审。
- 没有本轮真机安装或审核回执，不能声称已经提交审核或上架。原有 PiP 系统行为及审核风险仍然适用。

## 已完成

- 0.4.0 (7)：本机 Release 归档、签名校验和 App Store IPA 导出成功。产物：`~/Library/Caches/ChargeUnlock/Release/PlugLit.ipa`。
- 真机 iPhone：通过 `./build.sh ios-install` 覆盖安装并成功启动；devicectl 读取到 version 0.4.0 / bundleVersion 7，未卸载应用或安装 UI 测试执行器。
- `./build.sh test`：充电策略、电量覆盖、App 信息和诊断保留/清理测试通过。
- `./build.sh website-deploy`：网站生成、链接校验、4 项 Worker 测试通过，部署命令退出 0。Worker 最新版本 `638a9307-39f8-4c44-a7ef-02452cf4e92c`。
- 官网 https://auv.macseek.cc：首页、反馈、隐私、条款、更新、指南及健康接口全部 HTTP 200。Edge 桌面和 390×844 手机视口检查通过，已恢复原浏览器视口。
- `./build.sh feedback-network-check`：Swift URLSession HTTPS 提交、同请求重复提交、删除测试通过；合成记录已删除。此前浏览器表单测试也收到回执并删除。
- App Store Connect App `6828947154` / 版本 `c4a77f54-19cc-4e67-8e81-e3e1b4c20904`：中文元数据、工具分类、年龄分级、内容权利、免费价格、审核联系人和说明已保存。中国大陆销售范围，手动发布。
- 商店截图：指南 `7f800019-7097-86d2-8020-7883a26b09b0` 与新版反馈 `c4800019-7097-86d2-8007-02095c4f2bc0` 均 COMPLETE，1284×2778。移除了长时间未处理完成的旧关于页及旧反馈图。
- App 隐私：用户明确确认后点击发布，页面显示“几秒钟前由旺旺 杨发布”。邮箱、客户支持、其他诊断数据：App 功能用途、关联用户、不用于追踪。
- API key、Distribution 证书及私钥、profile 已配置，私钥在仓库外；没有把私钥上传官网或 VPS。
- 用户确认已取得 Apple 账户持有人授权，计划以吴凯申请的个体工商户主体办理 App 备案。

## 仍然阻塞审核

1. Apple 处理构建 6 返回 90534 Unsupported SDK or Xcode version，上传记录 `b0a9bf1e-5bb9-4c13-8662-baefac0b588a`。当前 Xcode 27.2 (27B52) / SDK iphoneos27.2 (24B8118) 已在 Apple 官网列为正式版，但上传服务拒绝。最新本地构建 7 未重复上传相同工具链。
2. 需要安装 Apple 官方 Xcode 27.1 (27A9275)，通过 DEVELOPER_DIR 指向独立副本重建；本机 Edge 下载被 ERR_BLOCKED_BY_CLIENT 拦截，已请用户处理。
3. 真实 App 备案号缺失；个体工商户工商登记名称/备案主体资料待提供。不伪造备案，也没有改为海外发布绕过用户的国内发布目标。

最终 `asc validate --ipa ...` 唯一阻断项：没有已处理成功并关联的构建。whatsNew 的提示是首发警告：Apple 实际拒绝首发编辑该字段。隐私发布状态经浏览器核验，公共 API 本身无法核验。

## 尚未验证与风险

- 未在最新版本上重新完成整套真机插拔电/跨 App/PiP/熄屏回归，未交互验证手机内反馈表单；真机仅核验安装、启动和版本。网络验证使用原生 URLSession 合成测试。
- 无 App Review 提交回执，版本仍是 PREPARE_FOR_SUBMISSION，不能称为已提交审核或已上架。
- PiP 充电动画防锁屏仍存在 2.5.4 / 4.2 审核风险；效果随系统状态而变，无法自动把 PiP 收到屏幕边缘。
- Cloudflare 全球托管不等于大陆备案或境内存储；未在多家中国大陆运营商网络验收。跨境数据处理仍需按实际主体完成合规核验。
- 已保存网页和隐私发布截图于 `release/evidence/`；使用说明和密钥管理详见 `release/README.md`。
