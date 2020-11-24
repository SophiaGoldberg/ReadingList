import Foundation

public struct Queue<T> {
  public var items: [T] = []
    public init() {

    }

  public mutating func enqueue(_ value: T) {
    items.append(value)
  }

    public mutating func dequeue() -> T? {
    guard !items.isEmpty else {
      return nil
    }
    return items.removeFirst()
  }

    public var front: T? {
    return items.first
  }

    public var back: T? {
    return items.last
  }
}
