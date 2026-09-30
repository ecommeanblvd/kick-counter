import Foundation

func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}
