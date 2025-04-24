import Foundation
import CoreData
import SwiftUI

class ChargingSessionViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    @Published var currentSession: ChargingSession?
    @Published var sessions: [ChargingSession] = []
    @Published var errorMessage: String?
    
    // Default electricity rate as specified in PRD
    private let defaultRate: Double = 0.6402
    @AppStorage("electricityRate") var electricityRate: Double = 0.6402
    @AppStorage("defaultPreviousReading") var defaultPreviousReading: Double = 0.0
    
    init(context: NSManagedObjectContext) {
        print("Initializing ChargingSessionViewModel")
        self.context = context
        fetchSessions()
    }
    
    func fetchSessions() {
        print("Fetching sessions...")
        let request = NSFetchRequest<ChargingSession>(entityName: "ChargingSession")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChargingSession.timestamp, ascending: false)]
        
        do {
            sessions = try context.fetch(request)
            print("Fetched \(sessions.count) sessions")
            for (index, session) in sessions.enumerated() {
                print("Session \(index): ID: \(session.id?.uuidString ?? "nil"), Date: \(session.formattedDate), kWh: \(session.kwhUsed), Cost: \(session.cost), isPaid: \(session.isPaid)")
            }
        } catch {
            print("Error fetching sessions: \(error)")
            errorMessage = "Failed to fetch sessions: \(error.localizedDescription)"
        }
    }
    
    // Add debug method to validate session
    func validateSession(_ session: ChargingSession) -> Bool {
        print("Validating session: \(session.formattedDate)")
        print("Session data:")
        print("- ID: \(session.id?.uuidString ?? "nil")")
        print("- Previous Reading: \(session.previousReading)")
        print("- New Reading: \(session.newReading)")
        print("- kWh Used: \(session.kwhUsed)")
        print("- Cost: \(session.cost)")
        print("- isPaid: \(session.isPaid)")
        print("- Has Photo: \(session.photoURL != nil)")
        print("- Notes: \(session.notes ?? "nil")")
        
        // Validate essential properties
        guard session.id != nil else {
            print("❌ Session validation failed: Missing ID")
            return false
        }
        guard session.timestamp != nil else {
            print("❌ Session validation failed: Missing timestamp")
            return false
        }
        guard session.newReading > session.previousReading else {
            print("❌ Session validation failed: Invalid readings")
            return false
        }
        guard session.kwhUsed > 0 else {
            print("❌ Session validation failed: Invalid kWh")
            return false
        }
        guard session.cost > 0 else {
            print("❌ Session validation failed: Invalid cost")
            return false
        }
        
        print("✅ Session validation passed")
        return true
    }
    
    func calculateUsage(previousReading: Double, newReading: Double) -> (kwhUsed: Double, cost: Double)? {
        guard newReading > previousReading else {
            errorMessage = "New reading must be greater than previous reading"
            return nil
        }
        
        let kwhUsed = newReading - previousReading
        let cost = kwhUsed * electricityRate
        
        return (kwhUsed, cost)
    }
    
    func createSession(previousReading: Double, newReading: Double, photoURL: URL? = nil, notes: String? = nil) {
        guard let calculation = calculateUsage(previousReading: previousReading, newReading: newReading) else {
            return
        }
        
        let session = ChargingSession(context: context)
        session.previousReading = previousReading
        session.newReading = newReading
        session.kwhUsed = calculation.kwhUsed
        session.cost = calculation.cost
        session.isPaid = false
        session.photoURL = photoURL
        session.notes = notes
        
        do {
            try context.save()
            fetchSessions()
        } catch {
            errorMessage = "Failed to save session: \(error.localizedDescription)"
        }
    }
    
    // Modify existing methods to include validation
    func togglePaidStatus(for session: ChargingSession) {
        print("Toggling paid status for session: \(session.formattedDate)")
        guard validateSession(session) else {
            errorMessage = "Invalid session data"
            return
        }
        
        session.isPaid.toggle()
        saveContext()
    }
    
    private func saveContext() {
        do {
            print("Saving context...")
            try context.save()
            print("Context saved successfully")
            fetchSessions()
        } catch {
            print("Error saving context: \(error)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    func updateNotes(for session: ChargingSession, notes: String) {
        session.notes = notes
        
        do {
            try context.save()
            fetchSessions()
        } catch {
            errorMessage = "Failed to update notes: \(error.localizedDescription)"
        }
    }
    
    // Analytics methods
    func totalUnpaidAmount() -> Double {
        return sessions.filter { !$0.isPaid }.reduce(0) { $0 + $1.cost }
    }
    
    func totalKwhThisMonth() -> Double {
        let calendar = Calendar.current
        let now = Date()
        return sessions.filter { session in
            guard let timestamp = session.timestamp else { return false }
            return calendar.isDate(timestamp, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.kwhUsed }
    }
    
    func totalCostThisMonth() -> Double {
        let calendar = Calendar.current
        let now = Date()
        return sessions.filter { session in
            guard let timestamp = session.timestamp else { return false }
            return calendar.isDate(timestamp, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.cost }
    }
    
    func deleteSession(_ session: ChargingSession) {
        context.delete(session)
        
        do {
            try context.save()
            fetchSessions()
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
        }
    }
    
    func updatePhoto(for session: ChargingSession, url: URL) {
        // Delete old photo if exists
        if let oldURL = session.photoURL {
            try? FileManager.default.removeItem(at: oldURL)
        }
        
        session.photoURL = url
        
        do {
            try context.save()
            fetchSessions()
        } catch {
            errorMessage = "Failed to update photo: \(error.localizedDescription)"
        }
    }
    
    func removePhoto(from session: ChargingSession) {
        // Delete the photo file
        if let photoURL = session.photoURL {
            try? FileManager.default.removeItem(at: photoURL)
        }
        
        session.photoURL = nil
        
        do {
            try context.save()
            fetchSessions()
        } catch {
            errorMessage = "Failed to remove photo: \(error.localizedDescription)"
        }
    }
    
    func saveDefaultPreviousReading(_ reading: Double) {
        print("Saving default previous reading: \(reading)")
        if reading > 0 {
            defaultPreviousReading = reading
        }
    }
    
    func getDefaultPreviousReading() -> Double {
        return defaultPreviousReading
    }
} 