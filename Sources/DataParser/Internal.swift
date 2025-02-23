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

#if Foundation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

internal func copyMemory<D: DataProtocol>(
    to pointer: UnsafeMutableRawPointer,
    from data: D,
    range _range: Range<some Comparable>
) -> Bool {
    let range = _range as! Range<D.Index>
    var offset = range.lowerBound
    var bytesLeft = data.distance(from: offset, to: range.upperBound)
    var destPointer = pointer

    var regionLowerBound = data.startIndex

    for eachRegion in data.regions {
        let regionUpperBound = data.index(regionLowerBound, offsetBy: eachRegion.count)
        defer { regionLowerBound = regionUpperBound }

        if regionUpperBound <= offset { continue }
        if regionLowerBound >= range.upperBound { break }

        eachRegion.withUnsafeBytes {
            if let srcPointer = $0.baseAddress {
                let srcOffset = data.distance(from: regionLowerBound, to: offset)
                let bytesToCopy = Swift.min(bytesLeft, $0.count - srcOffset)

                destPointer.copyMemory(from: srcPointer + srcOffset, byteCount: bytesToCopy)

                destPointer += bytesToCopy
                offset = data.index(offset, offsetBy: bytesToCopy)
                bytesLeft -= bytesToCopy
            }
        }
    }

    return (bytesLeft == 0)
}

internal func withUnsafeRegion<D: DataProtocol, T>(
    in data: D,
    range _range: Range<some Comparable>,
    _ closure: (UnsafeRawBufferPointer) throws -> T
) rethrows -> T? {
    let range = _range as! Range<D.Index>
    var regionLowerBound = data.startIndex

    for eachRegion in data.regions {
        let regionUpperBound = data.index(regionLowerBound, offsetBy: eachRegion.count)
        defer { regionLowerBound = regionUpperBound }

        if range.lowerBound >= regionLowerBound {
            if range.upperBound <= regionUpperBound {
                let offset = data.distance(from: regionLowerBound, to: range.lowerBound)
                let count = data.distance(from: range.lowerBound, to: range.upperBound)

                return try eachRegion.withUnsafeBytes {
                    try closure(UnsafeRawBufferPointer(start: $0.baseAddress! + offset, count: count))
                }
            } else {
                break
            }
        }
    }

    return nil
}

#endif
