import Foundation
import Regex
import ReadingList_Foundation

/// Holds data from a CSV row relating to a book, for import.
struct BookCSVImportRow {
    let title: String
    let authors: [Author]
    let subtitle: String?
    let description: String?
    let started: Date?
    let finished: Date?
    let googleBooksId: String?
    let manualBookId: String?
    let isbn13: ISBN13?
    let language: String?
    let notes: String?
    let currentPage: Int32?
    let currentPercentage: Int32?
    let pageCount: Int32?
    let publicationDate: Date?
    let publisher: String?
    let rating: Double?
    let subjects: [String]
    let lists: [ListIndex]

    struct ListIndex {
        let listName: String
        let index: Int32
    }

    /// Matches the format of a list membership text, e.g.`List Name (123)`, or `List Name (#123)`, producing the list name and the index as the first and second capture groups respectively.
    private static let extractListDetail = Regex(#"^(.+) \(#?(\d+)\)$"#)

    /**
     * Matches any string, and produces one or two capture groups, equal to the last name and - if present - the first name. The last name is defined as the portion of the string from the start
     * until the first non-escaped comma. An escaped comma is a comma preceeded by a backslash, unless the backslash is itself escaped (backslashes are escaped by preceeding them
     * with a backslashe, so commas preceeded by an even number of backslashes are "legit" commas).
    */
    private static let extractAuthorNameComponents = Regex(#"^(.*?[^\\](?:\\\\)*)(?:,(.*)|$)$"#)

    init?(for format: CSVImportFormat, row: [String: String]) {
        switch format {
        case .readingList:
            self.init(readingListRow: row)
        case .goodreads:
            self.init(goodreadsRow: row)
        }
    }

    init?(readingListRow row: [String: String]) {
        func value(_ csvColumn: BookCSVColumn) -> String? {
            row[csvColumn.header]
        }

        guard let title = value(.title), let authors = value(.authors) else { return nil }
        self.title = title
        // Don't unescape the escape characters yet; we need them to remain escaped until we unescape the commas
        self.authors = authors.semicolonSeparatedItems(unescapeEscapedEscapeCharacters: false).compactMap {
            guard let authorExtractionMatch = BookCSVImportRow.extractAuthorNameComponents.firstMatch(in: $0) else { return nil }
            guard [1, 2].contains(authorExtractionMatch.captures.count) else {
                assertionFailure("Unexpected number of captures: \(authorExtractionMatch.captures.count)")
                return nil
            }
            guard let lastName = authorExtractionMatch.captures[0]?.trimming().nilIfWhitespace()?.unescaping(",") else { return nil }
            let firstNames = authorExtractionMatch.captures[safe: 1]??.trimming().nilIfWhitespace()?.unescaping(",")
            return Author(lastName: lastName, firstNames: firstNames)
        }
        guard !self.authors.isEmpty else { return nil }

        subtitle = value(.subtitle)
        description = value(.bookDescription)
        started = Date(value(.startedReading), format: "yyyy-MM-dd")
        finished = Date(value(.finishedReading), format: "yyyy-MM-dd")
        googleBooksId = value(.googleBooksId)
        manualBookId = row["Reading List ID"]
        isbn13 = ISBN13(value(.isbn13))
        language = value(.language)
        notes = value(.notes)
        currentPage = Int32(value(.currentPage))
        currentPercentage = Int32(value(.currentPercentage))
        pageCount = Int32(value(.pageCount))
        publicationDate = Date(value(.publicationDate), format: "yyyy-MM-dd")
        publisher = value(.publisher)
        if let ratingString = value(.rating), let ratingValue = Double(ratingString) {
            rating = ratingValue
        } else {
            rating = nil
        }
        if let subjectsText = value(.subjects) {
            subjects = subjectsText.semicolonSeparatedItems()
        } else {
            subjects = []
        }
        if let listsText = value(.lists) {
            lists = listsText.semicolonSeparatedItems().compactMap(Self.listIndex(from:))
        } else {
            lists = []
        }
    }

    init?(goodreadsRow row: [String: String]) { //swiftlint:disable:this cyclomatic_complexity
        guard let title = row["Title"], let author = row["Author l-f"] else { return nil }
        self.title = title

        let firstAuthor: Author
        if let firstCommaPos = author.range(of: ","), let lastName = author[..<firstCommaPos.lowerBound].trimming().nilIfWhitespace() {
            firstAuthor = Author(lastName: lastName, firstNames: author[firstCommaPos.upperBound...].trimming().nilIfWhitespace())
        } else {
            firstAuthor = Author(lastName: author, firstNames: nil)
        }

        var additionalAuthors = [Author]()
        if let additionalAuthorsCell = row["Additional Authors"] {
            for additionalAuthor in additionalAuthorsCell.components(separatedBy: ",") {
                guard let trimmedAuthor = additionalAuthor.trimming().nilIfWhitespace() else { continue }
                if let range = trimmedAuthor.range(of: " ", options: .backwards),
                    let lastName = trimmedAuthor[range.upperBound...].trimming().nilIfWhitespace() {
                    additionalAuthors.append(Author(lastName: lastName, firstNames: trimmedAuthor[..<range.upperBound].trimming().nilIfWhitespace()))
                } else {
                    additionalAuthors.append(Author(lastName: trimmedAuthor, firstNames: nil))
                }
            }
        }
        authors = [firstAuthor] + additionalAuthors

        // The Exclusive Shelf seems to determine the "current" state of the book. Use this as an indicator of where to put the book.
        let exclusiveShelf = row["Exclusive Shelf"]
        if exclusiveShelf == "read" || exclusiveShelf == "currently-reading" {
            // There is only one read date provided in the CSV, so we have to use that for both started and finished. And it's not always
            // present either; in those cases, use the date added instead.
            if let dateString = row["Date Read"] ?? row["Date Added"] {
                started = Date(dateString, format: "yyyy/MM/dd")
            } else {
                started = Date()
            }

            if exclusiveShelf == "read" {
                finished = started
            } else {
                finished = nil
            }
        } else {
            started = nil
            finished = nil
        }

        manualBookId = row["Book Id"]
        // The GoodReads export seems to present ISBNs like: ="9781231231231"
        isbn13 = ISBN13(row["ISBN13"]?.trimmingCharacters(in: CharacterSet(charactersIn: "\"=")))

        notes = row["My Review"]
        pageCount = Int32(row["Number of Pages"])
        publisher = row["Publisher"]

        if let ratingString = row["My Rating"], let ratingValue = Double(ratingString) {
            rating = ratingValue
        } else {
            rating = nil
        }

        subtitle = nil
        description = nil
        googleBooksId = nil
        language = nil
        currentPage = nil
        currentPercentage = nil
        publicationDate = nil
        subjects = []
        if let bookshelvesWithPositions = row["Bookshelves with positions"] {
            lists = bookshelvesWithPositions.components(separatedBy: ",").compactMap(Self.listIndex(from:))
        } else {
            lists = []
        }
    }

    private static func listIndex(from string: String) -> ListIndex? {
        guard let match = BookCSVImportRow.extractListDetail.firstMatch(in: string) else { return nil }
        guard match.captures.count == 2 else {
            assertionFailure("Unexpected number of captures: \(match.captures.count)")
            return nil
        }
        guard let listName = match.captures[0]?.trimming().nilIfWhitespace(),
            let listIndex = match.captures[1]?.trimming().nilIfWhitespace() else { return nil }
        guard let integerListIndex = Int32(listIndex) else { return nil }
        return ListIndex(listName: listName, index: integerListIndex)
    }
}

extension String {
    /**
     * Matches components separated by semicolons, except semi-colons which are escaped (that is, preceeded by a backslash), unless the escape
     * character itself is part of an escaped backslash (that is, is part of an even number of successive backslashes).
     * E.g.:
     * -  `"Part1;Part2"` produces `["Part1", "Part2"]`
     * -  `"Part1\;Part1.1"` produces `["Part1\;Part1.1"]`
     * -  `"Part1\\;Part2"` produces `["Part1\\", "Part2"]`
    */
    private static let semicolonSeparatedItems = Regex(#"[^;].*?[^\\](?:\\\\)*(?=;|$)"#)

    func semicolonSeparatedItems(unescapeEscapedEscapeCharacters unescape: Bool = true) -> [String] {
        return Self.semicolonSeparatedItems.allMatches(in: self).compactMap {
            $0.matchedString.trimming().nilIfWhitespace()?.unescaping(";", unescapeEscapedEscapeCharacters: unescape)
        }
    }
}
