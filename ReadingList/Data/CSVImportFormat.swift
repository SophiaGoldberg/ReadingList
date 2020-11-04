import Foundation

enum CSVImportFormat: Int, Codable, CaseIterable {
    case readingList = 0
    case goodreads = 1
}

extension CSVImportFormat: CustomStringConvertible {
    var description: String {
        switch self {
        case .readingList:
            return "Reading List"
        case .goodreads:
            return "Goodreads"
        }
    }
}

extension CSVImportFormat {
    var requiredHeaders: [String] {
        switch self {
        case .readingList:
            return BookCSVColumn.allCases.filter(\.isMandatoryForImport).map(\.header)
        case .goodreads:
            return ["Title", "Author l-f"]
        }
    }
}
