import AppKit
import SwiftUI

@MainActor
final class SleepLockPopoverViewModel: ObservableObject {
    struct DurationOption: Identifiable {
        let title: String
        let selection: SleepController.ActiveSelection
        let action: () -> Void

        var id: SleepController.ActiveSelection { selection }
    }

    @Published private(set) var mode: SleepController.SleepMode = .off
    @Published private(set) var activeSelection: SleepController.ActiveSelection = .none
    @Published private(set) var isLaunchAtLoginEnabled = false

    func update(
        mode: SleepController.SleepMode,
        activeSelection: SleepController.ActiveSelection,
        isLaunchAtLoginEnabled: Bool
    ) {
        self.mode = mode
        self.activeSelection = activeSelection
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
    }
}

struct SleepLockPopoverView: View {
    @ObservedObject var viewModel: SleepLockPopoverViewModel

    let onKeepAwake1Hour: () -> Void
    let onKeepAwake3Hours: () -> Void
    let onKeepAwake5Hours: () -> Void
    let onKeepAwakeUntilTurnedOff: () -> Void
    let onAllowSleep30Minutes: () -> Void
    let onAllowSleep1Hour: () -> Void
    let onAllowSleep2Hours: () -> Void
    let onDisable: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onAbout: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            section {
                groupLabel("Keep awake")
                optionList(keepAwakeOptions)
            }

            section {
                groupLabel("Allow sleep in")
                optionList(allowSleepOptions)
            }

            section {
                menuRow(title: "Disable SleepLock", action: onDisable)
            }

            section(hasDivider: false) {
                checkedMenuRow(
                    title: "Launch at login",
                    isChecked: viewModel.isLaunchAtLoginEnabled,
                    action: onToggleLaunchAtLogin
                )
                menuRow(title: "About SleepLock", action: onAbout)
                menuRow(title: "Quit SleepLock", action: onQuit)
            }
        }
        .frame(width: 220)
        .background(menuBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 4)
        .compositingGroup()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SleepLock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.top, 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            divider
        }
    }

    private var keepAwakeOptions: [SleepLockPopoverViewModel.DurationOption] {
        [
            .init(title: "1 hour", selection: .keepAwake1h, action: onKeepAwake1Hour),
            .init(title: "3 hours", selection: .keepAwake3h, action: onKeepAwake3Hours),
            .init(title: "5 hours", selection: .keepAwake5h, action: onKeepAwake5Hours),
            .init(title: "Until turned off", selection: .keepAwakeInfinite, action: onKeepAwakeUntilTurnedOff)
        ]
    }

    private var allowSleepOptions: [SleepLockPopoverViewModel.DurationOption] {
        [
            .init(title: "30 min", selection: .allowSleep30m, action: onAllowSleep30Minutes),
            .init(title: "1 hour", selection: .allowSleep1h, action: onAllowSleep1Hour),
            .init(title: "2 hours", selection: .allowSleep2h, action: onAllowSleep2Hours)
        ]
    }

    private var menuBackground: some View {
        Color(red: 232.0 / 255.0, green: 232.0 / 255.0, blue: 232.0 / 255.0)
    }

    private var textColor: Color {
        Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0)
    }

    private var dividerColor: Color {
        Color.black.opacity(0.12)
    }

    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 0.5)
    }

    private func section<Content: View>(
        hasDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if hasDivider {
                divider
            }
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
    }

    private func optionList(_ options: [SleepLockPopoverViewModel.DurationOption]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options) { option in
                menuRow(title: option.title, leadingInset: 28, action: option.action)
            }
        }
    }

    private func menuRow(
        title: String,
        leadingInset: CGFloat = 28,
        action: @escaping () -> Void
    ) -> some View {
        HoverMenuButton(action: action) { isHovered in
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isHovered ? Color.white : textColor)
                    .padding(.leading, leadingInset)
                    .padding(.trailing, 14)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 21, maxHeight: 21, alignment: .leading)
            .background(isHovered ? hoverColor : .clear)
        }
    }

    private func checkedMenuRow(
        title: String,
        isChecked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HoverMenuButton(action: action) { isHovered in
            HStack(spacing: 6) {
                Text(isChecked ? "✓" : "")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isHovered ? Color.white : textColor)
                    .frame(width: 14, alignment: .leading)

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isHovered ? Color.white : textColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
            .background(isHovered ? hoverColor : .clear)
        }
    }

    private var hoverColor: Color {
        Color(red: 52.0 / 255.0, green: 120.0 / 255.0, blue: 246.0 / 255.0)
    }
}

private struct HoverMenuButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: (Bool) -> Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label(isHovered)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
