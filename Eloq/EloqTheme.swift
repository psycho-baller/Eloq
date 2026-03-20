import SwiftUI

enum EloqTheme {
    static let accent = Color(
        red: 121.0 / 255.0,
        green: 175.0 / 255.0,
        blue: 163.0 / 255.0
    )
    static let accentStrong = Color(
        red: 93.0 / 255.0,
        green: 143.0 / 255.0,
        blue: 132.0 / 255.0
    )
    static let accentSoft = accent.opacity(0.18)

    static let canvas = Color(
        red: 18.0 / 255.0,
        green: 22.0 / 255.0,
        blue: 26.0 / 255.0
    )
    static let surface = Color(
        red: 27.0 / 255.0,
        green: 33.0 / 255.0,
        blue: 39.0 / 255.0
    )
    static let surfaceRaised = Color(
        red: 34.0 / 255.0,
        green: 42.0 / 255.0,
        blue: 50.0 / 255.0
    )
    static let border = Color.white.opacity(0.08)

    static let textPrimary = Color(
        red: 242.0 / 255.0,
        green: 238.0 / 255.0,
        blue: 231.0 / 255.0
    )
    static let textSecondary = Color(
        red: 166.0 / 255.0,
        green: 176.0 / 255.0,
        blue: 182.0 / 255.0
    )

    static let warning = Color(
        red: 198.0 / 255.0,
        green: 150.0 / 255.0,
        blue: 98.0 / 255.0
    )
    static let danger = Color(
        red: 180.0 / 255.0,
        green: 110.0 / 255.0,
        blue: 105.0 / 255.0
    )
}

struct EloqPanelGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EloqTheme.textSecondary)

            configuration.content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(EloqTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EloqTheme.border, lineWidth: 1)
        )
    }
}

enum EloqChipTone {
    case accent
    case neutral
    case warning
    case danger

    var foregroundColor: Color {
        switch self {
        case .accent:
            return EloqTheme.accent
        case .neutral:
            return EloqTheme.textSecondary
        case .warning:
            return EloqTheme.warning
        case .danger:
            return EloqTheme.danger
        }
    }

    var backgroundColor: Color {
        switch self {
        case .accent:
            return EloqTheme.accentSoft
        case .neutral:
            return EloqTheme.surfaceRaised
        case .warning:
            return EloqTheme.warning.opacity(0.14)
        case .danger:
            return EloqTheme.danger.opacity(0.14)
        }
    }

    var borderColor: Color {
        switch self {
        case .accent:
            return EloqTheme.accent.opacity(0.22)
        case .neutral:
            return EloqTheme.border
        case .warning:
            return EloqTheme.warning.opacity(0.22)
        case .danger:
            return EloqTheme.danger.opacity(0.22)
        }
    }
}

struct EloqChip: View {
    let text: String
    let tone: EloqChipTone

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tone.foregroundColor)
            .background(tone.backgroundColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tone.borderColor, lineWidth: 1)
            )
    }
}
