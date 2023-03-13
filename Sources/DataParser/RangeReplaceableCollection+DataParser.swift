//
//  RangeReplaceableCollection+DataParser.swift
//
//
//  Created by Charles Srstka on 3/12/23.
//

extension RangeReplaceableCollection where Element == UInt8 {
    public mutating func append<I: BinaryInteger>(_ someInt: I, byteOrder: ByteOrder) {
        var i = someInt

        withUnsafeBytes(of: &i) { bytes in
            if byteOrder.isHost {
                self += bytes
            } else {
                self += bytes.reversed()
            }
        }
    }

    public mutating func append<F: BinaryFloatingPoint>(_ someFloat: F, byteOrder: ByteOrder) {
        var f = someFloat

        withUnsafeBytes(of: &f) { bytes in
            if byteOrder.isHost {
                self += bytes
            } else {
                self += bytes.reversed()
            }
        }
    }

    public mutating func appendTuple<T, I: BinaryInteger>(
        _ tuple: T,
        unitType: I.Type,
        unitCount: some BinaryInteger,
        beginningAtIndex: some BinaryInteger = Int(0),
        byteOrder: ByteOrder
    ) {
        var destTuple = tuple
        let startIndex = Int(beginningAtIndex)
        let count = Int(unitCount)

        withUnsafeBytes(of: &destTuple) { bytes in
            if MemoryLayout<I>.stride == 1 {
                self += bytes[startIndex..<(startIndex + count)]
                return
            }

            bytes.withMemoryRebound(to: unitType) { ptr in
                for i in startIndex..<(count + startIndex) {
                    self.append(ptr[i], byteOrder: byteOrder)
                }
            }
        }
    }
}
