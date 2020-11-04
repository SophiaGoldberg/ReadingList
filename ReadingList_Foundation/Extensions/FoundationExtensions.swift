import Foundation
import AVFoundation
import UIKit
import os.log

public extension String {
    /// Return whether the string contains any characters which are not whitespace.
    var isEmptyOrWhitespace: Bool {
        return self.trimming().isEmpty
    }

    func nilIfWhitespace() -> String? {
        return isEmptyOrWhitespace ? nil : self
    }

    /// Returns the input string with an "s" appended if the supplied number was 0 or greater than 1.
    func pluralising(_ number: Int) -> String {
        if number == 1 {
            return self
        }
        return "\(self)s"
    }

    /// Removes all whitespace characters from the beginning and the end of the string.
    func trimming() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }

    func urlEncoding() -> String {
        let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[] ").inverted
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)!
    }

    var sortable: String {
        return self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale.current)
    }

    func append(toFile file: URL, encoding: String.Encoding) throws {
        if let fileHandle = try? FileHandle(forWritingTo: file) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(self.data(using: encoding)!)
        } else {
            try self.write(to: file, atomically: false, encoding: encoding)
        }
    }

    func attributedWithFont(_ font: UIFont) -> NSAttributedString {
        return NSAttributedString(self, font: font)
    }

    func startIndex(ofFirstSubstring substring: String) -> Int? {
        guard let substringRange = range(of: substring) else { return nil }
        return distance(from: startIndex, to: substringRange.lowerBound)
    }
}

public extension Int16 {
    var string: String {
        return "\(self)"
    }

    init?(_ string: String?) {
        guard let string = string else { return nil }
        self.init(string)
    }
}

public extension Int32 {
    var string: String {
        return "\(self)"
    }

    init?(_ string: String?) {
        guard let string = string else { return nil }
        self.init(string)
    }
}

public extension Int64 {
    var string: String {
        return "\(self)"
    }

    init?(_ string: String?) {
        guard let string = string else { return nil }
        self.init(string)
    }
}

public extension Int {
    var string: String {
        return "\(self)"
    }

    init?(_ string: String?) {
        guard let string = string else { return nil }
        self.init(string)
    }

    init?(_ int16: Int16?) {
        guard let int16 = int16 else { return nil }
        self.init(int16)
    }

    init?(_ int32: Int32?) {
        guard let int32 = int32 else { return nil }
        self.init(int32)
    }

    var int32: Int32 {
        Int32(self)
    }

    func itemCount(singular item: String) -> String {
        return "\(self.string) \(item.pluralising(self))"
    }
}

public extension NSSortDescriptor {
    convenience init<Root, Value>(_ keyPath: KeyPath<Root, Value>, ascending: Bool = true) {
        self.init(keyPath: keyPath, ascending: ascending)
    }

    convenience init(_ key: String, ascending: Bool = true) {
        self.init(key: key, ascending: ascending)
    }
}

public extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

public extension URL {
    func withHttps() -> URL? {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        urlComponents.scheme = "https"
        return urlComponents.url
    }

    static func temporary(fileWithName fileName: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    static func temporary() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    }

    static var documents: URL {
        return try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    static var applicationSupport: URL {
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

public extension String.SubSequence {
    func trimming() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
}

public extension FileManager {
    func removeTemporaryFiles() {
        let tmpFiles: [URL]
        do {
            tmpFiles = try FileManager.default.contentsOfDirectory(at: URL(string: NSTemporaryDirectory())!,
                                                                   includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            os_log("Error enumerating temporary directory: %{public}s", type: .error, error.localizedDescription)
            return
        }

        os_log("Deleting %d temporary files", type: .info, tmpFiles.count)
        for url in tmpFiles {
            do {
                try FileManager.default.removeItem(at: url)
                os_log("Removed temporary file %{public}s", type: .info, url.path)
            } catch {
                os_log("Unable to remove temporary file %{public}s: %{public}s", type: .error, url.path, error.localizedDescription)
            }
        }
    }
}

public extension AVCaptureVideoPreviewLayer {
    convenience init(_ session: AVCaptureSession, gravity: AVLayerVideoGravity, frame: CGRect) {
        self.init(session: session)
        self.frame = frame
        videoGravity = gravity
    }
}

public extension Array where Element: Equatable {
    func distinct() -> [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            if !uniqueValues.contains(item) {
                uniqueValues += [item]
            }
        }
        return uniqueValues
    }

    func appendingRemaining(_ array: [Element]) -> [Element] {
        return self + array.subtracting(self)
    }

    func subtracting(_ array: [Element]) -> [Element] {
        self.filter { !array.contains($0) }
    }

    func containsAll(_ items: [Element]) -> Bool {
        return items.allSatisfy { self.contains($0) }
    }
}

public extension Date {
    init?(_ dateString: String?, format: String) {
        guard let dateString = dateString else { return nil }
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = format
        dateStringFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = dateStringFormatter.date(from: dateString) else { return nil }
        self.init(timeInterval: 0, since: date)
    }

    init?(iso: String?) {
        self.init(iso, format: "yyyy-MM-dd")
    }

    func string(withDateFormat dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: self)
    }

    static func startOfToday() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }

    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }

    func date(byAdding dateComponents: DateComponents) -> Date? {
        return Calendar.current.date(byAdding: dateComponents, to: self)
    }

    func compareIgnoringTime(_ other: Date) -> ComparisonResult {
        return self.startOfDay().compare(other.startOfDay())
    }

    func toPrettyString(short: Bool = true) -> String {
        let today = Date.startOfToday()
        let otherDate = startOfDay()

        let thisYear = Calendar.current.dateComponents([.year], from: today).year!
        let otherYear = Calendar.current.dateComponents([.year], from: otherDate).year!

        let daysDifference = Calendar.current.dateComponents([.day], from: otherDate, to: today).day!

        if daysDifference == 0 {
            return "Today"
        }
        if daysDifference > 0 && daysDifference <= 3 {
            return self.string(withDateFormat: "EEE\(short ? "" : "E")")
        } else {
            // Use the format "12 Feb", or - if the date is not from this year - "12 Feb 2015"
            return self.string(withDateFormat: "d MMM\(short ? "" : "M")\(thisYear == otherYear ? "" : " yyyy")")
        }
    }
}

public extension IndexPath {
    func next() -> IndexPath {
        return IndexPath(row: row + 1, section: section)
    }

    func previous() -> IndexPath {
        return IndexPath(row: row - 1, section: section)
    }
}

public extension NSPredicate {

    convenience init(boolean: Bool) {
        switch boolean {
        case true:
            self.init(format: "TRUEPREDICATE")
        case false:
            self.init(format: "FALSEPREDICATE")
        }
    }

    convenience init(intFieldName: String, equalTo: Int) {
        self.init(format: "\(intFieldName) == %d", equalTo)
    }

    convenience init(stringFieldName: String, equalTo: String) {
        self.init(format: "\(stringFieldName) == %@", equalTo)
    }

    convenience init(fieldName: String, containsSubstring substring: String) {
        // Special case for "contains empty string": should return TRUE
        if substring.isEmpty {
            self.init(boolean: true)
        } else {
            self.init(format: "\(fieldName) CONTAINS[cd] %@", substring)
        }
    }

    func not() -> NSPredicate {
        return NSCompoundPredicate(notPredicateWithSubpredicate: self)
    }

    static func or(_ orPredicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func and(_ andPredicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }

    static func wordsWithinFields(_ searchString: String, fieldNames: String...) -> NSPredicate {
        // Split on whitespace and remove empty elements
        let searchStringComponents = searchString.components(separatedBy: CharacterSet.alphanumerics.inverted).filter {
            !$0.isEmpty
        }

        // AND each component, where each component is OR'd over each of the fields
        return NSPredicate.and(searchStringComponents.map { searchStringComponent in
            NSPredicate.or(fieldNames.map { fieldName in
                NSPredicate(fieldName: fieldName, containsSubstring: searchStringComponent)
            })
        })
    }
}

public extension NSOrderedSet {
    var isEmpty: Bool {
        return count == 0 //swiftlint:disable:this empty_count
    }
}

public extension Sequence {
    func sorted<T>(byAscending sortableProperty: KeyPath<Element, T>) -> [Self.Element] where T: Comparable {
        return sorted { $0[keyPath: sortableProperty] < $1[keyPath: sortableProperty] }
    }

    func sorted<T>(byAscending sortablePropertySelector: (Element) -> T) -> [Self.Element] where T: Comparable {
        return sorted { sortablePropertySelector($0) < sortablePropertySelector($1) }
    }

    func distinct<T>(by keyPath: KeyPath<Element, T>) -> [Element] where T: Hashable {
        var newArray = [Element]()
        var seenItentifiers = Set<T>()
        for element in self {
            let identifier = element[keyPath: keyPath]
            if seenItentifiers.insert(identifier).inserted {
                newArray.append(element)
            }
        }
        return newArray
    }
}
