//
//  SettingsView.swift
//  DeliveryBar
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    let showsNavigation: Bool
    let onDone: () -> Void

    init(showsNavigation: Bool = true, onDone: @escaping () -> Void = {}) {
        self.showsNavigation = showsNavigation
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsNavigation {
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

                Divider()
            }

            Form {
                Section("提醒") {
                    Toggle("菜单栏与列表内超时提示", isOn: $remindersEnabled)

                    LabeledContent("开发中未推进") {
                        Text("7 天")
                            .foregroundStyle(DeliveryBarTheme.softText)
                    }

                    LabeledContent("待验收未处理") {
                        Text("5 天")
                            .foregroundStyle(DeliveryBarTheme.softText)
                    }
                }

                Section("后续版本") {
                    LabeledContent("系统本地通知") {
                        Text("V1.1")
                            .foregroundStyle(DeliveryBarTheme.softText)
                    }

                    LabeledContent("开机自启动") {
                        Text("V1.2+")
                            .foregroundStyle(DeliveryBarTheme.softText)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)

            if showsNavigation {
                Divider()

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
        }
        .frame(width: 400, height: 360)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
    }
}
