import Foundation

enum AppInformation {
    static func version(in info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "未知"
        let build = info["CFBundleVersion"] as? String ?? "未知"
        return "\(version)（\(build)）"
    }

    // shortcut: release links are optional until publishing destinations are supplied.
    static func url(for key: String, in info: [String: Any]) -> URL? {
        guard let text = info[key] as? String,
              let url = URL(string: text), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static let privacy = """
    本说明适用于当前版本的电亮 PlugLit。

    我们使用哪些信息
    电亮读取设备的充电状态和系统电量，用于判断是否开启亮屏、更新充电画面和在拔电后停止播放。这些处理在设备本地完成。

    本地保存的内容
    应用保存是否已展示使用指南的偏好，以及最近一次运行状态（电量、充电状态、播放状态和时间），供本地故障排查使用。应用也会写入系统诊断日志。电亮不会主动将这些信息上传到服务器；系统诊断数据由你的 iOS 设置管理。

    数据收集与权限
    当前版本不包含账号系统、广告或第三方统计 SDK，不读取通讯录、照片、麦克风或位置。充电动画为应用内置资源，无需联网播放。

    快捷指令与外部网站
    个人自动化由你在系统快捷指令中创建和管理，电亮无法读取或删除这些规则。点击官网、更多应用或版本页面时，将打开外部服务，其网络访问适用对应服务的隐私政策。

    删除与变更
    删除应用会移除其本地应用数据；系统日志、系统备份和个人自动化由 iOS 分别管理。请在卸载前手动停用或删除关联自动化。未来如增加数据处理功能，将同步更新本说明。
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
    请仅从你信任的发布渠道获取更新。外部网站和其他应用由各自提供方运营。适用法律赋予你的权利不受本说明影响。
    """
}
