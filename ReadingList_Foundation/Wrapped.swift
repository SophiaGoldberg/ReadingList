import Foundation

public class Wrapped<T> {
    public var wrappedValue: T

    public init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}
