import Foundation

@objc public enum BookReadState: Int16, CustomStringConvertible, CaseIterable, Codable {
    case reading = 1
    case toRead = 2
    case finished = 3

    public var description: String {
        switch self {
        case .reading: return "Reading"
        case .toRead: return "To Read"
        case .finished: return "Finished"
        }
    }

    var longDescription: String {
        switch self {
        case .toRead:
            return "📚 To Read"
        case .reading:
            return "📖 Currently Reading"
        case .finished:
            return "🎉 Finished"
        }
    }
}
