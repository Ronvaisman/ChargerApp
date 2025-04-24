//
//  ContentView.swift
//  ChargerApp
//
//  Created by Ron Vaisman on 24/04/2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: ChargingSessionViewModel
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: ChargingSessionViewModel(context: context))
    }
    
    var body: some View {
        TabView {
            NewSessionView(viewModel: viewModel)
                .tabItem {
                    Label("Usage", systemImage: "bolt.fill")
                }
            
            SessionsView(viewModel: viewModel)
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet")
                }
            
            AnalyticsView(viewModel: viewModel)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return ContentView(context: context)
}
