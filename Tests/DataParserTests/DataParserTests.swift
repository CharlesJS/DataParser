import XCTest
import TestHelper
@testable import DataParser

final class DataParserTests: XCTestCase {
    func testParseByteArrays() throws {
        try TestHelper.runParserTests(expectPointerAccess: true) { $0 }
        try TestHelper.runParserTests(expectPointerAccess: true) { ContiguousArray($0) }
    }

    func testGenericCollections() throws {
        try TestHelper.runParserTests(expectPointerAccess: false) { AnyCollection($0) }
    }
}
