import SwiftUI
import Foundation

extension String {
    var localized: String {
        return Bundle.main.localizedString(forKey: self, value: nil, table: nil)
    }
}

extension Text {
    init(localized key: String) {
        let localizedString = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        self.init(verbatim: localizedString)
    }
}

extension View {
    func localized() -> some View {
        self.environment(\.layoutDirection, Locale.current.language.languageCode?.identifier == "he" ? .rightToLeft : .leftToRight)
    }
} 
