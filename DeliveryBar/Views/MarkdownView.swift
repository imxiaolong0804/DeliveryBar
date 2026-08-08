//
//  MarkdownView.swift
//  DeliveryBar
//
//  MarkdownParser 产出的块结构的 SwiftUI 渲染。
//

import AppKit
import SwiftUI

struct MarkdownView: View {
    private enum Layout {
        static let blockSpacing: CGFloat = 10
        static let listSpacing: CGFloat = 4
        static let indentWidth: CGFloat = 16
        static let maxImageHeight: CGFloat = 420
    }

    let source: String
    /// 把 `dbimg://<uuid>` 这类引用解析成图片，解析不出来就显示占位
    var imageProvider: (String) -> NSImage? = { _ in nil }

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.blockSpacing) {
            ForEach(blocks) { block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 对齐编辑器里的 lineHeightMultiple 1.5，只读和可编辑状态下行距一致
        .lineSpacing(4)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .heading(level, text):
            Text(MarkdownInline.attributed(text))
                .font(headingFont(level: level))
                .foregroundStyle(DeliveryBarTheme.ink)
                .padding(.top, level <= 2 ? 4 : 0)

        case let .paragraph(text):
            Text(MarkdownInline.attributed(text))
                .font(.system(size: 13.5))
                .foregroundStyle(DeliveryBarTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

        case let .bulletList(items):
            VStack(alignment: .leading, spacing: Layout.listSpacing) {
                ForEach(items) { item in
                    listRow(marker: .bullet(isChecked: item.isChecked), item: item)
                }
            }

        case let .orderedList(start, items):
            VStack(alignment: .leading, spacing: Layout.listSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    listRow(marker: .number(start + index), item: item)
                }
            }

        case let .codeBlock(language, code):
            MarkdownCodeBlock(language: language, code: code)

        case let .quote(text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(DeliveryBarTheme.accent.opacity(0.55))
                    .frame(width: 3)

                Text(MarkdownInline.attributed(text))
                    .font(.system(size: 13.5))
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .divider:
            Divider()
                .padding(.vertical, 2)

        case let .image(alt, reference):
            MarkdownImageBlock(
                alt: alt,
                image: imageProvider(reference),
                maxHeight: Layout.maxImageHeight
            )
        }
    }

    private enum ListMarker {
        case bullet(isChecked: Bool?)
        case number(Int)
    }

    private func listRow(marker: ListMarker, item: MarkdownListItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            markerView(marker)
                .frame(minWidth: 16, alignment: .trailing)

            Text(MarkdownInline.attributed(item.text))
                .font(.system(size: 13.5))
                .foregroundStyle(strikesThrough(marker) ? DeliveryBarTheme.softText : DeliveryBarTheme.ink)
                .strikethrough(strikesThrough(marker), color: DeliveryBarTheme.softText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(item.indent) * Layout.indentWidth)
    }

    @ViewBuilder
    private func markerView(_ marker: ListMarker) -> some View {
        switch marker {
        case let .bullet(isChecked):
            if let isChecked {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(isChecked ? DeliveryBarTheme.accent : DeliveryBarTheme.softText)
            } else {
                Text("•")
                    .font(.system(size: 13.5))
                    .foregroundStyle(DeliveryBarTheme.softText)
            }
        case let .number(value):
            Text("\(value).")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DeliveryBarTheme.softText)
                .monospacedDigit()
        }
    }

    private func strikesThrough(_ marker: ListMarker) -> Bool {
        if case let .bullet(isChecked) = marker, isChecked == true { return true }
        return false
    }

    /// 和编辑器里的 MarkdownTextTheme.headingFont 保持同一套值。
    /// 两边不一致的话，同一条备忘在可编辑和只读状态下会是两种排版。
    private func headingFont(level: Int) -> Font {
        switch level {
        case 1:
            .system(size: 20, weight: .medium)
        case 2:
            .system(size: 16.5, weight: .medium)
        case 3:
            .system(size: 14.5, weight: .medium)
        default:
            .system(size: 13.5, weight: .medium)
        }
    }
}

// MARK: - Code Block

private struct MarkdownCodeBlock: View {
    let language: String
    let code: String

    @State private var isHovered = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty || isHovered || isCopied {
                HStack(spacing: 6) {
                    Text(language.isEmpty ? "代码" : language)
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)

                    Spacer()

                    if isHovered || isCopied {
                        Button {
                            Clipboard.copy(code)
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isCopied = false
                            }
                        } label: {
                            Label(isCopied ? "已复制" : "复制", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                .font(DeliveryBarTheme.Typography.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(isCopied ? DeliveryBarTheme.success : DeliveryBarTheme.accent)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DeliveryBarTheme.quietFill, in: RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Image Block

private struct MarkdownImageBlock: View {
    let alt: String
    let image: NSImage?
    let maxHeight: CGFloat

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                        .stroke(DeliveryBarTheme.cardStroke)
                }
                .contextMenu {
                    Button("复制图片") { copy(image) }
                    Button("在预览中打开") { openExternally(image) }
                }
                .help(alt.isEmpty ? "截图" : alt)
        } else {
            Label(alt.isEmpty ? "图片已丢失" : "\(alt)（图片已丢失）", systemImage: "photo.badge.exclamationmark")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)
                .labelStyle(.titleAndIcon)
                .deliveryCard(padding: 8)
        }
    }

    private func copy(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    /// 面板里看不清细节时，落一份临时 PNG 交给系统默认看图应用
    private func openExternally(_ image: NSImage) {
        guard let data = MemoImageCodec.pngData(from: image) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeliveryBar-\(UUID().uuidString).png")
        guard (try? data.write(to: url)) != nil else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Inline

enum MarkdownInline {
    /// 行内样式交给系统解析器：**粗体**、*斜体*、`代码`、~~删除线~~、[链接](url)
    static func attributed(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace

        guard var attributed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }

        // 行内代码系统只标记了语义，字体和底色要自己补
        let codeRanges = attributed.runs.compactMap { run in
            run.inlinePresentationIntent?.contains(.code) == true ? run.range : nil
        }
        for range in codeRanges {
            attributed[range].font = .system(size: 12.5, design: .monospaced)
            attributed[range].backgroundColor = DeliveryBarTheme.quietFill
        }

        return attributed
    }
}

// MARK: - Image Codec

enum MemoImageCodec {
    static func pngData(from image: NSImage) -> Data? {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
