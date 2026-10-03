import Foundation

func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}
