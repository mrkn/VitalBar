public struct HistoryBuffer<Element>: Sendable where Element: Sendable {
    public let capacity: Int

    private var storage: [Element?]
    private var nextWriteIndex = 0
    public private(set) var count = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "HistoryBuffer capacity must be greater than zero")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public mutating func append(_ element: Element) {
        storage[nextWriteIndex] = element
        nextWriteIndex = (nextWriteIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    public var latest: Element? {
        guard count > 0 else {
            return nil
        }

        let index = (nextWriteIndex - 1 + capacity) % capacity
        return storage[index]
    }

    public var elements: [Element] {
        guard count > 0 else {
            return []
        }

        if count < capacity {
            return storage[0..<count].compactMap { $0 }
        }

        var ordered: [Element] = []
        ordered.reserveCapacity(capacity)

        for offset in 0..<capacity {
            let index = (nextWriteIndex + offset) % capacity
            if let value = storage[index] {
                ordered.append(value)
            }
        }

        return ordered
    }
}
