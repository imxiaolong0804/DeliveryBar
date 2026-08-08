//
//  MemoEditorTextView.swift
//  DeliveryBar
//
//  备忘正文编辑器。用 NSTextView 而不是 SwiftUI TextEditor，图的是三件事：
//  能拦住图片粘贴/拖拽、能在光标位置插入、能拿到系统撤销栈。
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// 让外部（工具栏按钮、模板芯片、快捷键）能操作编辑器的句柄
final class MemoEditorController: ObservableObject {
    fileprivate weak var textView: NSTextView?

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    /// 在光标处插入，并把光标移到插入内容之后
    func insertAtCursor(_ text: String) {
        guard let textView, textView.isEditable else { return }
        textView.insertText(text, replacementRange: textView.selectedRange())
        textView.scrollRangeToVisible(textView.selectedRange())
        focus()
    }

    /// 整体换掉正文（套模板用）。走编辑器而不是直接改绑定，
    /// 因为同一条备忘打开期间编辑器才是内容的权威。
    func replaceAll(with text: String) {
        guard let textView, textView.isEditable else { return }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard textView.shouldChangeText(in: fullRange, replacementString: text) else { return }

        textView.textStorage?.replaceCharacters(in: fullRange, with: text)
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        focus()
    }
}

struct MemoEditorTextView: NSViewRepresentable {
    @Binding var text: String
    /// 当前编辑的是哪一条备忘。只有它变了才整体换内容——见 updateNSView 里的说明。
    let documentID: UUID
    let controller: MemoEditorController
    /// 返回要插入正文的 Markdown 片段；返回 nil 表示这次不当图片处理，走默认粘贴
    let onInsertImage: (NSImage) -> String?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = MemoTextView(frame: .zero)
        textView.delegate = context.coordinator
        // 正文用系统字体。等宽只留给代码块和行内 `code`，由 MarkdownSyntaxHighlighter 按语法分配——
        // 整篇等宽的话中文会 fallback 到另一套字体，字距和西文对不齐，一屏中文又密又糙。
        textView.font = MarkdownTextTheme.bodyFont
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        // Markdown 源码里的引号和减号被自动替换成中文标点会直接毁掉语法
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        // 水平留白由 MemoTextView.layout() 按窗口宽度动态给，这里只定初值
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.imageInsertHandler = onInsertImage

        scrollView.documentView = textView
        controller.textView = textView
        context.coordinator.loadedDocumentID = documentID
        context.coordinator.highlighter.attach(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MemoTextView else { return }
        controller.textView = textView
        textView.imageInsertHandler = onInsertImage
        context.coordinator.highlighter.attach(textView)

        // 同一条备忘打开期间，编辑器是正文的唯一权威，SwiftUI 一律不回写。
        //
        // 回写过会出事：自动保存改了 updatedAt，@Query 重排触发重渲染，
        // 这时 updateNSView 拿到的还是上一拍的 text，一句 textView.string = text
        // 就会把输入法里没上屏的拼音连同刚敲的字符一起抹掉。
        guard context.coordinator.loadedDocumentID != documentID else { return }

        // 输入法组合还没结束就换文档会把候选词吞掉，等这一轮敲完再说
        guard !textView.hasMarkedText() else { return }

        context.coordinator.loadedDocumentID = documentID
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        // 撤销栈不能跨备忘，否则 ⌘Z 会把上一条的内容倒回来
        textView.undoManager?.removeAllActions()
        // 换文档不走 textDidChange，这里补一次着色
        context.coordinator.highlighter.highlightNow()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let highlighter = MarkdownSyntaxHighlighter()
        var loadedDocumentID: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            highlighter.schedule()
        }
    }
}

// MARK: - NSTextView subclass

private final class MemoTextView: NSTextView {
    private enum Layout {
        static let maxContentWidth: CGFloat = 720
        static let minimumHorizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 20
    }

    var imageInsertHandler: ((NSImage) -> String?)?

    /// 窗口拉宽后行长不跟着无限变长——超过阅读宽度就靠加大左右留白把正文框住居中。
    /// 一行一百多个字看着累，这是备忘和 JSON 编辑区最大的排版差别。
    override func layout() {
        super.layout()

        let target = min(Layout.maxContentWidth, bounds.width - Layout.minimumHorizontalInset * 2)
        let inset = max(Layout.minimumHorizontalInset, (bounds.width - target) / 2)

        if abs(textContainerInset.width - inset) > 0.5 {
            textContainerInset = NSSize(width: inset, height: Layout.verticalInset)
        }
    }

    /// 富文本关掉后系统不再接受图片拖拽，这里手动把图片类型加回来
    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        super.acceptableDragTypes + [.png, .tiff, .fileURL]
    }

    /// ⌘V 粘贴和拖拽落地都会走到这里，一处拦截覆盖两种入口
    override func readSelection(from pboard: NSPasteboard) -> Bool {
        if
            let imageInsertHandler,
            let image = MemoPasteboard.image(from: pboard),
            let markdown = imageInsertHandler(image)
        {
            insertText(markdown, replacementRange: selectedRange())
            return true
        }

        return super.readSelection(from: pboard)
    }
}

// MARK: - Pasteboard

enum MemoPasteboard {
    /// 剪贴板里同时有文字时一律按文字处理：从网页复制图片往往还带着一个 URL，
    /// 那种情况下用户多半是想要链接。需要强制插图有工具栏按钮兜底。
    static func image(from pasteboard: NSPasteboard, allowsTextFallback: Bool = true) -> NSImage? {
        if allowsTextFallback, pasteboard.availableType(from: [.string]) != nil {
            return nil
        }
        return rawImage(from: pasteboard)
    }

    /// 工具栏「插入截图」用：只要剪贴板里有图就取，不管有没有附带文字
    static func forcedImage(from pasteboard: NSPasteboard) -> NSImage? {
        rawImage(from: pasteboard)
    }

    private static func rawImage(from pasteboard: NSPasteboard) -> NSImage? {
        let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]
        if
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL],
            let url = urls.first,
            let image = NSImage(contentsOf: url)
        {
            return image
        }

        guard pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) else { return nil }
        return pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }
}
