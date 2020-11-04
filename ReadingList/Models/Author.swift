import Foundation
import CoreData

@objc(Author)
class Author: NSObject, NSSecureCoding {
    static var supportsSecureCoding = true

    let lastName: String
    let firstNames: String?

    init(lastName: String, firstNames: String?) {
        self.lastName = lastName
        self.firstNames = firstNames
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherAuthor = object as? Author else { return false }
        return lastName == otherAuthor.lastName &&
            firstNames == otherAuthor.firstNames
    }

    convenience init(firstNameLastName text: String) {
        if let range = text.range(of: " ", options: .backwards) {
            let firstNames = text[..<range.upperBound].trimming()
            let lastName = text[range.lowerBound...].trimming()
            self.init(lastName: lastName, firstNames: firstNames)
        } else {
            self.init(lastName: text, firstNames: nil)
        }
    }

    required convenience init?(coder aDecoder: NSCoder) {
        let lastName = aDecoder.decodeObject(of: NSString.self, forKey: "lastName")! as String
        let firstNames = aDecoder.decodeObject(of: NSString.self, forKey: "firstNames") as String?
        self.init(lastName: lastName, firstNames: firstNames)
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.lastName, forKey: "lastName")
        aCoder.encode(self.firstNames, forKey: "firstNames")
    }

    var fullName: String {
        guard let firstNames = firstNames else { return lastName }
        return "\(firstNames) \(lastName)"
    }

    var lastNameCommaFirstName: String {
        guard let firstNames = firstNames else { return lastName }
        return "\(lastName), \(firstNames)"
    }

    var lastNameSort: String {
        guard let firstNames = firstNames else { return lastName.sortable }
        return "\(lastName.sortable).\(firstNames.sortable)"
    }
}

extension Array where Element == Author {
    var lastNamesSort: String {
        return self.map { $0.lastNameSort }.joined(separator: "..")
    }

    var fullNames: String {
        return self.map { $0.fullName }.joined(separator: ", ")
    }
}
