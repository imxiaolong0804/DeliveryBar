//
//  SettingsView.swift
//  DeliveryBar
//

import SwiftUI

struct SettingsView: View {
    private enum Layout {
        static let embeddedWidth: CGFloat = 460
        static let standaloneWidth: CGFloat = 400
        static let embeddedHeight: CGFloat = 360
        static let standaloneHeight: CGFloat = 400
    }

    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage("mainHotKeyRegistered") private var mainHotKeyRegistered = false
    @AppStorage("jsonHotKeyRegistered") private var jsonHotKeyRegistered = false
    @AppStorage("mainHotKeyStatusText") private var mainHotKeyStatusText = "⌘⇧D 未注册"
    @AppStorage("jsonHotKeyStatusText") private var jsonHotKeyStatusText = "⌘⇧J 未注册"

    let showsNavigation: Bool
    let onDone: () -> Void

    init(showsNavigation: Bool = true, onDone: @escaping () -> Void = {}) {
        self.showsNavigation = showsNavigation
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsNavigation {
                navigationHeader
                Divider()
            }

            settingsContent
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsNavigation {
                Divider()
                footer
            }
        }
        .frame(
            width: showsNavigation ? Layout.standaloneWidth : Layout.embeddedWidth,
            height: showsNavigation ? Layout.standaloneHeight : Layout.embeddedHeight
        )
        .tint(DeliveryBarTheme.accent)
        .clipped()
    }

    private var navigationHeader: some View {
        HStack {
            Button {
                onDone()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text("设置")
                .font(.headline)
                .foregroundStyle(DeliveryBarTheme.ink)

            Spacer()
        }
        .padding(12)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingSection(title: "提醒", systemImage: "bell.badge") {
                SettingRow(title: "超时提示", detail: "菜单栏角标与列表内提醒") {
                    Toggle("", isOn: $remindersEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingDivider()

                ReminderThresholdRow()
            }

            SettingSection(title: "快捷键", systemImage: "keyboard") {
                SettingRow(title: "主面板", detail: "全局显示或隐藏 DeliveryBar") {
                    hotKeyStatus(text: mainHotKeyStatusText, isRegistered: mainHotKeyRegistered)
                }

                SettingDivider()

                SettingRow(title: "JSON 格式化", detail: "打开独立 JSON 工具窗口") {
                    hotKeyStatus(text: jsonHotKeyStatusText, isRegistered: jsonHotKeyRegistered)
                }
            }

            SettingSection(title: "后续版本", systemImage: "sparkles") {
                SettingRow(title: "系统本地通知", detail: "到期提醒与系统通知") {
                    SettingValuePill("规划中", tint: DeliveryBarTheme.muted)
                }

                SettingDivider()

                SettingRow(title: "开机自启动", detail: "随系统登录自动启动") {
                    SettingValuePill("规划中", tint: DeliveryBarTheme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button("完成") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .tint(DeliveryBarTheme.accent)
        }
        .padding(12)
    }

    private func hotKeyStatus(text: String, isRegistered: Bool) -> some View {
        SettingStatusPill(
            text: text,
            systemImage: isRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            tint: isRegistered ? DeliveryBarTheme.success : DeliveryBarTheme.danger
        )
    }
}

private struct SettingSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DeliveryBarTheme.accent)
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()
            }

            VStack(spacing: 0) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deliveryCard(
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10),
            stroke: DeliveryBarTheme.cardStroke
        )
    }
}

private struct SettingRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .frame(minHeight: 28)
        .padding(.vertical, 3)
    }
}

private struct ReminderThresholdRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("提醒阈值")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(1)

                Text("不同流程阶段的停留时间")
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                ThresholdPill(title: "开发", value: "7 天")
                ThresholdPill(title: "测试", value: "5 天")
                ThresholdPill(title: "上线", value: "5 天")
            }
        }
        .frame(minHeight: 30)
        .padding(.vertical, 3)
    }
}

private struct ThresholdPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .foregroundStyle(DeliveryBarTheme.softText)

            Text(value)
                .foregroundStyle(DeliveryBarTheme.accent)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(DeliveryBarTheme.accent.opacity(0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke(DeliveryBarTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(DeliveryBarTheme.cardStroke)
            .frame(height: 1)
    }
}

private struct SettingValuePill: View {
    let text: String
    let tint: Color

    init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct SettingStatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .frame(maxWidth: 160, alignment: .trailing)
    }
}
