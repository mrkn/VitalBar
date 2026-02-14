import SwiftUI

enum UsageLevel: Equatable {
    case unknown
    case idle
    case moderate
    case high
    case stale
}

struct UsageStyle {
    static func level(for usage: Double?, isStale: Bool) -> UsageLevel {
        if isStale {
            return .stale
        }

        guard let usage else {
            return .unknown
        }

        switch usage {
        case ..<0.50:
            return .idle
        case ..<0.80:
            return .moderate
        default:
            return .high
        }
    }

    static func color(for level: UsageLevel) -> Color {
        switch level {
        case .unknown:
            return .secondary
        case .idle:
            return .green
        case .moderate:
            return .yellow
        case .high:
            return .red
        case .stale:
            return .orange
        }
    }
}
