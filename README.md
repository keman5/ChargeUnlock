# ChargeUnlock

Mac 菜单栏开发工具：指定 iPhone 通过 USB 连接时，用独立的 XCTest 助手保持屏幕唤醒；可以切换到其他 App。拔线、暂停或退出后停止保活，沿用手机原有自动锁定时间，不修改系统设置，也不绕过密码锁屏。

## iPhone 独立版（画中画）

另提供原生 iOS App，支持 iOS 17 及以上，使用系统画中画循环播放本地无声视频。日常使用只需 ChargeUnlock 和 iOS“快捷指令”的充电器自动化，不依赖 ChargeUnlockRunner，也无需 Mac 持续连接。手机上原有的 ChargeUnlockRunner-Runner 可以卸载；使用此模式时请退出 Mac 保活工具。是否阻止自动锁屏取决于系统的实际播放行为，不能等同于修改全局锁屏设置。

```sh
./build.sh ios-install DEVICE_UDID TEAM_ID
```

此命令运行自检、生成并校验 6 秒低码率本地视频、对指定真机构建签名、安装并启动。仅构建用 `ios` 模式；签名团队存于忽略的 `iOS/Signing.local.xcconfig`，构建缓存位于 `~/Library/Caches/ChargeUnlock/iOS/`。

画中画启动成功后自动返回桌面，手动开启和快捷指令启动均生效；启动失败时留在 App 内。此行为使用 iOS 私有退后台接口，仅用于本机开发安装，不适用于 App Store 上架；系统不支持该接口时需手动上滑返回桌面。重新打开 App 不会再次自动退出。

开发者可选的 `./build.sh ios-test DEVICE_UDID TEAM_ID` 会临时安装并运行 ChargeUnlockRunner，连续检查两次画中画启动、自动返回桌面、重新进入及停止流程；手机需解锁并连接电源。它不属于 iOS 日常使用流程，完成后可卸载测试助手。

在手机“快捷指令 → 自动化”创建两条个人自动化：

1. **充电器 → 已连接 → 立即运行**，添加 ChargeUnlock 的“开始充电保活”。
2. **充电器 → 已断开 → 立即运行**，添加 ChargeUnlock 的“停止充电保活”。

iOS 27 的快捷指令编辑器中，可新建快捷指令，添加“自动化 → 充电器”触发器，分别选择“连接”和“断开连接”，再添加上述动作；展开触发器确认“自动化”已启用。

开始动作会打开 App 并尝试启动画中画，锁屏时可能需要先解锁；停止动作不需要打开界面。App 同时监控电池状态，断电即停止播放。用户关闭画中画或媒体中断也会停止，不擅自重新开启。它不修改自动锁定时间，不自动解锁手机。

画中画尺寸由 iOS 决定，可双指缩小；没有公开接口把它强制变成任意小的悬浮点。隐藏到屏幕边缘、锁屏启动、其他视频抢占及长时间运行需要分别验证。测试防锁屏时必须停止 Mac 保活程序和 UI 测试助手，以免它们影响结果。

参考：[AVPlayer 防显示器休眠](https://developer.apple.com/documentation/avfoundation/avplayer/preventsdisplaysleepduringvideoplayback)、[充电器自动化](https://support.apple.com/en-gb/guide/shortcuts/apde31e9638b/ios)。

## Mac 版使用

1. Mac 安装完整 Xcode，并登录自己的 Apple 开发者账户。
2. iPhone 使用 iOS 17 或更新系统；通过数据线连接，解锁、信任 Mac，开启开发者模式及“设置 → 开发者 → 启用 UI 自动化”。
3. 运行 `./build.sh install`。菜单栏出现手机图标。
4. 菜单“签名团队…”填 Xcode 中的 10 位 Team ID。只有一台 USB iPhone 时首次自动绑定；多台时手动选择。绑定后不会自动改选其他手机。
5. 首次运行会在本地构建并安装 ChargeUnlockRunner 测试助手。若手机显示自动化授权提示，请亲自确认。菜单显示“正在保持 iPhone 亮屏”才表示收到成功的按键回执。
6. 需要运行自己的 Xcode UI 测试时先点“暂停保活”；完成后再启用。失败不会不停重试授权，处理提示后点“重新连接助手”。

Mac 需要支持 `devicectl device notification post` 的 Xcode（本机 Xcode 验证）；只接普通充电器不生效。启动后可以从桌面切到其他 App，不需要停留在助手界面。首次配置/签名与系统版本兼容仍须在目标手机验证。

## 断连与安全边界

Mac 直接读取 USB 硬件列表，不把 Wi-Fi 开发连接当成插线。每 3 秒给选中设备发送一次当前会话专用的 Darwin 通知。手机只在收到最近 8 秒的许可、充电/充满、且确认未锁屏时每 10 秒发送一次 F13；没有许可 30 秒后结束测试助手。Mac 的 USB 检查间隔 1 秒。

停止保活后是重新按系统的空闲倒计时锁屏，不是立即强制锁屏。最后一个已经发送的事件可能延后一次倒计时。手机已锁屏时不发送事件，不自动解锁。即使 Mac 异常退出、睡眠或拔线后仍有 Wi-Fi 连接，许可过期也会停止新事件。

这是开发用途的 XCTest 方案，使用私有设备事件和锁屏状态接口，不能作为普通 App Store iOS App 发布；系统升级可能使接口失效。F13 没有常规 iOS 操作，但监听 F13 的 App 可能收到该按键。XCTest 自动化可能影响并行 UI 测试、输入时序和电量测试；并行调试兼容性需实测。

## 构建与数据

- `./build.sh test`：许可状态及 USB 目标保护自检。
- `./build.sh mac`：构建 `dist/ChargeUnlock.app`。
- `./build.sh install`：正常退出旧版，安装到 `/Applications/ChargeUnlock.app` 并启动；保留偏好与用户数据。
- `./build.sh runner DEVICE_UDID TEAM_ID`：本地构建并签名手机测试助手。
- `./build.sh run DEVICE_UDID TEAM_ID SESSION_UUID`：构建并运行助手（由菜单栏应用调用）。

配置保存于 `local.chargeunlock.mac` 的 UserDefaults；设备 ID 和 Team ID 不写入源码。最近运行日志和状态位于 `~/Library/Application Support/ChargeUnlock/`；签名构建缓存位于 `~/Library/Caches/ChargeUnlock/Runner/`，可在退出应用后删除以强制重新构建。脚本清理项目 `.artifacts` 和 Go 构建缓存，产物放在 `dist`。不创建开机启动项，不修改现有 PUA/WDA 配置。

参考：[Apple idle timer](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)、[iphone-use 的 F13 保活研究](https://github.com/leeguooooo/iphone-use/blob/main/runner/IPhoneUseRunner/IPhoneUseRunnerUITests/IPURBridge.m)。
