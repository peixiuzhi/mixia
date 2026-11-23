import SwiftUI

// MARK: - 卡片

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

// MARK: - 头像块

struct AvatarView: View {
    let title: String
    var size: CGFloat = 36

    var body: some View {
        let pair = AvatarTint.pair(for: title)
        let text = title.trimmingCharacters(in: .whitespaces)
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(pair.background)
            .frame(width: size, height: size)
            .overlay(
                Text(String(text.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(pair.foreground)
            )
    }
}

// MARK: - 主按钮

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(15, .semibold))
            .foregroundColor(Color(hex: 0x04160F))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(14, .medium))
            .foregroundColor(Color(hex: 0xB8C4D2))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white.opacity(configuration.isPressed ? 0.09 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

// MARK: - 小图标按钮

struct IconSquareButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.sans(12, .semibold))
            .foregroundColor(Color(hex: 0x0A241C))
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color(hex: 0xE8F8F0))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }
}

// MARK: - 分类标签

struct CategoryChip: View {
    let title: String
    let selected: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(Theme.sans(12, selected ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(Theme.sans(11, .semibold))
                        .opacity(0.55)
                }
            }
            .foregroundColor(selected ? Theme.accent : Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Theme.accent.opacity(0.13) : Color.white.opacity(0.028))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Theme.accent.opacity(0.4) : Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分组标题

struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.sans(10.5, .regular))
            .tracking(1.4)
            .foregroundColor(Theme.muted2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
            .padding(.bottom, 7)
    }
}
