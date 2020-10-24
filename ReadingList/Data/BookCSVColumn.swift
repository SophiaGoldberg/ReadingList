import Foundation
import ReadingList_Foundation

/// Enumerates the columns in the native Reading List CSV export.  Note that lists are to be semicolon separated, any any semicolon in an item will be escaped to `\;`,
/// and any backslash will be escaped to `\\`.
enum BookCSVColumn: CaseIterable {
    case isbn13
    case googleBooksId
    case title
    case subtitle
    case authors
    case pageCount
    case publicationDate
    case publisher
    case bookDescription
    case subjects
    case language
    case startedReading
    case finishedReading
    case currentPage
    case currentPercentage
    case rating
    case notes
    /// A column which holds all lists which the book belongs to, in the form `List A (19); List B (3); List C (4)`.
    case lists
}

extension BookCSVColumn: CsvColumn {
    static var dateFormat: String { "YYYY-MM-dd" }

    /// The CsvExport containing all columns
    static var export: CsvExport<BookCSVColumn> {
        CsvExport(columns: BookCSVColumn.allCases)
    }

    var isMandatoryForImport: Bool {
        return self == .title || self == .authors
    }

    /// The header for the CSV column
    var header: String {
        switch self {
        case .isbn13: return "ISBN-13"
        case .googleBooksId: return "Google Books ID"
        case .title: return "Title"
        case .subtitle: return "Subtitle"
        case .authors: return "Authors"
        case .pageCount: return "Page Count"
        case .publicationDate: return "Publication Date"
        case .publisher: return "Publisher"
        case .bookDescription: return "Description"
        case .subjects: return "Subjects"
        case .language: return "Language Code"
        case .startedReading: return "Started Reading"
        case .finishedReading: return "Finished Reading"
        case .currentPage: return "Current Page"
        case .currentPercentage: return "Current Percentage"
        case .rating: return "Rating"
        case .notes: return "Notes"
        case .lists: return "Lists"
        }
    }

    // FUTURE: The design of this is not completely clear: why does a column have the ability to get data from a Book (i.e.
    // for an export), but not from the CSVRow (i.e. from an import)? This needs a bit of thought to improve clarity.
    func cellValue(_ book: Book) -> String? { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .isbn13: return book.isbn13?.string
        case .googleBooksId: return book.googleBooksId
        case .title: return book.title
        case .subtitle: return book.subtitle
        case .authors: return book.authors.map { author -> String in
            if let firstNames = author.firstNames {
                let escapedLastName = author.lastName.escaping(",")
                let escapedFirstNames = firstNames.escaping(",")
                return "\(escapedLastName), \(escapedFirstNames)"
            } else {
                // Escape the commas even though we are not separating by comma, so that we don't get confused when
                // importing from this string.
                return author.lastName.escaping(",")
            }
            // We have already escaped the escape characters when we were escaping the commas, above
        }.semicolonSeparated(escapeEscapeCharacterLiterals: false)
        case .pageCount: return book.pageCount?.string
        case .publicationDate: return book.publicationDate?.string(withDateFormat: Self.dateFormat)
        case .publisher: return book.publisher
        case .bookDescription: return book.bookDescription
        case .subjects: return book.subjects.map(\.name).semicolonSeparated()
        case .language: return book.language?.rawValue
        case .startedReading: return book.startedReading?.string(withDateFormat: Self.dateFormat)
        case .finishedReading: return book.finishedReading?.string(withDateFormat: Self.dateFormat)
        case .notes: return book.notes
        case .currentPage:
            guard let currentPage = book.currentPage, book.progressAuthority == .page else { return nil }
            return currentPage.string
        case .currentPercentage:
            guard let currentPercentage = book.currentPercentage, book.progressAuthority == .percentage else { return nil }
            return currentPercentage.string
        case .rating:
            guard let rating = book.rating, let ratingDouble = Double(exactly: rating) else { return nil }
            return "\(ratingDouble / 2)"
        case .lists:
            // We want to return a cell value like:
            //      List A (19); List B (3); List C (4)
            // Increment the sort value to make them 1-based.
            return book.listItems.sorted(byAscending: { $0.list.name }).map {
                "\($0.list.name) (\($0.sort + 1))"
            }.semicolonSeparated()
        }
    }
}

extension Sequence where Element == String {
    /**
     Returns a String which contains the items separated by semicolons, with any semicolons in each item escaped.
     */
    func semicolonSeparated(escapeEscapeCharacterLiterals: Bool = true) -> String {
        return self.map { $0.escaping(";", escapeEscapeCharacterLiterals: escapeEscapeCharacterLiterals) }.joined(separator: "; ")
    }
}

extension String {
    static let escapeCharacter = #"\"#

    func escaping(_ character: String, escapeEscapeCharacterLiterals: Bool = true) -> String {
        let input: String
        if escapeEscapeCharacterLiterals {
            input = replacingOccurrences(of: Self.escapeCharacter, with: "\(Self.escapeCharacter)\(Self.escapeCharacter)")
        } else {
            input = self
        }
        return input.replacingOccurrences(of: character, with: "\(Self.escapeCharacter)\(character)")
    }

    func unescaping(_ characters: String..., unescapeEscapedEscapeCharacters: Bool = true) -> String {
        var result = self
        for character in characters {
            result = result.replacingOccurrences(of: "\(Self.escapeCharacter)\(character)", with: character)
        }
        if unescapeEscapedEscapeCharacters {
            return result.replacingOccurrences(of: "\(Self.escapeCharacter)\(Self.escapeCharacter)", with: Self.escapeCharacter)
        } else {
            return result
        }
    }
}
