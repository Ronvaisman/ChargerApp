//
//  ChargerAppApp.swift
//  ChargerApp
//
//  Created by Ron Vaisman on 24/04/2025.
//

import SwiftUI

@main
struct ZapNTapApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var viewModel = ChargingSessionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(viewModel)
        }
    }
}
