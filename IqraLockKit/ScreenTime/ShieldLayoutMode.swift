import Foundation

/// How ayah text is shown on the OS Screen Time shield.
public enum ShieldLayoutMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case arabicAndTranslation
    case arabicOnly
    case translationOnly
    case none

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .arabicAndTranslation: return "Arabic & translation"
        case .arabicOnly: return "Arabic only"
        case .translationOnly: return "Translation only"
        case .none: return "No ayah text"
        }
    }

    public var detail: String {
        switch self {
        case .arabicAndTranslation:
            return "Arabic in the main line with the meaning underneath."
        case .arabicOnly:
            return "Arabic only, with the surah reference below."
        case .translationOnly:
            return "English translation in the larger line for easier reading."
        case .none:
            return "Progress and a button to open IqraLock and read there."
        }
    }
}
