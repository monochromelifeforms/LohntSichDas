//
//  AppLanguage.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// Supported display languages. `.system` follows the device language,
/// falling back to English when no matching localization exists.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case german, english, korean, spanish, italian, dutch, french, romanian, portuguese

    var id: String { rawValue }

    /// The concrete language to use for string lookup —
    /// resolves `.system` to the best matching language.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        let preferred = Locale.current.language.languageCode?.identifier ?? "en"
        switch preferred {
        case "de": return .german
        case "ko": return .korean
        case "es": return .spanish
        case "it": return .italian
        case "nl": return .dutch
        case "fr": return .french
        case "ro": return .romanian
        case "pt": return .portuguese
        default:   return .english
        }
    }

    /// Native name shown in the language picker.
    var displayName: String {
        switch self {
        case .system:     return "System"
        case .german:     return "Deutsch"
        case .english:    return "English"
        case .korean:     return "한국어"
        case .spanish:    return "Español"
        case .italian:    return "Italiano"
        case .dutch:      return "Nederlands"
        case .french:     return "Français"
        case .romanian:   return "Română"
        case .portuguese: return "Português"
        }
    }
}
