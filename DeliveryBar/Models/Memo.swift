//
//  Memo.swift
//  DeliveryBar
//
//  备忘：长文本沉淀。和快捷录（点一下就复制/打开的动作型条目）刻意分开，
//  也和待办/日志（7 天滚动窗口清理）刻意分开——备忘只在用户主动删除时才消失。
//

import Foundation
import SwiftData

enum MemoKind: String, Codable, CaseIterable, Identifiable {
    case problem
    case process
    case knowledge
    case blank

    var id: String { rawValue }

    /// 新建菜单里的顺序，空白排最后
    static let creatable: [MemoKind] = [.problem, .process, .knowledge, .blank]

    var title: String {
        switch self {
        case .problem:
            "问题"
        case .process:
            "流程"
        case .knowledge:
            "知识"
        case .blank:
            "空白"
        }
    }

    var systemImage: String {
        switch self {
        case .problem:
            "ladybug"
        case .process:
            "list.number"
        case .knowledge:
            "lightbulb"
        case .blank:
            "doc.text"
        }
    }

    /// 新建时预填的骨架，纯粹是省敲字，可以随便删改，不是必填字段。
    /// 列表项后面的空格是故意留的，光标落上去就能直接接着写。
    var template: String {
        switch self {
        case .problem:
            """
            ## 现象

            ## 排查过程

            ## 根因

            ## 解决方案

            ## 结论 / 下次怎么避免

            """
        case .process:
            """
            ## 适用场景

            ## 步骤
            1.
            2.
            3.

            ## 注意事项

            """
        case .knowledge:
            """
            ## 要点

            ## 细节

            ## 参考

            """
        case .blank:
            ""
        }
    }
}

@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Markdown 源码。编辑态所见即此内容，预览态渲染后展示。
    var content: String
    var kindRaw: String
    var tag: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    /// 软删除时间。非空表示在「最近删除」里，超过保留期由 MaintenanceService 物理删除。
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \MemoAttachment.memo)
    var attachments: [MemoAttachment]

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        kind: MemoKind = .blank,
        tag: String = "",
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        attachments: [MemoAttachment] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.kindRaw = kind.rawValue
        self.tag = tag
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.attachments = attachments
    }

    var kind: MemoKind {
        get { MemoKind(rawValue: kindRaw) ?? .blank }
        set { kindRaw = newValue.rawValue }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return firstContentLine ?? "未命名备忘"
    }

    /// 列表副标题：跳过标题行和空行，取第一句正文
    var preview: String {
        let line = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return false }
                return !trimmed.hasPrefix("#") && trimmed != "---"
            }
        guard let line else { return "空备忘" }
        return String(line).trimmingCharacters(in: .whitespaces)
    }

    private var firstContentLine: String? {
        let line = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let line else { return nil }
        // 骨架标题（## 现象）也能当临时标题用，去掉井号更好看
        let trimmed = String(line).trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? nil : stripped
    }

    /// 列表搜索：query 需为已 lowercased 的非空串。正文必须参与匹配——
    /// 记录问题的全部价值就在于下次能搜到。
    func matches(_ query: String) -> Bool {
        [title, content, tag, kind.title].contains { $0.lowercased().contains(query) }
    }

    /// 导出与「复制全文」共用：标题为空时不硬塞一行井号
    var markdownDocument: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return content }
        return "# \(trimmedTitle)\n\n\(content)"
    }

    func attachment(for id: UUID) -> MemoAttachment? {
        attachments.first { $0.id == id }
    }

    /// 正文里删掉图片那一行后，附件本体还留在库里。每次落盘顺手清掉不再被引用的，
    /// 否则截图会一直占着磁盘。
    func pruneUnusedAttachments(in context: ModelContext) {
        guard !attachments.isEmpty else { return }
        let referenced = MemoAttachmentReference.referencedIDs(in: content)
        for attachment in attachments where !referenced.contains(attachment.id) {
            context.delete(attachment)
        }
    }

    func touch() {
        updatedAt = Date()
    }

    func markDeleted() {
        deletedAt = Date()
        touch()
    }

    func restore() {
        deletedAt = nil
        touch()
    }
}

@Model
final class MemoAttachment {
    @Attribute(.unique) var id: UUID
    /// 截图动辄几百 KB，放外部文件而不是直接塞进 SQLite
    @Attribute(.externalStorage) var data: Data
    var createdAt: Date
    var memo: Memo?

    init(
        id: UUID = UUID(),
        data: Data,
        createdAt: Date = Date(),
        memo: Memo? = nil
    ) {
        self.id = id
        self.data = data
        self.createdAt = createdAt
        self.memo = memo
    }
}

/// 正文里引用附件用的自定义 scheme：`![截图](dbimg://<uuid>)`。
/// 用 Markdown 原生图片语法而不是自造标记，导出时只要重写括号里的路径就行。
enum MemoAttachmentReference {
    static let scheme = "dbimg"

    static func markdown(for id: UUID, alt: String = "截图") -> String {
        "![\(alt)](\(scheme)://\(id.uuidString))"
    }

    /// 从 `dbimg://<uuid>` 取出附件 id，不是这个 scheme 就返回 nil
    static func attachmentID(from reference: String) -> UUID? {
        let prefix = "\(scheme)://"
        guard reference.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(reference.dropFirst(prefix.count)))
    }

    static func referencedIDs(in content: String) -> Set<UUID> {
        var ids: Set<UUID> = []
        var remainder = Substring(content)
        let prefix = "\(scheme)://"

        while let start = remainder.range(of: prefix) {
            let afterPrefix = remainder[start.upperBound...]
            // UUID 后面紧跟的是 Markdown 的右括号
            let raw = afterPrefix.prefix { $0 != ")" && $0 != "\n" }
            if let id = UUID(uuidString: String(raw)) {
                ids.insert(id)
            }
            remainder = afterPrefix
        }

        return ids
    }
}
