//
//  HasContiguousRegions.swift
//  
//
//  Created by Charles Srstka on 3/12/22.
//

public protocol _ContiguousRegion {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
    func startIndex<C: Collection>(for collection: C) -> C.Index
    func endIndex<C: Collection>(for collection: C) -> C.Index
}

public protocol _HasContiguousRegions {
    var contiguousRegions: [_ContiguousRegion] { get }
}

extension _HasContiguousRegions {
    public func copyMemory<C: Collection>(
        to pointer: UnsafeMutableRawPointer,
        from collection: C,
        range: Range<C.Index>
    ) -> Bool {
        var offset = range.lowerBound
        var bytesLeft = collection.distance(from: offset, to: range.upperBound)
        var destPointer = pointer

        for eachRegion in self.contiguousRegions {
            let regionStart = eachRegion.startIndex(for: collection)
            let regionEnd = eachRegion.endIndex(for: collection)

            guard regionEnd > offset else { continue }
            guard regionStart < range.upperBound else { break }

            eachRegion.withUnsafeBytes {
                if let srcPointer = $0.baseAddress {
                    let srcOffset = collection.distance(from: regionStart, to: offset)
                    let bytesToCopy = Swift.min(bytesLeft, $0.count - srcOffset)

                    destPointer.copyMemory(from: srcPointer + srcOffset, byteCount: bytesToCopy)

                    destPointer += bytesToCopy
                    offset = collection.index(offset, offsetBy: bytesToCopy)
                    bytesLeft -= bytesToCopy
                }
            }
        }

        return (bytesLeft == 0)
    }
}
