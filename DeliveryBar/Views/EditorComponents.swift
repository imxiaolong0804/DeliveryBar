//
//  EditorComponents.swift
//  DeliveryBar
//
//  需求编辑器与快捷录编辑器共用的表单组件。
//

import SwiftUI

/// 表单分组：小标题 + 卡片容器
struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .deliveryCard(padding: 10)
        }
    }
}

/// 带标题的表单输入框。Field 由各编辑器自己的焦点枚举填充。
struct EditorTextField<Field: Hashable>: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<Field?>.Binding
    let field: Field
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField(placeholder, text: $text, axis: axis)
                .focused(focusedField, equals: field)
                .modifier(OptionalLineLimit(range: lineLimit))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField.wrappedValue = field
                }
        }
    }
}

/// 输入框 + 可展开的历史建议芯片（PM / 测试人员 / 标签共用）
struct SuggestionTextField<Field: Hashable>: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    let focusedField: FocusState<Field?>.Binding
    let field: Field

    @State private var isShowingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TextField(placeholder, text: $text)
                        .focused(focusedField, equals: field)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField.wrappedValue = field
                        }

                    // 没有历史记录时不显示展开按钮，避免点开一个空列表
                    if !suggestions.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.16)) {
                                isShowingSuggestions.toggle()
                            }
                        } label: {
                            Image(systemName: isShowingSuggestions ? "chevron.up.circle" : "chevron.down.circle")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28)
                        .help("从历史记录中选择")
                    }
                }

                if isShowingSuggestions {
                    suggestionChips
                }
            }
        }
    }

    private var suggestionChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    text = suggestion
                    focusedField.wrappedValue = field
                    withAnimation(.snappy(duration: 0.16)) {
                        isShowingSuggestions = false
                    }
                }
                .font(DeliveryBarTheme.Typography.caption)
                .lineLimit(1)
                .buttonStyle(.bordered)
                .tint(DeliveryBarTheme.accent)
                .controlSize(.small)
            }
        }
    }
}

/// SwiftUI 的 lineLimit(_:) 没有 ClosedRange 的可选重载，用它承接「不限制」的情况
private struct OptionalLineLimit: ViewModifier {
    let range: ClosedRange<Int>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let range {
            content.lineLimit(range)
        } else {
            content
        }
    }
}
