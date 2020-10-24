import Foundation

enum Progress: Equatable {
    case percentage(Int32?)
    case page(Int32?)
}

enum ProgressType: Int, Equatable, CustomStringConvertible {
    case page = 1
    case percentage = 2

    var description: String {
        switch self {
        case .page: return "Page"
        case .percentage: return "Percentage"
        }
    }
}
