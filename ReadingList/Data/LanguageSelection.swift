import Foundation
import ReadingList_Foundation

enum LanguageSelection: CustomStringConvertible, Equatable {
    case none
    case blank
    case some(LanguageIso639_1)

    var description: String {
        switch self {
        case .none: return "None"
        case .blank: return ""
        case let .some(language): return language.description
        }
    }
}
