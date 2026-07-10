//
//  SystemNumberStyle.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// A decimal format style backed by `NumberFormatter` so that it honors the
/// user's custom "Number Format" override in iOS Settings → Language & Region.
///
/// The modern `.number` `FormatStyle` derives its separators from the locale
/// identifier's data (e.g. `en_DE` → comma decimal) and ignores that override,
/// whereas `NumberFormatter` reads it from `Locale.autoupdatingCurrent` — the
/// same mechanism the system's own "Region Format Example" uses.
struct SystemNumberStyle: ParseableFormatStyle {
    /// Fixed number of fraction digits to display, matching the field's precision.
    var fractionDigits: Int

    func format(_ value: Double) -> String {
        Self.formatter(fractionDigits: fractionDigits).string(from: value as NSNumber) ?? ""
    }

    var parseStrategy: SystemNumberParseStrategy {
        SystemNumberParseStrategy(fractionDigits: fractionDigits)
    }

    /// Builds a decimal `NumberFormatter` bound to the live system locale.
    fileprivate static func formatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }
}

struct SystemNumberParseStrategy: ParseStrategy {
    var fractionDigits: Int

    func parse(_ value: String) throws -> Double {
        // An empty field is treated as zero so the value can be cleared while editing.
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
        if let number = SystemNumberStyle.formatter(fractionDigits: fractionDigits).number(from: value) {
            return number.doubleValue
        }
        throw CocoaError(.formatting)
    }
}

extension Double {
    /// Formats the value as a string honoring the system's "Number Format" setting.
    func systemFormatted(fractionDigits: Int) -> String {
        SystemNumberStyle(fractionDigits: fractionDigits).format(self)
    }
}
