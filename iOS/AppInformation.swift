import Foundation

enum AppInformation {
    static let website = URL(string: "https://auv.macseek.cc")!

    static func updateURL(in info: [String: Any]) -> URL {
        if let id = info["PlugLitAppStoreID"] as? String,
           !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return URL(string: "https://apps.apple.com/app/id\(id)")!
        }
        return website.appendingPathComponent("updates/")
    }
    static func version(in info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "未知"
        let build = info["CFBundleVersion"] as? String ?? "未知"
        return "\(version)（\(build)）"
    }

    static func url(for key: String, in info: [String: Any]) -> URL? {
        guard let text = info[key] as? String,
              let url = URL(string: text), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static let privacy = """
    电亮 PlugLit 隐私政策 · 更新日期：2026-10-30

    运营者与联系方式
    本应用由吴凯开发并运营。隐私与支持邮箱：feedback.pluglit@macseek.cc。官网：https://auv.macseek.cc。

    我们使用哪些信息
    电亮读取设备的充电状态和系统电量，用于判断是否开启亮屏、更新充电画面和在拔电后停止播放。这些处理在设备本地完成。

    本地保存的内容
    应用保存是否已展示使用指南的偏好，并在本机记录最多 200 条、最近 7 天内的运行事件（时间、电量、充电状态、播放状态）。读取或写入时排除过期事件；打开应用时清理旧记录。可以在“问题反馈”中预览、导出或清空。诊断目录不参与系统备份，卸载应用会删除本地记录。应用也写入系统日志，由你的 iOS 设置管理。

    自愿反馈与诊断
    只有你填写反馈、同意发送并点击“提交反馈”后，才会将问题描述和选填的邮箱发送到 https://auv.macseek.cc。诊断附件默认关闭；开启后还会发送你可以预览的机型标识（如 iPhone18,3）、系统与应用版本、省电和温度状态、电量及运行事件。不读取设备名称、序列号、UDID、广告标识或其他 App 内容。不附带日志也能反馈，不上传不影响亮屏功能。

    网站、存储与删除
    官网使用 Cloudflare 提供网络与存储服务，服务器可能位于境外。传输使用 HTTPS；网络服务商会处理连接 IP，反馈数据库不保存原始 IP。反馈仅用于排查和回复，在线记录保留 30 天，到期后在下一次每小时清理任务中删除；托管服务可能保留有限的灾备数据。提交成功后请保存反馈编号，可在官网反馈页申请即时删除在线记录，请勿公开该编号。Cloudflare 的服务隐私说明见 https://www.cloudflare.com/privacypolicy/。请勿在反馈中包含密码、支付信息或无关个人资料。

    数据收集与权限
    当前版本不包含账号系统、广告或第三方统计 SDK，不读取通讯录、照片、麦克风或位置。充电动画为应用内置资源，无需联网播放。反馈描述、选填邮箱与诊断信息只在你主动提交时收集，不用于广告、追踪或数据交易。

    快捷指令与外部网站
    个人自动化由你在系统快捷指令中创建和管理，电亮无法读取或删除这些规则。点击官网、更多应用或版本页面时，将打开外部服务，其网络访问适用对应服务的隐私政策。

    删除与变更
    删除应用会移除其本地应用数据，但不会自动删除已经提交的反馈；可使用反馈编号在官网删除。系统日志、系统备份和个人自动化由 iOS 分别管理。请在卸载前手动停用或删除关联自动化。隐私咨询和权利请求可通过官网反馈页提交。未来如增加数据处理功能，将同步更新本说明。
    """

    static let terms = """
    使用电亮 PlugLit 前，请了解以下说明。

    功能范围
    电亮通过系统画中画播放充电动画，在支持的情况下保持屏幕亮着。它不会修改系统自动锁定时长，也不会绕过设备密码或解锁限制。停止播放后，由系统按原有设置决定何时锁屏。

    系统限制
    播放效果受 iOS 版本、电源状态、其他媒体和系统资源影响。锁屏插电可能需要先解锁；收起、暂停或关闭画中画可能结束亮屏。应用不保证在所有设备和场景中持续亮屏。

    合理使用
    持续亮屏与播放会增加耗电和发热，请根据设备温度和使用环境合理安排时长。不再需要时请停止播放，不要依赖本应用完成必须持续显示的关键任务。

    自动化与停用
    插拔电源自动运行需要你自行配置快捷指令规则。停止本次播放不会停用后续自动化；卸载前请先停止播放，再删除相关规则。

    更新与外部服务
    iOS 正式版本通过 Apple App Store 更新，测试版本通过 Apple TestFlight 分发；尚未发布时官网会如实说明。应用不会下载或安装可执行代码，也不使用 Sparkle。外部网站和其他应用由各自提供方运营。适用法律赋予你的权利不受本说明影响。
    """
}
