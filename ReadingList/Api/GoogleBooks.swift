import Foundation
import Promises
import ReadingList_Foundation
import os.log

struct GoogleBooksApi {

    private let jsonDecoder = JSONDecoder()

    /**
     Searches on Google Books for the given search string
     */
    func search(_ text: String) -> Promise<[SearchResult]> {
        os_log("Searching for Google Books with query", type: .debug)
        guard let url = GoogleBooksRequest.searchText(text, GeneralSettings.searchLanguageRestriction).url else {
            return Promise<[SearchResult]>(ResponseError.invalidUrl)
        }
        return URLSession.shared.data(url: url)
            .then(assertNoError)
            .then(parseSearchResults)
    }

    /**
     Searches on Google Books for the given ISBN
     */
    func fetch(isbn: String) -> Promise<FetchResult> {
        os_log("Searching for Google Book with ISBN %{public}s", type: .debug, isbn)
        guard let url = GoogleBooksRequest.searchIsbn(isbn).url else {
            os_log("Invalid URL for ISBN search (%{public}s)", type: .error, isbn)
            return Promise<FetchResult>(ResponseError.invalidUrl)
        }
        return URLSession.shared.data(url: url)
            .then(parseSearchResults)
            .then {
                guard let result = $0.first else { throw ResponseError.noResult }
                os_log("Resolved ISBN %{public}s to Google Books ID %{public}s", type: .info, isbn, result.id)
                return self.fetch(searchResult: result)
            }
    }

    /**
     Fetches the specified book from Google Books. Performs a supplementary request for the
     book's cover image data if requested.
     */
    func fetch(googleBooksId: String, fetchCoverImage: Bool = true) -> Promise<FetchResult> {
        return fetch(googleBooksId: googleBooksId, existingSearchResult: nil, fetchCoverImage: fetchCoverImage)
    }

    /**
     Fetches the book identified by a search result from Google Books. If the fetch results are not sufficient
     to create a Book object (sometimes fetch results miss data which is present in a search result), an attempt
     is made to "mix" the data from the search and fetch results. Performs a supplementary request for the
     book's cover image data if requested.
     */
    func fetch(searchResult: SearchResult, fetchCoverImage: Bool = true) -> Promise<FetchResult> {
        return fetch(googleBooksId: searchResult.id, existingSearchResult: searchResult, fetchCoverImage: fetchCoverImage)
    }

    /**
     Fetches the specified book from Google Books. If the results are not sufficient to create a Book object,
     and a search result was supplied, an attempt is made to "mix" the data from the search and fetch results.
     Performs a supplementary request for the book's cover image data if requested.
     */
    private func fetch(googleBooksId: String, existingSearchResult: SearchResult?, fetchCoverImage: Bool) -> Promise<FetchResult> {
        os_log("Fetching Google Book with ID %{public}s", type: .info, googleBooksId)
        guard let url = GoogleBooksRequest.fetch(googleBooksId).url else {
            return Promise<FetchResult>(ResponseError.invalidUrl)
        }
        let fetchPromise = URLSession.shared.data(url: url)
            .then { data -> ItemMetadata in
                os_log("Data response for Google Book %{public}s received", type: .info, googleBooksId)
                return try self.jsonDecoder.decode(ItemMetadata.self, from: data)
            }
            .catch {
                os_log("Error decoding JSON into ItemMetadata for Google Book %{public}s: %{public}s", type: .error, googleBooksId, $0.localizedDescription)
            }
            .then { result -> FetchResult in
                if let searchResult = existingSearchResult {
                    return FetchResult(result, searchResult)
                } else if let fetchResult = FetchResult(result) {
                    return fetchResult
                } else {
                    os_log("Could not build a FetchResult from the ItemMetadata", type: .error)
                    throw ResponseError.invalidResult
                }
            }
            .recover { error -> FetchResult in
                if let existingSearchResult = existingSearchResult {
                    os_log("Falling back to using existing search result for Google Book with ID %{public}s", type: .default, googleBooksId)
                    return FetchResult(existingSearchResult)
                }
                throw error
            }

        if !fetchCoverImage {
            return fetchPromise
        }

        let coverPromise = fetchPromise.then {
            self.getCover(googleBooksId: $0.id)
        }

        return any(fetchPromise, coverPromise).then { fetch, cover -> FetchResult in
            os_log("Fetch and Cover request both complete for Google Book %{public}s", type: .info, googleBooksId)
            switch fetch {
            case var .value(fetchResult):
                if case let .value(coverDataValue) = cover {
                    fetchResult.image = coverDataValue
                }
                return fetchResult
            case let .error(fetchResultError):
                throw fetchResultError
            }
        }
    }

    /**
     Gets the cover image data for the book corresponding to the Google Books ID (if exists).
     */
    func getCover(googleBooksId: String) -> Promise<Data> {
        guard let url = GoogleBooksRequest.coverImage(googleBooksId, .thumbnail).url else {
            return Promise<Data>(ResponseError.invalidUrl)
        }
        os_log("Requesting cover image for Google Books ID %{public}s", type: .info)
        return URLSession.shared.data(url: url)
    }

    func assertNoError(json: Data) throws {
        if let googleError = try? jsonDecoder.decode(ReportedError.self, from: json) {
            throw ResponseError.specifiedError(code: googleError.error.code, message: googleError.error.message)
        }
    }

    func parseSearchResults(_ searchResults: Data) throws -> [SearchResult] {
        os_log("Parsing data as SearchResult array", type: .info)
        do {
            let results = try jsonDecoder.decode(SearchResults.self, from: searchResults)
            return results.items?.compactMap(SearchResult.init).distinct(by: \.id) ?? []
        } catch {
            os_log("Error parsing search results: %{public}s", type: .error, error.localizedDescription)
            throw error
        }
    }

    func parseFetchResults(_ fetchResult: Data) throws -> FetchResult? {
        let result = try jsonDecoder.decode(ItemMetadata.self, from: fetchResult)
        return FetchResult(result)
    }

    /**
    Contains an item's metadata and cover image data
     */
    struct FetchResult {
        let id: String
        var title: String
        var authors: [String]
        var subtitle: String?
        var description: String?
        var isbn13: ISBN13?
        var pageCount: Int?
        var subjects = [String]()
        var publisher: String?
        var language: LanguageIso639_1?
        var thumbnailImage: URL?
        var smallImage: URL?
        var image: Data?

        private static func cleanDescription(_ description: String?) -> String? {
            // This string may contain some HTML. We want to remove them, but first we might as well replace the "<br>"s with '\n's
            // and the "<p>"s with "\n\n".
            return description?.components(separatedBy: "<br>")
                .map { $0.trimming() }
                .joined(separator: "\n")
                .components(separatedBy: "<p>")
                .flatMap { $0.components(separatedBy: "</p>") }
                .compactMap { $0.trimming().nilIfWhitespace() }
                .joined(separator: "\n\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private static func categoriesToSubjects(_ categories: [String]?) -> [String] {
            return categories?.flatMap { $0.components(separatedBy: "/") }
                .compactMap { $0.trimming().nilIfWhitespace() }
                .filter { $0 != "General" }
                .distinct() ?? []
        }

        private mutating func initialiseNonSearchResultProperties(_ volumeInfo: ItemMetadata.VolumeInfo) {
            description = FetchResult.cleanDescription(volumeInfo.description)
            isbn13 = ISBN13(volumeInfo.industryIdentifiers?.first { $0.type == "ISBN_13" }?.identifier)
            pageCount = volumeInfo.pageCount
            subjects = FetchResult.categoriesToSubjects(volumeInfo.categories)
            publisher = volumeInfo.publisher
            language = volumeInfo.language
            thumbnailImage = volumeInfo.imageLinks?.thumbnail?.withHttps()
            smallImage = volumeInfo.imageLinks?.small?.withHttps()
        }

        fileprivate init(_ itemMetadata: ItemMetadata, _ searchResult: SearchResult) {
            assert(itemMetadata.id == searchResult.id)
            id = searchResult.id
            title = searchResult.title
            authors = searchResult.authors
            subtitle = searchResult.subtitle
            initialiseNonSearchResultProperties(itemMetadata.volumeInfo)
        }

        fileprivate init(_ searchResult: SearchResult) {
            id = searchResult.id
            title = searchResult.title
            authors = searchResult.authors
            subtitle = searchResult.subtitle
        }

        fileprivate init?(_ itemMetadata: ItemMetadata) {
            guard let itemTitle = itemMetadata.volumeInfo.title else { return nil }
            guard let itemAuthors = itemMetadata.volumeInfo.authors, !itemAuthors.isEmpty else { return nil }
            id = itemMetadata.id
            title = itemTitle
            authors = itemAuthors
            subtitle = itemMetadata.volumeInfo.subtitle
            initialiseNonSearchResultProperties(itemMetadata.volumeInfo)
        }
    }

    struct SearchResult {
        let id: String
        let title: String
        let authors: [String]
        let subtitle: String?
        let isbn13: ISBN13?
        let thumbnailImage: URL?

        var titleAndSubtitle: String {
            if let subtitle = subtitle {
                return "\(title): \(subtitle)"
            } else {
                return title
            }
        }

        var authorList: String {
            authors.joined(separator: ", ")
        }

        fileprivate init?(_ itemMetadata: ItemMetadata) {
            id = itemMetadata.id
            guard let title = itemMetadata.volumeInfo.title else { return nil }
            self.title = title
            guard let authors = itemMetadata.volumeInfo.authors, !authors.isEmpty else { return nil }
            self.authors = authors
            subtitle = itemMetadata.volumeInfo.subtitle
            isbn13 = ISBN13(itemMetadata.volumeInfo.industryIdentifiers?.first { $0.type == "ISBN_13" }?.identifier)
            thumbnailImage = itemMetadata.volumeInfo.imageLinks?.thumbnail?.withHttps()
        }
    }

    enum ResponseError: Error {
        case noResult
        case invalidResult
        case invalidUrl
        case specifiedError(code: Int, message: String)
    }

    // MARK: Decodable JSON response models

    /**
     The data returned from a fetch request against Google Books
     */
    fileprivate struct ItemMetadata: Decodable {
        let id: String
        let volumeInfo: VolumeInfo

        struct VolumeInfo: Decodable {
            let title: String?
            let subtitle: String?
            let authors: [String]?
            let description: String?
            let industryIdentifiers: [IndustryIdentifier]?
            let pageCount: Int?
            let categories: [String]?
            let publisher: String?
            let language: LanguageIso639_1?
            let imageLinks: ImageLinks?

            struct ImageLinks: Decodable {
                let thumbnail: URL?
                let small: URL?
            }

            struct IndustryIdentifier: Decodable {
                let type: String
                let identifier: String
            }
        }
    }

    /**
     The metadata returned for a collection of items when searching on Google Books.
     */
    fileprivate struct SearchResults: Decodable {
        let items: [ItemMetadata]?
    }

    /**
     The description of an error which may be returned by a Google Books response.
     */
    fileprivate struct ReportedError: Decodable {
        struct Details: Decodable {
            let code: Int
            let message: String
        }

        let error: Details
    }
}
