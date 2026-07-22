import Foundation

// MARK: - Currency Formatting

extension Double {
    /// Format as currency string: "$1,234.56"
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$0"
    }
    
    /// Format as compact currency: "$1.2K"
    var asCompactCurrency: String {
        if abs(self) >= 1000 {
            return String(format: "$%.1fK", self / 1000)
        }
        return asCurrency
    }
}

// MARK: - Date Helpers

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: self)
        ) ?? self
    }
    
    var endOfMonth: Date {
        Calendar.current.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: startOfMonth
        ) ?? self
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
    
    var shortMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: self)
    }
}
