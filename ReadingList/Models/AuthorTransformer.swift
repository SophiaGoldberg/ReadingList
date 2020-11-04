import Foundation

/// Exists to allow CoreData entity to have an transformable attribute of type [Author].
@objc(AuthorTransformer)
final class AuthorTransformer: NSSecureUnarchiveFromDataTransformer {

    static let name = NSValueTransformerName(rawValue: String(describing: AuthorTransformer.self))

    override static var allowedTopLevelClasses: [AnyClass] {
        return [Author.self, NSArray.self]
    }

    static func register() {
        let transformer = AuthorTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}
