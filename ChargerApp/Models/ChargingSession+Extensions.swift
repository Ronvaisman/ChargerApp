import Foundation
import CoreData

extension ChargingSession {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
        self.timestamp = Date()
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        guard let timestamp = timestamp else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Computed property for formatted cost
    var formattedCost: String {
        return String(format: "%.2f ILS", cost)
    }
    
    // Computed property for formatted kWh
    var formattedKWh: String {
        return String(format: "%.1f kWh", kwhUsed)
    }
} 