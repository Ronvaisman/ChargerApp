//
//  ChargerAppApp.swift
//  ChargerApp
//
//  Created by Ron Vaisman on 24/04/2025.
//

import SwiftUI

@main
struct ChargerAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
