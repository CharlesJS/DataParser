//
//  DataParser.swift
//
//  Created by Charles Srstka on 11/11/15.
//

#if Foundation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#endif

public struct DataParser<DataType: Collection> where DataType.Element == UInt8 {
    private let data: DataType
    private var _cursor: DataType.Index

    public var cursor: Int {
        get { self.data.distance(from: self.data.startIndex, to: self._cursor) }
        set { self._cursor = self.data.index(self.data.startIndex, offsetBy: newValue) }
    }

    public var bytesLeft: Int { self.data.distance(from: self._cursor, to: self.data.endIndex) }
    public var isAtEnd: Bool { return self.bytesLeft == 0 }

#if DEBUG
    internal enum TrackableAccess {
        case pointerAccess
        case byteAccess
    }

    internal var accessCounts: [TrackableAccess : Int] = [:]
#endif

    public init(_ data: DataType) {
        self.data = data
        self._cursor = data.startIndex
    }

    public init(pointer: UnsafeRawPointer, count: some BinaryInteger) where DataType == UnsafeRawBufferPointer {
        self.init(buffer: UnsafeRawBufferPointer(start: pointer, count: Int(count)))
    }

    public init(buffer: UnsafeRawBufferPointer) where DataType == UnsafeRawBufferPointer {
        self.init(buffer)
    }

    private typealias LargestSignedInteger = Int64
    private typealias LargestUnsignedInteger = UInt64

    public mutating func skipBytes(_ byteCount: some BinaryInteger) throws {
        if self.data.distance(from: self._cursor, to: self.data.endIndex) < byteCount {
            throw DataParserError.outOfBounds
        }

        self._cursor = self.data.index(self._cursor, offsetBy: Int(byteCount))
    }

    public mutating func readByte(advance: Bool = true) throws -> UInt8 {
        if self._cursor >= self.data.endIndex { throw DataParserError.outOfBounds }

        let byte = self.data[self._cursor]

        if advance {
            self._cursor = self.data.index(after: self._cursor)
        }

#if DEBUG
        self.accessCounts[.byteAccess, default: 0] += 1
#endif

        return byte
    }

    public mutating func readSignedByte(advance: Bool = true) throws -> Int8 {
        return try Int8(bitPattern: self.readByte(advance: advance))
    }

    public mutating func readUInt16(byteOrder: ByteOrder, advance: Bool = true) throws -> UInt16 {
        var i: UInt16 = 0

        try withUnsafeMutableBytes(of: &i) {
            if byteOrder.isHost {
                try self.copyToPointer($0.baseAddress!, byteCount: MemoryLayout<UInt16>.size, advance: advance)
            } else {
                try self._readSwapped($0, size: MemoryLayout<UInt16>.size, advance: advance)
            }
        }

        return i
    }

    public mutating func readInt16(byteOrder: ByteOrder, advance: Bool = true) throws -> Int16 {
        return try Int16(bitPattern: self.readUInt16(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readUInt32(byteOrder: ByteOrder, advance: Bool = true) throws -> UInt32 {
        var i: UInt32 = 0

        try withUnsafeMutableBytes(of: &i) {
            if byteOrder.isHost {
                try self.copyToPointer($0.baseAddress!, byteCount: MemoryLayout<UInt32>.size, advance: advance)
            } else {
                try self._readSwapped($0, size: MemoryLayout<UInt32>.size, advance: advance)
            }
        }

        return i
    }

    public mutating func readInt32(byteOrder: ByteOrder, advance: Bool = true) throws -> Int32 {
        return try Int32(bitPattern: self.readUInt32(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readUInt64(byteOrder: ByteOrder, advance: Bool = true) throws -> UInt64 {
        var i: UInt64 = 0

        try withUnsafeMutableBytes(of: &i) {
            if byteOrder.isHost {
                try self.copyToPointer($0.baseAddress!, byteCount: MemoryLayout<UInt64>.size, advance: advance)
            } else {
                try self._readSwapped($0, size: MemoryLayout<UInt64>.size, advance: advance)
            }
        }

        return i
    }

    public mutating func readInt64(byteOrder: ByteOrder, advance: Bool = true) throws -> Int64 {
        return try Int64(bitPattern: self.readUInt64(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readInt<T: FixedWidthInteger>(
        ofType type: T.Type,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> T {
        return try self.readInt(ofType: type, size: MemoryLayout<T>.size, byteOrder: byteOrder, advance: advance)
    }

    public mutating func readInt<T: FixedWidthInteger>(
        size: some BinaryInteger,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> T {
        return try self.readInt(ofType: T.self, size: size, byteOrder: byteOrder, advance: advance)
    }

    public mutating func readInt<T: FixedWidthInteger>(
        ofType type: T.Type,
        size: some BinaryInteger,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> T {
        guard size <= MemoryLayout<T>.size else { throw DataParserError.invalidArgument }

        var i: T = 0

        try withUnsafeMutableBytes(of: &i) { buf in
            if byteOrder.isHost {
                try self.copyToPointer(buf.baseAddress!, byteCount: size, advance: advance)
            } else {
                try self._readSwapped(buf, size: Int(size), advance: advance)
            }
        }

        return i
    }

    private mutating func _readSwapped(_ buf: UnsafeMutableRawBufferPointer, size: Int, advance: Bool) throws {
        try self._makeAtomic(advance: advance) { try $0._swap(buf, size: size) }
    }

    private mutating func _swap(_ buf: UnsafeMutableRawBufferPointer, size: Int) throws {
        assert(buf.baseAddress != nil && size != 0)

        for i in (0..<size).reversed() {
            buf.baseAddress!.storeBytes(of: try self.readByte(advance: true), toByteOffset: i, as: UInt8.self)
        }
    }

    public mutating func readFloat32(byteOrder: ByteOrder, advance: Bool = true) throws -> Float32 {
        return try Float32(bitPattern: self.readUInt32(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readFloat64(byteOrder: ByteOrder, advance: Bool = true) throws -> Float64 {
        return try Float64(bitPattern: self.readUInt64(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readFloat<F: BinaryFloatingPoint>(
        ofType: F.Type,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> F {
        switch MemoryLayout<F>.size {
        case MemoryLayout<Float32>.size:
            return F(try self.readFloat32(byteOrder: byteOrder, advance: advance))
        case MemoryLayout<Float64>.size:
            return F(try self.readFloat64(byteOrder: byteOrder, advance: advance))
        default:
            throw DataParserError.invalidArgument
        }
    }

    public mutating func readLEB128<I: FixedWidthInteger>(advance: Bool = true) throws -> I {
        return try self.readLEB128(ofType: I.self,advance: advance)
    }

    public mutating func readLEB128<I: FixedWidthInteger>(ofType: I.Type, advance: Bool = true) throws -> I {
        try self._makeAtomic(advance: advance) { parser in
            var out = I()
            var shift = 0

            var byte: UInt8

            repeat {
                byte = try parser.readByte(advance: true)

                out |= (I(byte & 0x7f) &<< shift)

                shift = shift &+ 7
            } while (byte & 0x80) != 0

            if I.isSigned && shift < I.bitWidth && (byte & 0x40) != 0 {
                // it's negative

                out |= (I(0) &- (I(1) &<< shift))
            }

            return out
        }
    }

    public mutating func readBytes(count: some BinaryInteger, advance: Bool = true) throws -> ContiguousArray<UInt8> {
        try self.readArray(count: count, ofType: UInt8.self, byteOrder: .host, advance: advance)
    }

    public mutating func readArray<Element: FixedWidthInteger>(
        count: some BinaryInteger,
        ofType _: Element.Type,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> ContiguousArray<Element> {
        let count = Int(count)
        let elementSize = MemoryLayout<Element>.stride
        let byteCount = count * elementSize
        let startIndex = self._cursor

        if self.data.distance(from: startIndex, to: self.data.endIndex) < byteCount {
            throw DataParserError.outOfBounds
        }

        return try ContiguousArray<Element>(unsafeUninitializedCapacity: count) { outBuffer, outCount in
            defer { outCount = count }

            do {
                if byteOrder.isHost || elementSize == 1 {
                    try self.copyToBuffer(UnsafeMutableRawBufferPointer(outBuffer), byteCount: byteCount, advance: advance)
                } else {
                    try self._makeAtomic(advance: advance) { parser in
                        for i in outBuffer.indices {
                            outBuffer[i] = try parser.readInt(ofType: Element.self, byteOrder: byteOrder, advance: true)
                        }
                    }
                }
            } catch {
                // Per ContiguousArray's API contract, make sure all memory is initialized even in case of an error.
                for i in outBuffer.indices {
                    outBuffer[i] = 0
                }

                throw error
            }
        }
    }

    public mutating func withUnsafeBytes<T>(
        count: Int,
        advance: Bool = true,
        closure: (UnsafeRawBufferPointer) -> T
    ) throws -> T {
        let startIndex = self._cursor

        guard self.data.distance(from: startIndex, to: self.data.endIndex) >= count else {
            throw DataParserError.outOfBounds
        }

        let endIndex = self.data.index(startIndex, offsetBy: count)
        let range = startIndex..<endIndex

#if Foundation
        if let data = self.data as? any DataProtocol,
           let returnValue = withUnsafeRegion(in: data, range: range, { closure($0) }) {
#if DEBUG
            self.accessCounts[.pointerAccess, default: 0] += 1
#endif
            
            if advance { try self.skipBytes(count) }

            return returnValue
        }
#endif

        if let returnValue = self.data.withContiguousStorageIfAvailable({
            let ptr = $0.baseAddress!.advanced(by: self.data.distance(from: self.data.startIndex, to: startIndex))
            let buf = UnsafeRawBufferPointer(start: ptr, count: count)

            return closure(buf)
        }) {
#if DEBUG
            self.accessCounts[.pointerAccess, default: 0] += 1
#endif

            if advance { try self.skipBytes(count) }

            return returnValue
        }

        return try self.readBytes(count: count, advance: advance).withUnsafeBytes(closure)
    }

    public mutating func readBytesToEnd(advance: Bool = true) throws -> ContiguousArray<UInt8> {
        try self.readBytes(count: self.bytesLeft, advance: advance)
    }

    public mutating func readUTF8String(byteCount: some BinaryInteger, advance: Bool = true) throws -> String {
        guard #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, macCatalyst 14.0, *), versionCheck(11) else {
            let codeUnits = try self.readArray(count: byteCount, ofType: UInt8.self, byteOrder: .host, advance: advance)

            return String(decoding: codeUnits, as: UTF8.self)
        }

        let byteCount = Int(byteCount)

        return try String(unsafeUninitializedCapacity: byteCount) {
            try self.copyToBuffer($0, count: byteCount, advance: advance)

            return byteCount
        }
    }

    public mutating func readUTF8CString(requireNullTerminator: Bool = true, advance: Bool = true) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let (length: byteCount, hasTerminator: hasTerminator) = try parser.getCStringLength(
                requireNullTerminator: requireNullTerminator
            )

            let string = try parser.readUTF8String(byteCount: byteCount, advance: advance)

            if advance && hasTerminator {
                try parser.skipBytes(1)
            }

            return string
        }
    }

    public mutating func readUTF8CString(
        byteCount: some BinaryInteger,
        requireNullTerminator: Bool = true,
        advance: Bool = true
    ) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let bytes = try parser.readBytes(count: byteCount, advance: advance)
            let terminatorIndex = bytes.firstIndex(of: 0)

            if requireNullTerminator && terminatorIndex == nil {
                throw DataParserError.outOfBounds
            }

            return String(decoding: bytes[..<(terminatorIndex ?? bytes.endIndex)], as: UTF8.self)
        }
    }
    
    public func getCStringLength(requireNullTerminator: Bool = true) throws -> (length: Int, hasTerminator: Bool) {
        let nullIndex: DataType.Index?
        if let index = self.data[self._cursor...].firstIndex(where: { $0 == 0 }) {
            nullIndex = index
        } else if requireNullTerminator {
            throw DataParserError.outOfBounds
        } else {
            nullIndex = nil
        }

        let length = self.data.distance(from: self._cursor, to: nullIndex ?? self.data.endIndex)
        let hasTerminator = nullIndex != nil

        return (length: length, hasTerminator: hasTerminator)
    }

    public mutating func copyToPointer(
        _ destPointer: UnsafeMutableRawPointer,
        byteCount: some BinaryInteger,
        advance: Bool = true
    ) throws {
        let byteCount = Int(byteCount)
        let startIndex = self._cursor

        guard self.data.distance(from: startIndex, to: self.data.endIndex) >= byteCount else {
            throw DataParserError.outOfBounds
        }

        let endIndex = self.data.index(startIndex, offsetBy: byteCount)

#if Foundation
        if let data = self.data as? any DataProtocol, copyMemory(to: destPointer, from: data, range: startIndex..<endIndex) {
#if DEBUG
            self.accessCounts[.pointerAccess, default: 0] += 1
#endif

            if advance { self._cursor = endIndex }

            return
        }
#endif

        if self.data[startIndex..<endIndex].withContiguousStorageIfAvailable({ buf in
            assert(buf.count >= byteCount)

            destPointer.copyMemory(from: buf.baseAddress!, byteCount: byteCount)

#if DEBUG
            self.accessCounts[.pointerAccess, default: 0] += 1
#endif

            if advance {
                self._cursor = endIndex
            }
        }) as Void? == nil {
            try _makeAtomic(advance: advance) { parser in
                for i in 0..<byteCount {
                    destPointer.storeBytes(of: try parser.readByte(advance: true), toByteOffset: i, as: UInt8.self)
                }
            }
        }
    }

    public mutating func copyToPointer<T>(
        _ destPointer: UnsafeMutablePointer<T>,
        count: some BinaryInteger,
        advance: Bool = true
    ) throws {
        let byteCount = Int(count) &* MemoryLayout<T>.stride

        try self.copyToPointer(UnsafeMutableRawPointer(destPointer), byteCount: byteCount, advance: advance)
    }

    public mutating func copyToBuffer<T>(
        _ destBuffer: UnsafeMutableBufferPointer<T>,
        count: some BinaryInteger,
        advance: Bool = true
    ) throws {
        let byteCount = Int(count) &* MemoryLayout<T>.stride

        try self.copyToBuffer(UnsafeMutableRawBufferPointer(destBuffer), byteCount: byteCount, advance: advance)
    }

    public mutating func copyToBuffer(
        _ destBuffer: UnsafeMutableRawBufferPointer,
        byteCount: some BinaryInteger,
        advance: Bool = true
    ) throws {
        let byteCount = Int(byteCount)

        guard byteCount <= destBuffer.count, let baseAddress = destBuffer.baseAddress else {
            throw DataParserError.invalidArgument
        }

        try self.copyToPointer(baseAddress, byteCount: byteCount, advance: advance)
    }

    public mutating func copyToTuple<T, I: FixedWidthInteger>(
        _ destTuple: inout T,
        unitType: I.Type,
        unitCount: some BinaryInteger,
        beginningAtIndex: some BinaryInteger = Int(0),
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws {
        let unitCount = Int(unitCount)
        let startIndex = Int(beginningAtIndex)

        try self._makeAtomic(advance: advance) { parser in
            try withUnsafeMutablePointer(to: &destTuple) {
                try $0.withMemoryRebound(to: unitType, capacity: unitCount + startIndex) {
                    let stride = MemoryLayout<I>.stride

                    if stride == 1 {
                        try parser.copyToPointer($0 + startIndex, count: unitCount, advance: advance)
                        return
                    }

                    var ptr = $0 + startIndex

                    for _ in 0..<unitCount {
                        ptr.pointee = try parser.readInt(ofType: I.self, byteOrder: byteOrder, advance: true)
                        ptr += 1
                    }
                }
            }
        }
    }

    package mutating func _makeAtomic<T>(
        advance: Bool,
        closure: (inout DataParser<DataType>) throws -> T
    ) rethrows -> T {
        let startingCursor = self._cursor
        let ret: T

        do {
            ret = try closure(&self)

            if !advance {
                self._cursor = startingCursor
            }
        } catch {
            self._cursor = startingCursor
            throw error
        }

        return ret
    }
}
