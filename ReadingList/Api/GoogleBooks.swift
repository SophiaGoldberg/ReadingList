import Foundation
import SwiftyJSON
import Promises
import ReadingList_Foundation

class GoogleBooks {

    /**
     Searches on Google Books for the given search string
     */
    static func search(_ text: String) -> Promise<[SearchResult]> {
        return URLSession.shared.json(url: GoogleBooksRequest.searchText(text).url)
            .then(GoogleBooksParser.assertNoError)
            .then(GoogleBooksParser.parseSearchResults)
    }

    /**
     Searches on Google Books for the given ISBN
     */
    static func fetch(isbn: String) -> Promise<FetchResult> {
        return URLSession.shared.json(url: GoogleBooksRequest.searchIsbn(isbn).url)
            .then(GoogleBooksParser.parseSearchResults)
            .then {
                guard let id = $0.first?.id else { throw GoogleError.noResult }
                return fetch(googleBooksId: id)
            }
    }

    /**
     Fetches the specified book from Google Books. Performs a supplementary request for the
     book's cover image data if necessary.
     */
    static func fetch(googleBooksId: String) -> Promise<FetchResult> {
        return fetch(googleBooksId: googleBooksId, existingSearchResult: nil)
    }

    /**
     Fetches the book identified by a search result from Google Books. If the fetch results are not sufficient
     to create a Book object (sometimes fetch results miss data which is present in a search result), an attempt
     is made to "mix" the data from the search and fetch results. Performs a supplementary request for the
     book's cover image data if necessary.
     */
    static func fetch(searchResult: SearchResult) -> Promise<FetchResult> {
        return fetch(googleBooksId: searchResult.id, existingSearchResult: searchResult)
    }

    /**
     Fetches the specified book from Google Books. If the results are not sufficient to create a Book object,
     and a search result was supplied, an attempt is made to "mix" the data from the search and fetch results.
     Performs a supplementary request for the book's cover image data if necessary.
     */
    private static func fetch(googleBooksId: String, existingSearchResult: SearchResult?) -> Promise<FetchResult> {
        let fetchPromise = URLSession.shared.json(url: GoogleBooksRequest.fetch(googleBooksId).url)
            .then { json -> FetchResult in
                if let fetchResult = GoogleBooksParser.parseFetchResults(json) {
                    return fetchResult
                }
                if let existingSearchResult = existingSearchResult,
                    let fetchResult = GoogleBooksParser.parseFetchResults(json, existingSearchResult: existingSearchResult) {
                    return fetchResult
                }
                throw GoogleError.missingEssentialData
            }

        let coverPromise = fetchPromise.then { getCover(googleBooksId: $0.id) }

        return any(fetchPromise, coverPromise).then { fetch, cover -> FetchResult in
            switch fetch {
            case let .value(fetchResultValue):
                if case let .value(coverDataValue) = cover {
                    fetchResultValue.coverImage = coverDataValue
                }
                return fetchResultValue
            case let .error(fetchResultError):
                throw fetchResultError
            }
        }
    }

    /**
     Gets the cover image data for the book corresponding to the Google Books ID (if exists).
     */
    static func getCover(googleBooksId: String) -> Promise<Data> {
        return URLSession.shared.data(url: GoogleBooksRequest.coverImage(googleBooksId, .thumbnail).url)
    }
}

enum GoogleBooksRequest {

    case searchText(String)
    case searchIsbn(String)
    case fetch(String)
    case coverImage(String, CoverType)
    case webpage(String)

    enum CoverType: Int {
        case thumbnail = 1
        case small = 2
    }

    // The base URL for GoogleBooks API v1 requests
    private static let apiBaseUrl = URL(string: "https://www.googleapis.com/")!
    private static let googleBooksBaseUrl = URL(string: "https://books.google.com/")!

    private static let searchResultFields = "items(id,volumeInfo(title,authors,industryIdentifiers,categories,imageLinks/thumbnail))"

    var url: URL {
        switch self {
        case let .searchText(searchString):
            let encodedQuery = searchString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            let relativeUrl = "books/v1/volumes?q=\(encodedQuery)&maxResults=40&fields=\(GoogleBooksRequest.searchResultFields)"
            return URL(string: relativeUrl, relativeTo: GoogleBooksRequest.apiBaseUrl)!
        case let .searchIsbn(isbn):
            let relativeUrl = "books/v1/volumes?q=isbn:\(isbn)&maxResults=40&fields=\(GoogleBooksRequest.searchResultFields)"
            return URL(string: relativeUrl, relativeTo: GoogleBooksRequest.apiBaseUrl)!
        case let .fetch(id):
            return URL(string: "books/v1/volumes/\(id)", relativeTo: GoogleBooksRequest.apiBaseUrl)!
        case let .coverImage(googleBooksId, coverType):
            return URL(string: "books/content?id=\(googleBooksId)&printsec=frontcover&img=1&zoom=\(coverType.rawValue)", relativeTo: GoogleBooksRequest.googleBooksBaseUrl)!
        case let .webpage(googleBooksId):
            return URL(string: "books?id=\(googleBooksId)", relativeTo: GoogleBooksRequest.googleBooksBaseUrl)!
        }
    }
}

class GoogleBooksParser {

    static func parseError(json: JSON) -> GoogleError? {
        if let code = json["error", "code"].int, let message = json["error", "message"].string {
            return GoogleError.specifiedError(code: code, message: message)
        }
        return nil
    }

    static func assertNoError(json: JSON) throws -> JSON {
        if let error = GoogleBooksParser.parseError(json: json) {
            throw error
        } else {
            return json
        }
    }

    static func parseSearchResults(_ searchResults: JSON) -> [SearchResult] {
        return searchResults["items"].compactMap { itemJson in
            GoogleBooksParser.parseItem(itemJson.1)
        }
    }

    static func parseItem(_ item: JSON) -> SearchResult? {
        guard let id = item["id"].string, !id.isEmptyOrWhitespace,
            let title = item["volumeInfo", "title"].string, !title.isEmptyOrWhitespace,
            let authorsJson = item["volumeInfo", "authors"].array, !authorsJson.isEmpty else { return nil }
        let authors: [String] = authorsJson.compactMap {
            guard let authorString = $0.rawString(), !authorString.isEmptyOrWhitespace else { return nil }
            return authorString
        }
        guard !authors.isEmpty else { return nil }

        let result = SearchResult(id: id, title: title, authors: authors)

        // Convert the thumbnail URL to HTTPS
        if let thumbnailUrlString = item["volumeInfo", "imageLinks", "thumbnail"].string,
            let thumbnailUrl = URL(string: thumbnailUrlString) {
            var urlComponents = URLComponents(url: thumbnailUrl, resolvingAgainstBaseURL: false)!
            urlComponents.scheme = "https"
            result.thumbnailCoverUrl = urlComponents.url
        }
        result.isbn13 = item["volumeInfo", "industryIdentifiers"].array?.first {
            $0["type"].stringValue == "ISBN_13"
        }?["identifier"].stringValue

        return result
    }

    static func parseFetchResults(_ fetchResult: JSON, existingSearchResult: SearchResult? = nil) -> FetchResult? {

        // Defer to the common search parsing initially, or use the provided search result
        guard let searchResult = existingSearchResult ?? GoogleBooksParser.parseItem(fetchResult) else { return nil }

        let result = FetchResult(fromSearchResult: searchResult)
        result.pageCount = fetchResult["volumeInfo", "pageCount"].int
        if let code = fetchResult["volumeInfo"]["language"].string, Language.byIsoCode[code] != nil {
            result.languageCode = code
        }
        // "Published Date" refers to *this* edition; there doesn't seem to be a way to get the first publication date :(
        //result.publishedDate = fetchResult["volumeInfo","publishedDate"].string?.toDateViaFormat("yyyy-MM-dd")

        result.hasSmallImage = fetchResult["volumeInfo", "imageLinks", "small"].string != nil
        result.hasThumbnailImage = fetchResult["volumeInfo", "imageLinks", "thumbnail"].string != nil

        // This string may contain some HTML. We want to remove them, but first we might as well replace the "<br>"s with '\n's
        // and the "<p>"s with "\n\n".
        var description = fetchResult["volumeInfo", "description"].string

        description = description?.components(separatedBy: "<br>")
            .map { $0.trimming() }
            .joined(separator: "\n")

        description = description?.components(separatedBy: "<p>")
            .flatMap { $0.components(separatedBy: "</p>") }
            .compactMap { $0.trimming().nilIfWhitespace() }
            .joined(separator: "\n\n")

        description = description?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        result.description = description

        // Try to get the categories
        if let subjects = fetchResult["volumeInfo", "categories"].array {
            result.subjects = subjects.flatMap {
                $0.stringValue.components(separatedBy: "/").map { $0.trimming() }
            }.filter { $0 != "General" }.distinct()
        }

        return result
    }
}

class SearchResult {
    let id: String
    var title: String
    var authors: [String]
    var isbn13: String?
    var thumbnailCoverUrl: URL?

    init(id: String, title: String, authors: [String]) {
        self.id = id
        self.title = title
        self.authors = authors
    }
}

class FetchResult {
    let id: String
    var title: String
    var authors = [String]()
    var isbn13: ISBN13?
    var description: String?
    var subjects = [String]()
    var languageCode: String?
    var publishedDate: Date?
    var pageCount: Int?
    var hasThumbnailImage: Bool = false
    var hasSmallImage: Bool = false

    var coverImage: Data?

    init(fromSearchResult searchResult: SearchResult) {
        id = searchResult.id
        title = searchResult.title
        authors = searchResult.authors
        isbn13 = ISBN13(searchResult.isbn13)
    }
}

enum GoogleError: Error {
    case noResult
    case missingEssentialData
    case specifiedError(code: Int, message: String)
}
