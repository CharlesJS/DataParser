//
//  DataParser.swift
//
//  Created by Charles Srstka on 11/11/15.
//

import Internal

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

    public init(pointer: UnsafeRawPointer, count: Int) where DataType == UnsafeRawBufferPointer {
        self.init(buffer: UnsafeRawBufferPointer(start: pointer, count: count))
    }

    public init(buffer: UnsafeRawBufferPointer) where DataType == UnsafeRawBufferPointer {
        self.init(buffer)
    }

    private typealias LargestSignedInteger = Int64
    private typealias LargestUnsignedInteger = UInt64

    public mutating func skipBytes(_ byteCount: Int) throws {
        self._cursor = self.data.index(self._cursor, offsetBy: byteCount)

        if self._cursor > self.data.endIndex {
            throw DataParserError.outOfBounds
        }
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

    public mutating func readInt<T: FixedWidthInteger>(size: Int, byteOrder: ByteOrder, advance: Bool = true) throws -> T {
        return try self.readInt(ofType: T.self, size: size, byteOrder: byteOrder, advance: advance)
    }

    public mutating func readInt<T: FixedWidthInteger>(
        ofType type: T.Type,
        size: Int,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> T {
        if size > MemoryLayout<T>.size { throw DataParserError.invalidArgument }

        var i: T = 0

        try withUnsafeMutableBytes(of: &i) { buf in
            if byteOrder.isHost {
                try self.copyToPointer(buf.baseAddress!, byteCount: size, advance: advance)
            } else {
                try self._readSwapped(buf, size: size, advance: advance)
            }
        }

        return i
    }

    private mutating func _readSwapped(_ buf: UnsafeMutableRawBufferPointer, size: Int, advance: Bool) throws {
        func swap(_ buf: UnsafeMutableRawBufferPointer, size: Int) throws {
            guard let dst = buf.baseAddress, size != 0 else { return }

            for i in (0..<size).reversed() {
                dst.storeBytes(of: try self.readByte(advance: true), toByteOffset: i, as: UInt8.self)
            }
        }

        if advance {
            try swap(buf, size: size)
        } else {
            let cursor = self.cursor
            defer { self.cursor = cursor }
            try swap(buf, size: size)
        }
    }

    public mutating func readFloat(byteOrder: ByteOrder, advance: Bool = true) throws -> Float {
        return try Float(bitPattern: self.readUInt32(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readDouble(byteOrder: ByteOrder, advance: Bool = true) throws -> Double {
        return try Double(bitPattern: self.readUInt64(byteOrder: byteOrder, advance: advance))
    }

    public mutating func readFloat<F: BinaryFloatingPoint>(
        ofType: F.Type,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> F {
        switch MemoryLayout<F>.size {
        case MemoryLayout<Float>.size:
            return F(try self.readFloat(byteOrder: byteOrder, advance: advance))
        case MemoryLayout<Double>.size:
            return F(try self.readDouble(byteOrder: byteOrder, advance: advance))
        default:
            throw DataParserError.invalidArgument
        }
    }

    public mutating func readLEB128<I: FixedWidthInteger>(advance: Bool = true) throws -> I {
        return try self.readLEB128(ofType: I.self,advance: advance)
    }

    public mutating func readLEB128<I: FixedWidthInteger>(ofType: I.Type, advance: Bool = true) throws -> I {
        let oldCursor = self.cursor

        var out = I()
        var shift = 0

        var byte: UInt8

        repeat {
            byte = try self.readByte(advance: true)

            out |= (I(byte & 0x7f) &<< shift)

            shift = shift &+ 7
        } while (byte & 0x80) != 0

        if I.isSigned && shift < I.bitWidth && (byte & 0x40) != 0 {
            // it's negative

            out |= (I(0) &- (I(1) &<< shift))
        }

        if !advance { self.cursor = oldCursor }

        return out
    }

    public mutating func readBytes(count: Int, advance: Bool = true) throws -> ContiguousArray<UInt8> {
        try self.readArray(count: count, ofType: UInt8.self, byteOrder: .host, advance: advance)
    }

    public mutating func readArray<Element: FixedWidthInteger>(
        count: Int,
        ofType _: Element.Type,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws -> ContiguousArray<Element> {
        let elementSize = MemoryLayout<Element>.stride
        let byteCount = count * elementSize
        let startIndex = self._cursor
        let nextIndex = self.data.index(startIndex, offsetBy: byteCount)

        if nextIndex > self.data.endIndex {
            throw DataParserError.outOfBounds
        }

        return try ContiguousArray<Element>(unsafeUninitializedCapacity: count) { outBuffer, outCount in
            defer { outCount = count }

            if byteOrder.isHost || elementSize == 1 {
                try self.copyToBuffer(UnsafeMutableRawBufferPointer(outBuffer), byteCount: byteCount, advance: advance)
            } else {
                do {
                    for i in outBuffer.indices {
                        outBuffer[i] = try self.readInt(ofType: Element.self, byteOrder: byteOrder, advance: true)
                    }
                } catch {
                    for i in outBuffer.indices {
                        outBuffer[i] = 0
                    }

                    throw error
                }

                if !advance {
                    self._cursor = startIndex
                }
            }
        }
    }

    public mutating func readBytesToEnd(advance: Bool = true) throws -> ContiguousArray<UInt8> {
        try self.readBytes(count: self.bytesLeft, advance: advance)
    }

    public mutating func readUTF8String(byteCount: Int, advance: Bool = true) throws -> String {
        if #available(macOS 11.0, *) {
            return try String(unsafeUninitializedCapacity: byteCount) {
                try self.copyToBuffer($0, count: byteCount, advance: advance)

                return byteCount
            }
        } else {
            let codeUnits = try self.readArray(count: byteCount, ofType: UInt8.self, byteOrder: .host, advance: advance)

            return String(decoding: codeUnits, as: UTF8.self)
        }
    }

    public mutating func readUTF8CString(requireNullTerminator: Bool = true, advance: Bool = true) throws -> String {
        let (length: byteCount, hasTerminator: hasTerminator) = try self.getCStringLength(
            requireNullTerminator: requireNullTerminator
        )

        let string = try self.readUTF8String(byteCount: byteCount, advance: advance)

        if advance && hasTerminator {
            try self.skipBytes(1)
        }

        return string
    }

    private mutating func readCStringBytes(
        requireNullTerminator: Bool = true,
        advance: Bool = true
    ) throws -> ContiguousArray<UInt8> {
        let (length: byteCount, hasTerminator: hasTerminator) = try self.getCStringLength(
            requireNullTerminator: requireNullTerminator
        )

        let bytes = try self.readBytes(count: byteCount, advance: advance)

        if advance && hasTerminator {
            try self.skipBytes(1)
        }

        return bytes
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

    public mutating func copyToPointer(_ destPointer: UnsafeMutableRawPointer, byteCount: Int, advance: Bool = true) throws {
        let startIndex = self._cursor
        let endIndex = self.data.index(startIndex, offsetBy: byteCount)

        if endIndex > self.data.endIndex {
            throw DataParserError.outOfBounds
        }

        if let hasContiguousRegions = self.data as? _HasContiguousRegions {
            let range = startIndex..<endIndex

            guard hasContiguousRegions.copyMemory(to: destPointer, from: self.data, range: range) else {
                throw DataParserError.outOfBounds
            }

#if DEBUG
        self.accessCounts[.pointerAccess, default: 0] += 1
#endif

            if advance {
                self._cursor = endIndex
            }
        } else if try self.data[startIndex..<endIndex].withContiguousStorageIfAvailable({
            guard let srcPointer = $0.baseAddress, $0.count >= byteCount else {
                throw DataParserError.outOfBounds
            }

            destPointer.copyMemory(from: srcPointer, byteCount: byteCount)

#if DEBUG
        self.accessCounts[.pointerAccess, default: 0] += 1
#endif

            if advance {
                self._cursor = endIndex
            }
        }) as Void? == nil {
            for i in 0..<byteCount {
                destPointer.storeBytes(of: try self.readByte(advance: true), toByteOffset: i, as: UInt8.self)
            }

            if !advance { self._cursor = startIndex }
        }
    }

    public mutating func copyToPointer<T>(_ destPointer: UnsafeMutablePointer<T>, count: Int, advance: Bool = true) throws {
        let byteCount = count &* MemoryLayout<T>.stride

        try self.copyToPointer(UnsafeMutableRawPointer(destPointer), byteCount: byteCount, advance: advance)
    }

    public mutating func copyToBuffer<T>(
        _ destBuffer: UnsafeMutableBufferPointer<T>,
        count: Int,
        advance: Bool = true
    ) throws {
        let byteCount = count &* MemoryLayout<T>.stride

        try self.copyToBuffer(UnsafeMutableRawBufferPointer(destBuffer), byteCount: byteCount, advance: advance)
    }

    public mutating func copyToBuffer(
        _ destBuffer: UnsafeMutableRawBufferPointer,
        byteCount: Int,
        advance: Bool = true
    ) throws {
        guard byteCount <= destBuffer.count, let baseAddress = destBuffer.baseAddress else {
            throw DataParserError.invalidArgument
        }

        try self.copyToPointer(baseAddress, byteCount: byteCount, advance: advance)
    }

    public mutating func copyToTuple<T, I: FixedWidthInteger>(
        _ destTuple: inout T,
        unitType: I.Type,
        unitCount: Int,
        beginningAtIndex startIndex: Int = 0,
        byteOrder: ByteOrder,
        advance: Bool = true
    ) throws {
        try withUnsafeMutablePointer(to: &destTuple) {
            try $0.withMemoryRebound(to: unitType, capacity: unitCount) {
                let stride = MemoryLayout<I>.stride

                if stride == 1 {
                    try self.copyToPointer($0 + startIndex, count: unitCount, advance: advance)
                    return
                }

                let oldCursor = self.cursor
                var ptr = $0 + startIndex

                for _ in 0..<unitCount {
                    ptr.pointee = try self.readInt(ofType: I.self, byteOrder: byteOrder, advance: true)
                    ptr += 1
                }

                if !advance { self.cursor = oldCursor }
            }
        }
    }
}
