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
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchSessions()
    }
    
    func fetchSessions() {
        let request = NSFetchRequest<ChargingSession>(entityName: "ChargingSession")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChargingSession.timestamp, ascending: false)]
        
        do {
            sessions = try context.fetch(request)
            print("Fetched \(sessions.count) sessions")
            for session in sessions {
                print("Session: \(session.formattedDate), Paid: \(session.isPaid)")
            }
        } catch {
            errorMessage = "Failed to fetch sessions: \(error.localizedDescription)"
        }
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
    
    func togglePaidStatus(for session: ChargingSession) {
        print("Toggling paid status for session: \(session.formattedDate)")
        print("Current status: \(session.isPaid)")
        
        session.isPaid.toggle()
        
        do {
            try context.save()
            print("Saved new status: \(session.isPaid)")
            fetchSessions()
        } catch {
            errorMessage = "Failed to update payment status: \(error.localizedDescription)"
            print("Error saving status: \(error.localizedDescription)")
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
} 