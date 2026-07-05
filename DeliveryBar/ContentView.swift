//
//  ContentView.swift
//  DeliveryBar
//
//  Created by didi on 2026/6/28.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MenuBarView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Requirement.self, TemporaryTask.self, PersonProfile.self, QuickEntry.self, JSONFormatHistory.self], inMemory: true)
}
