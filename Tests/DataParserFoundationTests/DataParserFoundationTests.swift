import XCTest
import Foundation
import TestHelper
import DataParser
@testable import DataParser_Foundation

final class DataTests: XCTestCase {
    func testData() throws {
        let data = Data(TestHelper.numericTestData)

        try TestHelper.testParseNumericData(parser: DataParser(data), expectPointerAccess: true)
        try TestHelper.testParseNumericData(parser: DataParser(data as NSData), expectPointerAccess: true)
    }

    func testDispatchData() throws {
        let data = TestHelper.numericTestData.withUnsafeBytes { DispatchData(bytes: $0) }

        try TestHelper.testParseNumericData(parser: DataParser(data), expectPointerAccess: true)
    }

    func testNonContiguousDispatchData() throws {
        let cutoffs = [0x4, 0x8, 0xe, 0x18, 0x21, 0x22, 0x29, 0x2e, 0x36, 0x41, 0x50]
        var data = DispatchData.empty

        var regionStart = 0
        for eachCutoff in cutoffs + [TestHelper.numericTestData.count] {
            TestHelper.numericTestData[regionStart..<eachCutoff].withUnsafeBytes {
                data.append(DispatchData(bytes: $0))
            }

            regionStart = eachCutoff
        }

        try TestHelper.testParseNumericData(parser: DataParser(data), expectPointerAccess: true)
    }

    func testDataAccessViaPointer() throws {
        class DataMock: NSObject {
            private let data: NSData

            init(data: Data) {
                self.data = data as NSData
            }

            override func forwardingTarget(for selector: Selector!) -> Any? {
                if selector == #selector(NSData.enumerateBytes(_:)) {
                    NSLog("enumerate bytes")
                }

                return self.data
            }
        }

        let dataMock = DataMock(data: Data(TestHelper.numericTestData))

        try TestHelper.testParseNumericData(
            parser: DataParser(unsafeBitCast(dataMock, to: NSData.self)),
            expectPointerAccess: true
        )
    }
}
