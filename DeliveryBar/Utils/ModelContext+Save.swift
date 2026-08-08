//
//  ModelContext+Save.swift
//  DeliveryBar
//

import SwiftData

extension ModelContext {
    /// 统一的保存入口：没有改动就不落盘，失败只在 Debug 断言（本地优先的个人工具，不打断使用）
    func saveChanges(_ context: String = #function) {
        guard hasChanges else { return }

        do {
            try save()
        } catch {
            assertionFailure("Failed to save model context (\(context)): \(error)")
        }
    }
}
