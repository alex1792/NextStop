//
//  NextStopApp.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
//

import SwiftUI
import SwiftData

@main
struct NextStopApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Trip.self,  //  register models defined in Trip.swift
            Stop.self,  // register models defined in Stop.swift
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
