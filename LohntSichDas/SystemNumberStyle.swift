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
    var minFractionDigits: Int
    var maxFractionDigits: Int
    var usesGrouping: Bool

    /// Fixed-precision style for read-only display (always shows `fractionDigits`
    /// decimals, e.g. "12.50").
    init(fractionDigits: Int) {
        self.minFractionDigits = fractionDigits
        self.maxFractionDigits = fractionDigits
        self.usesGrouping = true
    }

    /// Flexible style, typically for text entry: shows up to `maxFractionDigits`
    /// decimals but never forces trailing zeros, so arbitrary decimals entered by
    /// the user are preserved and shown rather than rounded.
    init(minFractionDigits: Int = 0, maxFractionDigits: Int, usesGrouping: Bool = true) {
        self.minFractionDigits = minFractionDigits
        self.maxFractionDigits = maxFractionDigits
        self.usesGrouping = usesGrouping
    }

    func format(_ value: Double) -> String {
        Self.formatter(min: minFractionDigits, max: maxFractionDigits, grouping: usesGrouping)
            .string(from: value as NSNumber) ?? ""
    }

    var parseStrategy: SystemNumberParseStrategy {
        SystemNumberParseStrategy(usesGrouping: usesGrouping)
    }

    /// Builds a decimal `NumberFormatter` bound to the live system locale.
    static func formatter(min: Int, max: Int, grouping: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = min
        formatter.maximumFractionDigits = max
        formatter.usesGroupingSeparator = grouping
        return formatter
    }
}

struct SystemNumberParseStrategy: ParseStrategy {
    var usesGrouping: Bool = true

    func parse(_ value: String) throws -> Double {
        // An empty field is treated as zero so the value can be cleared while editing.
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = usesGrouping
        formatter.maximumFractionDigits = 20 // parse without discarding typed precision
        if let number = formatter.number(from: value) {
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
