import XCTest
import TestHelper
@testable import DataParser

final class DataParserTests: XCTestCase {
    func testByteOrders() {
        XCTAssertTrue(ByteOrder.big.isBig)
        XCTAssertFalse(ByteOrder.big.isLittle)

        XCTAssertFalse(ByteOrder.little.isBig)
        XCTAssertTrue(ByteOrder.little.isLittle)

        if UInt16(littleEndian: 0x1234) == 0x1234 {
            XCTAssertFalse(ByteOrder.host.isBig)
            XCTAssertTrue(ByteOrder.host.isLittle)
        } else {
            XCTAssertTrue(ByteOrder.host.isBig)
            XCTAssertFalse(ByteOrder.host.isLittle)
        }
    }

    func testParseByteArrays() throws {
        try TestHelper.runParserTests(expectPointerAccess: true) { DataParser($0) }
        try TestHelper.runParserTests(expectPointerAccess: true) { DataParser(ContiguousArray($0)) }
    }

    func testPointers() throws {
        var cleanup: [() -> Void] = []
        defer { cleanup.forEach { $0() } }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 1)
            cleanup.append { ptr.deallocate() }

            bytes.withUnsafeBytes { ptr.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }

            return DataParser(pointer: ptr, count: bytes.count)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 1)
            cleanup.append { ptr.deallocate() }

            bytes.withUnsafeBytes { ptr.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }

            return DataParser(pointer: UnsafeRawPointer(ptr), count: bytes.count)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
            cleanup.append { ptr.deallocate() }

            bytes.withUnsafeBytes {
                $0.withMemoryRebound(to: UInt8.self) { ptr.assign(from: $0.baseAddress!, count: $0.count) }
            }

            return DataParser(pointer: ptr, count: bytes.count)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
            cleanup.append { ptr.deallocate() }

            bytes.withUnsafeBytes {
                $0.withMemoryRebound(to: UInt8.self) { ptr.assign(from: $0.baseAddress!, count: $0.count) }
            }

            return DataParser(pointer: UnsafePointer(ptr), count: bytes.count)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: bytes.count, alignment: 1)
            cleanup.append { buf.deallocate() }

            _ = buf.initializeMemory(as: UInt8.self, from: bytes)

            return DataParser(buf)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: bytes.count, alignment: 1)
            cleanup.append { buf.deallocate() }

            _ = buf.initializeMemory(as: UInt8.self, from: bytes)

            return DataParser(UnsafeRawBufferPointer(buf))
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bytes.count)
            cleanup.append { buf.deallocate() }

            _ = buf.initialize(from: bytes)

            return DataParser(buf)
        }

        try TestHelper.runParserTests(expectPointerAccess: true) { bytes in
            let buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bytes.count)
            cleanup.append { buf.deallocate() }

            _ = buf.initialize(from: bytes)

            return DataParser(UnsafeBufferPointer(buf))
        }
    }

    func testGenericCollections() throws {
        try TestHelper.runParserTests(expectPointerAccess: false) { DataParser(AnyCollection($0)) }
    }
}
