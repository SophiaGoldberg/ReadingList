import Foundation
import Swifter
import ReadingList_Foundation

public class MockServer {
    public let server = HttpServer()

    public init() {
        let mockedApiCalls = buildMockedApiCalls()
        let mockedPaths = mockedApiCalls.map { $0.request.path }.distinct()
        for path in mockedPaths {
            server.get[path] = { incomingRequest in
                guard let mockedRequest = mockedApiCalls.first(where: { mockRequest in
                    // The incoming request path starts with a '/' - drop this.
                    mockRequest.request.path == String(incomingRequest.path.dropFirst())
                        && (mockRequest.request.queryString ?? "") == incomingRequest.queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
                }) else {
                    return .notFound
                }
                return .ok(mockedRequest.response)
            }
            print("Registered responder to URL \(path)")
        }
    }

    private func buildMockedApiCalls() -> [(request: GoogleBooksRequest, response: HttpResponseBody)] {
        let jsonFileUrls = Bundle(for: type(of: self)).urls(forResourcesWithExtension: "json", subdirectory: nil)!
        let jsonApiCalls = jsonFileUrls.compactMap { fileUrl -> (request: GoogleBooksRequest, response: HttpResponseBody)? in
            let request: GoogleBooksRequest
            if let isbnMatch = fileUrl.lastPathComponent.regex("^Isbn_(\\d{13}).json$").first {
                request = GoogleBooksRequest.searchIsbn(String(isbnMatch.groups.first!))
            } else if let fetch = fileUrl.lastPathComponent.regex("^Fetch_(.+).json$").first {
                request = GoogleBooksRequest.fetch(fetch.groups.first!)
            } else if let search = fileUrl.lastPathComponent.regex("^Search_(.+).json$").first {
                request = GoogleBooksRequest.searchText(search.groups.first!, nil)
            } else {
                print("Unmatched file \(fileUrl.absoluteString)")
                return nil
            }

            let jsonData = try! JSONSerialization.jsonObject(with: try! Data(contentsOf: fileUrl))
            return (request, .json(jsonData as AnyObject))
        }

        let imageFileUrls = Bundle(for: type(of: self)).urls(forResourcesWithExtension: "jpg", subdirectory: nil)!
        let imageApiCalls = imageFileUrls.compactMap { fileUrl -> (request: GoogleBooksRequest, response: HttpResponseBody)? in
            (GoogleBooksRequest.coverImage(fileUrl.deletingPathExtension().lastPathComponent, .thumbnail), .data(try! Data(contentsOf: fileUrl)))
        }

        return jsonApiCalls + imageApiCalls
    }
}

extension String {
    func regex(_ regex: String) -> [(match: String, groups: [String])] {
        let regex = try! NSRegularExpression(pattern: regex)
        return regex.matches(in: self, range: NSRange(location: 0, length: self.count)).map { match in
            (self[match.range], (1..<match.numberOfRanges).map { self[match.range(at: $0)] })
        }
    }

    subscript(range: NSRange) -> String {
        return String(self[Range(range, in: self)!])
    }
}
