import Foundation
import CoreData
import SwiftUI

extension ChargingSession {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
        self.timestamp = Date()
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        guard let timestamp = timestamp else { return NSLocalizedString("Unknown Date", comment: "") }
        let formatter = DateFormatter()
        
        // Check if the locale is Hebrew
        if formatter.locale.identifier.hasPrefix("he") {
            formatter.dateFormat = "dd/MM/yy HH:mm"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        
        formatter.locale = Locale(identifier: NSLocalizedString("LOCALE", comment: ""))
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: timestamp)
    }
    
    // Computed property for formatted cost
    var formattedCost: String {
        return String(format: "%.2f %@", cost, NSLocalizedString("ILS", comment: ""))
    }
    
    // Computed property for formatted kWh
    var formattedKWh: String {
        return String(format: "%.1f %@", kwhUsed, NSLocalizedString("kWh", comment: ""))
    }
} 