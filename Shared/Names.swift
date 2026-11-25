import SwiftUI
import WageDripCore

/// Localized labels for core enums and built-in items.
extension Period {
    var label: LocalizedStringKey {
        switch self {
        case .today: "今日"
        case .month: "本月"
        case .year: "今年"
        }
    }

    var headlineLabel: LocalizedStringKey {
        switch self {
        case .today: "今日实收"
        case .month: "本月实收"
        case .year: "今年实收"
        }
    }
}

extension WorkStatus {
    var label: LocalizedStringKey {
        switch self {
        case .beforeWork: "未到上班时间"
        case .working: "上班中"
        case .flexEvening: "弹性时段"
        case .afterWork: "已下班"
        case .restDay: "今日休息"
        }
    }

    var signOff: LocalizedStringKey {
        switch self {
        case .beforeWork: "钱还没开始掉"
        case .working: "谢谢惠顾 明天再来"
        case .flexEvening: "这也算上班"
        case .afterWork: "今日已结清"
        case .restDay: "今天不卖命"
        }
    }
}

func localizedName(key: String?, custom: String?) -> String {
    if let custom, !custom.isEmpty { return custom }
    guard let key else { return "" }
    return String(localized: String.LocalizationValue(key))
}

extension Equivalent {
    var displayName: String { localizedName(key: nameKey, custom: customName) }
}

extension Milestone {
    var displayName: String { localizedName(key: nameKey, custom: customName) }
}

extension Region {
    var label: LocalizedStringKey {
        switch self {
        case .cn: "中国"
        case .us: "美国"
        }
    }
}

extension PayMode {
    var label: LocalizedStringKey {
        switch self {
        case .annual: "年薪"
        case .monthly: "月薪"
        case .hourly: "时薪"
        }
    }
}

extension HolidayCalendarKind {
    var label: LocalizedStringKey {
        switch self {
        case .cn: "中国法定节假日"
        case .us: "美国联邦假日"
        case .none: "不使用"
        }
    }
}

extension TaxPreset {
    var label: LocalizedStringKey {
        switch self {
        case .cnTier1: "中国一线 22%"
        case .cnOther: "中国其他 18%"
        case .usTier1: "美国一线 32%"
        case .usOther: "美国其他 25%"
        }
    }
}
