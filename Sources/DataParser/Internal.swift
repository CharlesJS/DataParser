//
//  Internal.swift
//  
//
//  Created by Charles Srstka on 3/12/22.
//

#if DEBUG
// To be used during testing only!
func emulateMacOSVersion(_ vers: Int, closure: () throws -> ()) rethrows {
    defer { emulatedVersion = Int.max }
    emulatedVersion = vers

    try closure()
}

nonisolated(unsafe) private var emulatedVersion = Int.max
package func versionCheck(_ vers: Int) -> Bool { emulatedVersion >= vers }
#else
@inline(__always) func versionCheck(_: Int) -> Bool { true }
#endif

package protocol _ContiguousRegion {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
    func startIndex<C: Collection>(for collection: C) -> C.Index
    func endIndex<C: Collection>(for collection: C) -> C.Index
}

package protocol _HasContiguousRegions {
    var contiguousRegions: [_ContiguousRegion] { get }
}

extension _HasContiguousRegions {
    internal func copyMemory<C: Collection>(
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

    internal func withContiguousRegion<C: Collection, T>(
        range: Range<C.Index>,
        in collection: C,
        closure: (UnsafeRawBufferPointer) throws -> T
    ) rethrows -> T? {
        for eachRegion in self.contiguousRegions {
            let regionStart = eachRegion.startIndex(for: collection)
            let regionEnd = eachRegion.endIndex(for: collection)

            if regionStart <= range.lowerBound && regionEnd >= range.upperBound {
                let offset = collection.distance(from: regionStart, to: range.lowerBound)
                let count = collection.distance(from: range.lowerBound, to: range.upperBound)

                return try eachRegion.withUnsafeBytes {
                    try closure(UnsafeRawBufferPointer(start: $0.baseAddress! + offset, count: count))
                }
            }
        }

        return nil
    }
}
