import XCTest
import TestHelper
@testable import DataParser

final class DataParserTests: XCTestCase {
    func testParseByteArrays() throws {
        try TestHelper.testParseNumericData(parser: DataParser(TestHelper.numericTestData), expectPointerAccess: true)
        try TestHelper.testParseStringData(parser: DataParser(TestHelper.stringTestData), expectPointerAccess: true)

        try TestHelper.testParseNumericData(
            parser: DataParser(ContiguousArray(TestHelper.numericTestData)),
            expectPointerAccess: true
        )

        try TestHelper.testParseStringData(
            parser: DataParser(ContiguousArray(TestHelper.stringTestData)),
            expectPointerAccess: true
        )
    }

    func testGenericCollections() throws {
        try TestHelper.testParseNumericData(
            parser: DataParser(AnyCollection(TestHelper.numericTestData)),
            expectPointerAccess: false
        )

        try TestHelper.testParseStringData(
            parser: DataParser(AnyCollection(TestHelper.stringTestData)),
            expectPointerAccess: false
        )
    }
}
