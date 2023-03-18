import XCTest
@_spi(DataParserInternal) @testable import DataParser

public struct TestHelper {
    private static let numericTestData: [UInt8] = [
        0x12,                                                // ASCII byte
        0x34,                                                // another ASCII byte
        0x89,                                                // higher byte
        0x12, 0x34,                                          // 0x1234, big endian
        0x78, 0x9a,                                          // 0x9a78, little endian
        0x12, 0x34, 0x56, 0x78,                              // 0x12345678, big endian
        0xef, 0xcd, 0xab, 0x89,                              // 0x89abcdef, little endian
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,      // 0x0123456789abcdef, big endian
        0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe,      // 0xfedcba9876543210, little endian
        0x79, 0xbd, 0xef,                                    // 0x79bdef, big endian
        0xfd, 0xec, 0xdb, 0xca, 0xb9, 0xa8, 0x97,            // 0x97a8b9cadbecfd, little endian
        0x40, 0x49, 0x0f, 0xd0,                              // 3.14159012, big endian
        0x4d, 0xf8, 0x2d, 0x40,                              // 2.71828008, little endian
        0x40, 0x05, 0xbf, 0x0a, 0x8b, 0x14, 0x57, 0x69,      // 2.7182818284590451, big endian
        0x18, 0x2d, 0x44, 0x54, 0xfb, 0x21, 0x09, 0x40,      // 3.1415926535897931, little endian
        0x00,                                                // 0, LEB128
        0xe5, 0x8e, 0x26,                                    // 624485, LEB128
        0xc0, 0xbb, 0x78,                                    // -123456, LEB128
        0xef, 0x9b, 0xaf, 0x85, 0x89, 0xcf, 0x95, 0x9a, 0x12 // 0x1234567890abcdef, LEB128
    ]

    private static let stringTestData: [UInt8] = [
        0x46, 0x6f, 0x6f,                                                 // "Foo"
        0x57, 0x69, 0x74, 0x68, 0x20, 0xf0, 0x9f, 0x98, 0x80, 0x20, 0x65,
        0x6d, 0x6f, 0x6a, 0x69, 0x73, 0x20, 0xf0, 0x9f, 0x98, 0xb9,       // "With 😀 emojis 😹"
        0x43, 0x20, 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67, 0x00,             // "C string\0"
        0x63, 0xc5, 0xa1, 0x74, 0xc5, 0x95, 0xc3, 0xae, 0xc3,
        0xb1, 0x67, 0x20, 0xf0, 0x9f, 0xa5, 0xb0, 0x00,                   // "cštŕîñg 🥰\0"
        0x54, 0x68, 0x65, 0x20, 0x65, 0x6e, 0x64                          // "The end"
    ]

    public static func runParserTests<T>(expectPointerAccess: Bool, closure: ([UInt8]) -> DataParser<T>) throws {
        try self._runParserTests(expectPointerAccess: expectPointerAccess, closure: closure)

        try emulateMacOSVersion(10) {
            try self._runParserTests(expectPointerAccess: expectPointerAccess, closure: closure)
        }
    }

    private static func _runParserTests<T>(expectPointerAccess: Bool, closure: ([UInt8]) -> DataParser<T>) throws {
        let numericParser = closure(self.numericTestData)
        let stringParser = closure(self.stringTestData)

        try testParseNumericData(parser: numericParser, expectPointerAccess: expectPointerAccess)
        try testParseStringData(parser: stringParser, expectPointerAccess: expectPointerAccess)
        try testParseRawStructs(expectPointerAccess: expectPointerAccess, closure: closure)
        try testCursorMutation(closure: closure)
        try testOverflowErrors(closure: closure)
    }

    private static func testParseNumericData<T>(parser: DataParser<T>, expectPointerAccess: Bool) throws {
        try testParseSignedIntegers(parser: parser, expectPointerAccess: expectPointerAccess)
        try testParseUnsignedIntegers(parser: parser, expectPointerAccess: expectPointerAccess)
        try testFloatingPoint(parser: parser, expectPointerAccess: expectPointerAccess)
        try testGenericNumericTypes(parser: parser, expectPointerAccess: expectPointerAccess)
        try testReadingRawBytes(parser: parser, expectPointerAccess: expectPointerAccess)
        try testReadingIntegerArrays(parser: parser, expectPointerAccess: expectPointerAccess)
        try testPointerCopies(parser: parser, expectPointerAccess: expectPointerAccess)
        try testReadTuples(parser: parser, expectPointerAccess: expectPointerAccess)
    }

    private static func testParseStringData<T>(parser: DataParser<T>, expectPointerAccess: Bool) throws {
        try testReadingStrings(parser: parser, expectPointerAccess: expectPointerAccess)
    }

    private static func testParseRawStructs<T>(expectPointerAccess: Bool, closure: ([UInt8]) -> DataParser<T>) throws {
        var testSockaddr = sockaddr_in(
            sin_len: 0x12,
            sin_family: 0x34,
            sin_port: 0x5678,
            sin_addr: .init(s_addr: 0x9abcdef0),
            sin_zero: (1, 2, 3, 4, 5, 6, 7, 8)
        )

        var testRange: Range<UInt64> = (0x98765432..<0xfedcba98)
        var testRect = NSRect(origin: NSPoint(x: 0x1234, y: 0x5678), size: NSSize(width: 0x9abc, height: 0xdef0))

        var data: [UInt8] = []

        withUnsafeBytes(of: &testSockaddr) { data += $0 }
        withUnsafeBytes(of: &testRange) { data += $0 }
        withUnsafeBytes(of: &testRect) { data += $0 }

        var parser = closure(data)

        try self.testRawRead(parser: &parser, expect: testSockaddr)
        try self.testRawRead(parser: &parser, expect: testRange)

        let cursorBeforeThrow = parser.cursor
        XCTAssertThrowsError(try parser.withUnsafeBytes(count: MemoryLayout<NSRect>.size + 1, advance: true) { _ in }) {
            XCTAssertEqual($0 as? DataParserError, .outOfBounds)
        }
        XCTAssertEqual(parser.cursor, cursorBeforeThrow)

        try self.testRawRead(parser: &parser, expect: testRect)

        try self.checkPointerAccess(
            parser: parser,
            rawDataAccesses: 3,
            rawDataBytes: MemoryLayout<sockaddr_in>.size + MemoryLayout<Range<UInt64>>.size + MemoryLayout<NSRect>.size,
            expectPointerAccess: expectPointerAccess
        )
    }

    private static func testRawRead<S, T>(parser: inout DataParser<T>, expect: S) throws {
        var expectedValue = expect

        try withUnsafeBytes(of: &expectedValue) { expectedBuffer in
            try parser.withUnsafeBytes(count: expectedBuffer.count, advance: false) {
                XCTAssertEqual(Data($0), Data(expectedBuffer))
            }

            try parser.withUnsafeBytes(count: expectedBuffer.count, advance: true) {
                XCTAssertEqual(Data($0), Data(expectedBuffer))
            }
        }
    }

    private static func testCursorMutation<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure(self.numericTestData)
        XCTAssertEqual(try parser.readByte(), 0x12)

        parser.cursor = 10
        XCTAssertEqual(try parser.readByte(), 0x78)

        parser.cursor = 4
        XCTAssertEqual(try parser.readUInt32(byteOrder: .little), 0x129a7834)
    }

    private static func testOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        try self.testNumericOverflowErrors(closure: closure)
        try self.testByteOverflowErrors(closure: closure)
        try self.testStringOverflowErrors(closure: closure)
        try self.testIntArrayOverflowErrors(closure: closure)
        try self.testPointerCopyOverflowErrors(closure: closure)
        try self.testTupleOverflowErrors(closure: closure)
    }

    private static func testNumericOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt(ofType: Int64.self, size: 8, byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt(ofType: Int64.self, size: 8, byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readInt(ofType: UInt64.self, size: 8, byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readInt(ofType: UInt64.self, size: 8, byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt64(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt64(byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt64(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt64(byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readFloat64(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readFloat64(byteOrder: .little)
        }

        XCTAssertEqual(try parser.readUInt32(byteOrder: .big), 0x01020304)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt32(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt32(byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt32(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt32(byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readFloat32(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "read out of bounds") {
            try $0.readFloat32(byteOrder: .little)
        }

        XCTAssertEqual(try parser.readUInt16(byteOrder: .big), 0x0506)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt16(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readInt16(byteOrder: .little)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt16(byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUInt16(byteOrder: .little)
        }

        XCTAssertEqual(try parser.readByte(), 0x07)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readByte()
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readSignedByte()
        }

        try self.testLEB128OverflowErrors(closure: closure)
    }

    private static func testLEB128OverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x80, 0x81, 0x00, 0x82, 0x83])

        XCTAssertEqual(try parser.readLEB128() as Int, 128)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readLEB128() as Int
        }
    }

    private static func testByteOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readBytes(count: 8)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.skipBytes(8)
        }

        XCTAssertEqual(try parser.readBytes(count: 5), [0x00, 0x01, 0x02, 0x03, 0x04])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readBytes(count: 3)
        }

        XCTAssertEqual(try parser.readBytes(count: 2), [0x05, 0x06])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readBytes(count: 1)
        }

        XCTAssertEqual(try parser.readBytesToEnd(), [])
    }

    private static func testStringOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57, 0x6f, 0x72, 0x6c, 0x64])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readUTF8String(byteCount: 12)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.getCStringLength(requireNullTerminator: true)
        }

        XCTAssertEqual(try parser.readUTF8String(byteCount: 11, advance: false), "Hello World")
    }

    private static func testIntArrayOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readArray(count: 4, ofType: UInt16.self, byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.readArray(count: 4, ofType: UInt16.self, byteOrder: .little)
        }

        XCTAssertEqual(
            try parser.readArray(count: 3, ofType: UInt16.self, byteOrder: .big, advance: false),
            [0x0102, 0x0304, 0x0506]
        )

        XCTAssertEqual(
            try parser.readArray(count: 3, ofType: UInt16.self, byteOrder: .little, advance: true),
            [0x0201, 0x0403, 0x0605]
        )

        XCTAssertEqual(parser.cursor, 6)
    }

    private static func testPointerCopyOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        let inputBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        var parser = closure(inputBytes)

        var data = [UInt8](repeating: 0, count: 6)
        data.withUnsafeMutableBytes { bytes in
            self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
                try $0.copyToBuffer(bytes, byteCount: 6)
            }

            self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
                try $0.copyToPointer(bytes.baseAddress!, byteCount: 6)
            }

            let byteBuffer = bytes.bindMemory(to: UInt8.self)

            self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
                try $0.copyToBuffer(byteBuffer, count: 6)
            }

            self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
                try $0.copyToPointer(byteBuffer.baseAddress!, count: 6)
            }
        }

        data = [UInt8](repeating: 0, count: 5)
        try data.withUnsafeMutableBytes { bytes in
            try parser.copyToBuffer(bytes, byteCount: 5, advance: false)
        }
        XCTAssertEqual(data, inputBytes)

        data = [UInt8](repeating: 0, count: 5)
        try data.withUnsafeMutableBytes { bytes in
            try parser.copyToPointer(bytes.baseAddress!, byteCount: 5, advance: false)
        }
        XCTAssertEqual(data, inputBytes)

        data = [UInt8](repeating: 0, count: 5)
        try data.withUnsafeMutableBytes { bytes in
            try parser.copyToBuffer(bytes.bindMemory(to: UInt8.self), count: 5, advance: false)
        }
        XCTAssertEqual(data, inputBytes)

        data = [UInt8](repeating: 0, count: 5)
        try data.withUnsafeMutableBytes { bytes in
            try parser.copyToPointer(bytes.bindMemory(to: UInt8.self).baseAddress!, count: 5, advance: false)
        }
        XCTAssertEqual(data, inputBytes)
    }

    private static func testTupleOverflowErrors<T>(closure: ([UInt8]) -> DataParser<T>) throws {
        var parser = closure([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

        var tuple3: (UInt16, UInt16, UInt16) = (0, 0, 0)
        var tuple4: (UInt16, UInt16, UInt16, UInt16) = (0, 0, 0, 0)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.copyToTuple(&tuple4, unitType: UInt16.self, unitCount: 4, byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.copyToTuple(&tuple4, unitType: UInt16.self, unitCount: 4, byteOrder: .little)
        }

        try parser.copyToTuple(&tuple3, unitType: UInt16.self, unitCount: 3, byteOrder: .big, advance: false)
        XCTAssertEqual(tuple3.0, 0x0102)
        XCTAssertEqual(tuple3.1, 0x0304)
        XCTAssertEqual(tuple3.2, 0x0506)

        try parser.copyToTuple(&tuple3, unitType: UInt16.self, unitCount: 3, byteOrder: .little)
        XCTAssertEqual(tuple3.0, 0x0201)
        XCTAssertEqual(tuple3.1, 0x0403)
        XCTAssertEqual(tuple3.2, 0x0605)

        XCTAssertEqual(parser.cursor, 6)

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.copyToTuple(&tuple3, unitType: UInt16.self, unitCount: 3, byteOrder: .big)
        }

        self.testFailure(&parser, expectedError: DataParserError.outOfBounds, reason: "Read out of bounds") {
            try $0.copyToTuple(&tuple3, unitType: UInt16.self, unitCount: 3, byteOrder: .little)
        }
    }

    private static func checkPointerAccess<T>(
        parser: DataParser<T>,
        singleBytes: Int = 0,
        bigEndianAccesses: Int = 0,
        bigEndianBytes: Int = 0,
        littleEndianAccesses: Int = 0,
        littleEndianBytes: Int = 0,
        rawDataAccesses: Int = 0,
        rawDataBytes: Int = 0,
        expectPointerAccess: Bool
    ) throws {
        let expectedPointerAccesses: Int
        let expectedByteAccesses: Int

        if expectPointerAccess {
            if ByteOrder.little.isHost {
                expectedPointerAccesses = littleEndianAccesses + rawDataAccesses
                expectedByteAccesses = bigEndianBytes + singleBytes
            } else {
                expectedPointerAccesses = bigEndianAccesses + rawDataAccesses
                expectedByteAccesses = littleEndianBytes + singleBytes
            }
        } else {
            expectedPointerAccesses = 0
            expectedByteAccesses = singleBytes + bigEndianBytes + littleEndianBytes + rawDataBytes
        }

        XCTAssertEqual(parser.accessCounts[.pointerAccess] ?? 0, expectedPointerAccesses * 2)
        XCTAssertEqual(parser.accessCounts[.byteAccess] ?? 0, expectedByteAccesses * 2)
    }


    private static func testParseSignedIntegers<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: 18, byteCount: 1) { try $0.readSignedByte(advance: $1) }
        try testRead(&parser, expect: 52, byteCount: 1) { try $0.readSignedByte(advance: $1) }
        try testRead(&parser, expect: -119, byteCount: 1) { try $0.readSignedByte(advance: $1) }
        try testRead(&parser, expect: 4660, byteCount: 2) { try $0.readInt16(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: -25992, byteCount: 2) { try $0.readInt16(byteOrder: .little, advance: $1) }
        try testRead(&parser, expect: 305419896, byteCount: 4) { try $0.readInt32(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: -1985229329, byteCount: 4) { try $0.readInt32(byteOrder: .little, advance: $1) }
        try testRead(&parser, expect: 81985529216486895, byteCount: 8) { try $0.readInt64(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: -81985529216486896, byteCount: 8) { try $0.readInt64(byteOrder: .little, advance: $1) }

        try testRead(&parser, expect: 7978479, byteCount: 3) {
            try $0.readInt(ofType: Int32.self, size: 3, byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: 42688237409135869, byteCount: 7) {
            try $0.readInt(ofType: Int64.self, size: 7, byteOrder: .little, advance: $1)
        }

        try parser.skipBytes(24)

        try testRead(&parser, expect: 0, byteCount: 1) { try $0.readLEB128(ofType: Int64.self, advance: $1) }
        try testRead(&parser, expect: 624485, byteCount: 3) { try $0.readLEB128(ofType: Int64.self, advance: $1) }
        try testRead(&parser, expect: -123456, byteCount: 3) { try $0.readLEB128(ofType: Int64.self, advance: $1) }
        try testRead(&parser, expect: 0x1234567890abcdef, byteCount: 9) {
            try $0.readLEB128(ofType: Int64.self, advance: $1)
        }

        XCTAssertTrue(parser.isAtEnd)

        try self.checkPointerAccess(
            parser: parser,
            singleBytes: 19,
            bigEndianAccesses: 4,
            bigEndianBytes: 17,
            littleEndianAccesses: 4,
            littleEndianBytes: 21,
            expectPointerAccess: expectPointerAccess
        )
    }

    private static func testParseUnsignedIntegers<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: 18, byteCount: 1) { try $0.readByte(advance: $1) }
        try testRead(&parser, expect: 52, byteCount: 1) { try $0.readByte(advance: $1) }
        try testRead(&parser, expect: 137, byteCount: 1) { try $0.readByte(advance: $1) }
        try testRead(&parser, expect: 4660, byteCount: 2) { try $0.readUInt16(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: 39544, byteCount: 2) { try $0.readUInt16(byteOrder: .little, advance: $1) }
        try testRead(&parser, expect: 305419896, byteCount: 4) { try $0.readUInt32(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: 2309737967, byteCount: 4) { try $0.readUInt32(byteOrder: .little, advance: $1) }
        try testRead(&parser, expect: 81985529216486895, byteCount: 8) { try $0.readUInt64(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: 18364758544493064720, byteCount: 8) {
            try $0.readUInt64(byteOrder: .little, advance: $1)
        }

        try testRead(&parser, expect: 7978479, byteCount: 3) {
            try $0.readInt(ofType: UInt32.self, size: 3, byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: 42688237409135869, byteCount: 7) {
            try $0.readInt(ofType: UInt64.self, size: 7, byteOrder: .little, advance: $1)
        }

        try self.checkPointerAccess(
            parser: parser,
            singleBytes: 3,
            bigEndianAccesses: 4,
            bigEndianBytes: 17,
            littleEndianAccesses: 4,
            littleEndianBytes: 21,
            expectPointerAccess: expectPointerAccess
        )
    }

    private static func testFloatingPoint<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try parser.skipBytes(41)

        try testRead(&parser, expect: 3.14159012, byteCount: 4) { try $0.readFloat32(byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: 2.71828008, byteCount: 4) { try $0.readFloat32(byteOrder: .little, advance: $1) }

        try testRead(&parser, expect: 2.7182818284590451, byteCount: 8) {
            try $0.readFloat64(byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: 3.1415926535897931, byteCount: 8) {
            try $0.readFloat64(byteOrder: .little, advance: $1)
        }

        try self.checkPointerAccess(
            parser: parser,
            bigEndianAccesses: 2,
            bigEndianBytes: 12,
            littleEndianAccesses: 2,
            littleEndianBytes: 12,
            expectPointerAccess: expectPointerAccess
        )
    }

    private static func testGenericNumericTypes<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: 18, byteCount: 1) { try $0.readInt(ofType: UInt8.self, byteOrder: .big, advance: $1) }
        try testRead(&parser, expect: 52 as Int8, byteCount: 1) { try $0.readInt(size: 1, byteOrder: .little, advance: $1) }

        try testRead(&parser, expect: -119, byteCount: 1) {
            try $0.readInt(ofType: Int8.self, byteOrder: .little, advance: $1)
        }

        try testRead(&parser, expect: 4660, byteCount: 2) {
            try $0.readInt(ofType: UInt16.self, byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: -25992 as Int16, byteCount: 2) {
            try $0.readInt(size: 2, byteOrder: .little, advance: $1)
        }

        try testRead(&parser, expect: 0x12345678efcdab89, byteCount: 8) {
            try $0.readInt(ofType: UInt64.self, byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: -1167088121787636991 as Int, byteCount: 8) {
            try $0.readInt(size: 8, byteOrder: .little, advance: $1)
        }

        testFailure(
            &parser,
            expectedError: DataParserError.invalidArgument,
            reason: "Size is too big to fit in the return type"
        ) {
            _ = try $0.readInt(size: 8, byteOrder: .little) as UInt32
        }

        try parser.skipBytes(18)

        try testRead(&parser, expect: 3.14159012, byteCount: 4) {
            try $0.readFloat(ofType: Float.self, byteOrder: .big, advance: $1)
        }

        try testRead(&parser, expect: 2.71828008, byteCount: 4) {
            try $0.readFloat(ofType: Float32.self, byteOrder: .little, advance: $1)
        }

        try testRead(&parser, expect: 2.7182818284590451, byteCount: 8) {
            try $0.readFloat(ofType: Double.self, byteOrder: .big, advance: $1)
        }

        testFailure(&parser, expectedError: DataParserError.invalidArgument, reason: "Unsupported floating-point type") {
            _ = try $0.readFloat(ofType: Float80.self, byteOrder: .little)
        }
    }

    private static func testReadingRawBytes<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: ContiguousArray(Self.numericTestData[0..<12]), byteCount: 12) {
            try $0.readBytes(count: 12, advance: $1)
        }

        try testRead(&parser, expect: ContiguousArray(Self.numericTestData[12..<19]), byteCount: 7) {
            try $0.readBytes(count: 7, advance: $1)
        }

        try testRead(&parser, expect: ContiguousArray(Self.numericTestData[19..<32]), byteCount: 13) {
            try $0.readBytes(count: 13, advance: $1)
        }

        try testRead(&parser, expect: ContiguousArray(Self.numericTestData[32...]), byteCount: 49) {
            try $0.readBytesToEnd(advance: $1)
        }

        XCTAssertTrue(parser.isAtEnd)

        try self.checkPointerAccess(
            parser: parser,
            rawDataAccesses: 4,
            rawDataBytes: 81,
            expectPointerAccess: expectPointerAccess
        )
    }

    private class FailSecondTimeCollection: Collection {
        typealias Element = UInt8
        typealias Index = Int

        var readYet = false
        var startIndex: Int { 0 }
        var endIndex: Int {
            if self.readYet {
                return 0
            } else {
                self.readYet = true
                return 1000
            }
        }
        subscript(position: Int) -> UInt8 { 0 }
        func index(after i: Int) -> Int { i + 1 }
    }

    private static func testReadingIntegerArrays<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: [0x3412, 0x1289, 0x7834], byteCount: 6) {
            try $0.readArray(count: 3, ofType: UInt16.self, byteOrder: .little, advance: $1)
        }

        try testRead(&parser, expect: [0x9a12345678efcdab, 0x890123456789abcd], byteCount: 16) {
            try $0.readArray(count: 2, ofType: UInt64.self, byteOrder: .big, advance: $1)
        }

        try self.checkPointerAccess(
            parser: parser,
            bigEndianAccesses: 1,
            bigEndianBytes: 16,
            littleEndianAccesses: 1,
            littleEndianBytes: 6,
            expectPointerAccess: expectPointerAccess
        )

        // Get past the initial bounds check, then fail inside ContiguousArray's initializer
        var failSecondTime = DataParser(FailSecondTimeCollection())
        XCTAssertThrowsError(try failSecondTime.readArray(count: 5, ofType: UInt32.self, byteOrder: .little)) {
            XCTAssertEqual($0 as? DataParserError, .outOfBounds)
        }
    }

    private struct FailingDataCollection: Collection, _HasContiguousRegions {
        typealias Element = UInt8
        typealias Index = Int
        struct Region: _ContiguousRegion {
            func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { fatalError("Fail") }
            func startIndex<C>(for collection: C) -> C.Index where C : Collection { collection.startIndex }
            func endIndex<C>(for collection: C) -> C.Index where C : Collection { collection.startIndex }
        }

        var readYet = false
        var startIndex: Int { 0 }
        var endIndex: Int { 1000 }
        subscript(position: Int) -> UInt8 { 0 }
        func index(after i: Int) -> Int { i + 1 }
        let contiguousRegions: [any _ContiguousRegion] = [Region()]
    }

    private static func testPointerCopies<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        let bytePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
        defer { bytePointer.deallocate() }

        testFailure(&parser, expectedError: DataParserError.invalidArgument, reason: "Destination pointer cannot be nil") {
            try $0.copyToBuffer(UnsafeMutableBufferPointer<UInt8>(start: nil, count: 0), count: 3)
        }

        testFailure(
            &parser,
            expectedError: DataParserError.invalidArgument,
            reason: "Destination pointer must have enough space"
        ) {
            let buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 2)
            defer { buf.deallocate() }
            try $0.copyToBuffer(buf, count: 3)
        }

        try testRead(&parser, expect: [0x12, 0x34, 0x89] as [UInt8], byteCount: 3) {
            bytePointer.initialize(repeating: 0, count: 3)
            defer { bytePointer.deinitialize(count: 3) }

            try $0.copyToPointer(bytePointer, count: 3, advance: $1)
            return (0..<3).map { bytePointer[$0] }
        }

        let uint16Pointer = UnsafeMutablePointer<UInt16>.allocate(capacity: 4)
        uint16Pointer.initialize(repeating: 0, count: 4)
        defer { uint16Pointer.deallocate() }

        try testRead(&parser, expect: [0x1234, 0x789a, 0x1234, 0x5678] as [UInt16], byteCount: 8) {
            uint16Pointer.initialize(repeating: 0, count: 4)
            defer { uint16Pointer.deinitialize(count: 4) }

            try $0.copyToPointer(uint16Pointer, count: 4, advance: $1)
            return (0..<4).map { UInt16(bigEndian: uint16Pointer[$0]) }
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 1)
        defer { rawPointer.deallocate() }

        try testRead(&parser, expect: [0xef, 0xcd, 0xab, 0x89, 0x01, 0x23, 0x45, 0x67] as [UInt8], byteCount: 8) {
            rawPointer.initializeMemory(as: UInt8.self, repeating: 0, count: 8)
            try $0.copyToPointer(rawPointer, byteCount: 8, advance: $1)

            return (0..<8).map { rawPointer.load(fromByteOffset: $0, as: UInt8.self) }
        }

        let byteBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 5)
        defer { byteBuffer.deallocate() }

        try testRead(&parser, expect: [0x89, 0xab, 0xcd, 0xef, 0x10] as [UInt8], byteCount: 5) {
            byteBuffer.initialize(repeating: 0)
            try $0.copyToBuffer(byteBuffer, count: 5, advance: $1)

            return Array(byteBuffer)
        }

        let uint32Buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: 3)
        defer { uint32Buffer.deallocate() }

        try testRead(&parser, expect: [0x32547698, 0xbadcfe79, 0xbdeffdec].map { UInt32(bigEndian: $0) }, byteCount: 12) {
            uint32Buffer.initialize(repeating: 0)
            try $0.copyToBuffer(uint32Buffer, count: 3, advance: $1)

            return Array(uint32Buffer)
        }

        let rawBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 17, alignment: 1)
        defer { rawBuffer.deallocate() }

        try testRead(&parser, expect: Array(Self.numericTestData[36..<53]), byteCount: 17) {
            rawBuffer.initializeMemory(as: UInt8.self, repeating: 0)
            try $0.copyToBuffer(rawBuffer, byteCount: 17, advance: $1)

            return Array(rawBuffer)
        }

        try self.checkPointerAccess(
            parser: parser,
            rawDataAccesses: 6,
            rawDataBytes: 53,
            expectPointerAccess: expectPointerAccess
        )

        var failing = DataParser(FailingDataCollection())
        testFailure(&failing, expectedError: DataParserError.outOfBounds) { parser in
            var data = Data(count: 1000)
            try data.withUnsafeMutableBytes {
                try $0.withMemoryRebound(to: UInt8.self) {
                    try parser.copyToBuffer($0, count: 1000)
                }
            }
        }
    }

    private static func testReadTuples<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        var byteTuple: (UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0)

        try runTest(&parser, byteCount: 5) {
            byteTuple = (0, 0, 0, 0, 0)
            try $0.copyToTuple(&byteTuple, unitType: UInt8.self, unitCount: 5, byteOrder: .host, advance: $1)
        } expect: {
            byteTuple == (0x12, 0x34, 0x89, 0x12, 0x34)
        } failureMessage: {
            "Expected (0x12, 0x34, 0x89, 0x12, 0x34), got \(byteTuple)"
        }

        try runTest(&parser, byteCount: 3) {
            byteTuple = (1, 2, 3, 4, 5)
            try $0.copyToTuple(
                &byteTuple,
                unitType: UInt8.self,
                unitCount: 3,
                beginningAtIndex: 2,
                byteOrder: .host,
                advance: $1
            )
        } expect: {
            byteTuple == (0x01, 0x02, 0x78, 0x9a, 0x12)
        } failureMessage: {
            "Expected (0x01, 0x02, 0x78, 0x9a, 0x12), got \(byteTuple)"
        }

        var uint32Tuple: (UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0)

        try runTest(&parser, byteCount: 16) {
            uint32Tuple = (0, 0, 0, 0)
            try $0.copyToTuple(&uint32Tuple, unitType: UInt32.self, unitCount: 4, byteOrder: .little, advance: $1)
        } expect: {
            uint32Tuple == (0xef785634, 0x0189abcd, 0x89674523, 0x10efcdab)
        } failureMessage: {
            "Expected: (0xef785634, 0x0189abcd, 0x89674523, 0x10efcdab), got \(uint32Tuple)"
        }

        try runTest(&parser, byteCount: 12) {
            uint32Tuple = (1, 2, 3, 4)
            try $0.copyToTuple(
                &uint32Tuple,
                unitType: UInt32.self,
                unitCount: 3,
                beginningAtIndex: 1,
                byteOrder: .little,
                advance: $1
            )
        } expect: {
            uint32Tuple == (0x1, 0x98765432, 0x79fedcba, 0xecfdefbd)
        } failureMessage: {
            "Expected: (0x1, 0x98765432, 0x79fedcba, 0xecfdefbd), got \(uint32Tuple)"
        }

        try runTest(&parser, byteCount: 16) {
            uint32Tuple = (0, 0, 0, 0)
            try $0.copyToTuple(&uint32Tuple, unitType: UInt32.self, unitCount: 4, byteOrder: .big, advance: $1)
        } expect: {
            uint32Tuple == (0xdbcab9a8, 0x9740490f, 0xd04df82d, 0x404005bf)
        } failureMessage: {
            "Expected: (0xdbcab9a8, 0x9740490f, 0xd04df82d, 0x404005bf), got \(uint32Tuple)"
        }

        try runTest(&parser, byteCount: 8) {
            uint32Tuple = (1, 2, 3, 4)
            try $0.copyToTuple(
                &uint32Tuple,
                unitType: UInt32.self,
                unitCount: 2,
                beginningAtIndex: 2,
                byteOrder: .big,
                advance: $1
            )
        } expect: {
            uint32Tuple == (0x1, 0x2, 0x0a8b1457, 0x69182d44)
        } failureMessage: {
            "Expected: (0x1, 0x2, 0x0a8b1457, 0x69182d44), got \(uint32Tuple)"
        }

        try self.checkPointerAccess(
            parser: parser,
            bigEndianAccesses: 6,
            bigEndianBytes: 24,
            littleEndianAccesses: 7,
            littleEndianBytes: 28,
            rawDataAccesses: 2,
            rawDataBytes: 8,
            expectPointerAccess: expectPointerAccess
        )

    }

    private static func testReadingStrings<T>(parser p: DataParser<T>, expectPointerAccess: Bool) throws {
        var parser = p

        try testRead(&parser, expect: "Foo", byteCount: 3) {
            try $0.readUTF8String(byteCount: 3, advance: $1)
        }

        try testRead(&parser, expect: "With 😀 emojis 😹", byteCount: 21) {
            try $0.readUTF8String(byteCount: 21, advance: $1)
        }

        try testRead(&parser, expect: "C string", byteCount: 9) {
            try $0.readUTF8CString(requireNullTerminator: true, advance: $1)
        }

        try testRead(&parser, expect: "cštŕîñg 🥰", byteCount: 17) {
            try $0.readUTF8CString(requireNullTerminator: false, advance: $1)
        }

        XCTAssertThrowsError(try parser.readUTF8CString(requireNullTerminator: true, advance: true)) {
            guard let error = $0 as? DataParserError else {
                XCTFail("Error is not DataParserError")
                return
            }

            XCTAssert(error == DataParserError.outOfBounds)
        }

        try testRead(&parser, expect: "The end", byteCount: 7) {
            try $0.readUTF8CString(requireNullTerminator: false, advance: $1)
        }

        try checkPointerAccess(
            parser: parser,
            rawDataAccesses: 5,
            rawDataBytes: 55,
            expectPointerAccess: expectPointerAccess
        )
    }

    public static func testRead<T: Equatable, DataType>(
        _ parser: inout DataParser<DataType>,
        expect expectedValue: T,
        byteCount: Int,
        file: StaticString = #file,
        line: UInt = #line,
        closure: (_ parser: inout DataParser<DataType>, _ advance: Bool) throws -> T
    ) throws where DataType.Element == UInt8 {
        try runTest(&parser, byteCount: byteCount, file: file, line: line) {
            try closure(&$0, $1)
        } expect: {
            $0 == expectedValue
        } failureMessage: {
            "Parsing \(T.self) failed; expected \(expectedValue), got \($0)"
        }
    }

    public static func testFailure<DataType, ErrorType: Error & Equatable, ReturnType>(
        _ parser: inout DataParser<DataType>,
        expectedError: ErrorType,
        reason: String = "",
        file: StaticString = #file,
        line: UInt = #line,
        closure: (inout DataParser<DataType>) throws -> ReturnType
    ) {
        let cursor = parser.cursor
        let bytesLeft = parser.bytesLeft

        XCTAssertThrowsError(_ = try closure(&parser), reason, file: file, line: line) {
            XCTAssertEqual($0 as? ErrorType, expectedError)
        }

        XCTAssertEqual(
            parser.cursor,
            cursor,
            "Cursor should not change if an error is thrown during reading",
            file: file,
            line: line
        )

        XCTAssertEqual(
            parser.bytesLeft,
            bytesLeft,
            "Bytes left should not change if an error is thrown during reading",
            file: file,
            line: line
        )
    }

    private static func runTest<DataType, T>(
        _ parser: inout DataParser<DataType>,
        byteCount: Int,
        file: StaticString = #file,
        line: UInt = #line,
        run: (_ parser: inout DataParser<DataType>, _ advance: Bool) throws -> T,
        expect: (T) throws -> Bool,
        failureMessage: (T) -> String = { _ in "Assertion failed" }
    ) throws {
        let cursor = parser.cursor
        let bytesLeft = parser.bytesLeft

        let nonAdvanceValue = try run(&parser, false)
        XCTAssert(try expect(nonAdvanceValue), failureMessage(nonAdvanceValue), file: file, line: line)

        XCTAssert(
            parser.cursor == cursor,
            "Cursor changed from \(cursor) to \(parser.cursor) despite advance == false",
            file: file,
            line: line
        )

        XCTAssert(
            parser.bytesLeft == bytesLeft,
            "Bytes left changed from \(bytesLeft) to \(parser.bytesLeft) despite advance == false",
            file: file,
            line: line
        )

        let advanceValue = try run(&parser, true)
        XCTAssert(try expect(advanceValue), failureMessage(advanceValue), file: file, line: line)

        XCTAssert(
            parser.cursor == cursor + byteCount,
            "Cursor is \(parser.cursor); expected \(cursor + byteCount)",
            file: file,
            line: line
        )

        XCTAssert(
            parser.bytesLeft == bytesLeft - byteCount,
            "Bytes left is \(parser.bytesLeft); expected \(bytesLeft - byteCount)",
            file: file,
            line: line
        )
    }
}
