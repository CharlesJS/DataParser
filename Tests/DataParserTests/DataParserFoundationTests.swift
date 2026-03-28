import Testing
@testable import DataParser

#if Foundation
#if canImport(FoundationEssentials)
import Dispatch
import FoundationEssentials

extension CocoaError: @retroactive Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.code == rhs.code }
}
#else
import Foundation
#endif

#if canImport(Glibc)
import Glibc
#endif

@Suite struct DataTests {
    @Test func testData() throws {
        try TestHelper.runParserTests(expectPointerAccess: true) { DataParser(Data($0)) }
#if canImport(Darwin)
        try TestHelper.runParserTests(expectPointerAccess: true) { DataParser(Data($0) as NSData) }
#endif
    }
    
    @Test func testDispatchData() throws {
        try TestHelper.runParserTests(expectPointerAccess: true) {
            $0.withUnsafeBytes { DataParser(DispatchData(bytes: $0)) }
        }
        
#if canImport(Darwin)
        try TestHelper.runParserTests(expectPointerAccess: true) {
            $0.withUnsafeBytes { DataParser((DispatchData(bytes: $0) as AnyObject) as! NSData) }
        }
#endif
    }
    
    @Test func testNonContiguousDispatchData() throws {
        let dataMaker = { (bytes: UnsafeRawBufferPointer) -> DispatchData in
            let cutoffs = [0x4, 0x8, 0xe, 0x18, 0x21, 0x22, 0x29, 0x2e, 0x36, 0x41, 0x50].filter { $0 < bytes.count }
            var data = DispatchData.empty
            
            var regionStart = 0
            for eachCutoff in cutoffs + [bytes.count] {
                bytes[regionStart..<eachCutoff].withUnsafeBytes {
                    data.append(DispatchData(bytes: $0))
                }
                
                regionStart = eachCutoff
            }
            
            return data
        }
        
        try TestHelper.runParserTests(expectPointerAccess: true) {
            $0.withUnsafeBytes { DataParser(dataMaker($0)) }
        }
        
        // uncomment once https://github.com/swiftlang/swift/issues/79556 is resolved
        //        try TestHelper.runParserTests(expectPointerAccess: true) {
        //            $0.withUnsafeBytes { DataParser((dataMaker($0) as AnyObject) as! NSData) }
        //        }
    }
    
    @Test func testReadingData() throws {
        var parser = DataParser([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a])
        
        TestHelper.testFailure(&parser, expectedError: DataParserError.outOfBounds) {
            try $0.readData(count: 12, advance: $1)
        }
        
        try TestHelper.testRead(&parser, expect: Data([0x00, 0x01, 0x02]), byteCount: 3) { parser, advance in
            try parser.readData(count: 3, advance: advance)
        }
        
        try TestHelper.testRead(&parser, expect: Data([0x03, 0x04, 0x05, 0x06, 0x07]), byteCount: 5) { parser, advance in
            try parser.readData(count: 5, advance: advance)
        }
        
        try TestHelper.testRead(&parser, expect: Data([0x08, 0x09, 0x0a]), byteCount: 3) { parser, advance in
            try parser.readDataToEnd(advance: advance)
        }
        
        TestHelper.testFailure(&parser, expectedError: DataParserError.outOfBounds) {
            try $0.readData(count: 1, advance: $1)
        }
    }
    
    @Test func testStringEncodings() throws {
        let string = "Tëstíñg Tê§†ing"
        
        let encodings: [String.Encoding] = [.nextstep, .utf8, .utf16, .windowsCP1252, .windowsCP1254, .macOSRoman]
        
        var rawData = Data()
        var cStringData = Data()
        var pascalStringData = Data()
        
        let lengths: [Int] = encodings.map { encoding in
            let stringData = string.data(using: encoding)!
            
            rawData += stringData
            
            if encoding != .utf16 {
                for _ in 0..<3 {
                    cStringData += stringData + [0]
                }
                
                rawData += stringData
            }
            
            pascalStringData += [UInt8(stringData.count)] + stringData
            
            return stringData.count
        }
        
        var rawParser = DataParser(rawData)
        var cStringParser = DataParser(cStringData)
        var pascalStringParser = DataParser(pascalStringData)
        
        TestHelper.testFailure(&rawParser, expectedError: DataParserError.outOfBounds) {
            try $0.readString(byteCount: rawData.count + 1, encoding: .utf8, advance: $1)
        }
        
        TestHelper.testFailure(&cStringParser, expectedError: DataParserError.outOfBounds) {
            try $0.readCString(byteCount: cStringData.count + 1, requireNullTerminator: true, encoding: .utf8, advance: $1)
        }
        
        TestHelper.testFailure(&cStringParser, expectedError: DataParserError.outOfBounds) {
            try $0.readCString(byteCount: cStringData.count + 1, requireNullTerminator: false, encoding: .utf8, advance: $1)
        }
        
        for (encoding, length) in zip(encodings, lengths) {
            if encoding != .utf16 {
                try TestHelper.testRead(&cStringParser, expect: string, byteCount: length + 1) { parser, advance in
                    try parser.readCString(encoding: encoding, advance: advance)
                }
                
                try TestHelper.testRead(&cStringParser, expect: string, byteCount: length + 1) { parser, advance in
                    try parser.readCString(
                        byteCount: length + 1,
                        requireNullTerminator: false,
                        encoding: encoding,
                        advance: advance
                    )
                }
                
                TestHelper.testFailure(
                    &cStringParser,
                    expectedError: CocoaError(.fileReadInapplicableStringEncoding),
                    reason: "Should fail if the string cannot be rendered in the requested encoding"
                ) { try $0.readCString(encoding: .nonLossyASCII, advance: $1) }
                
                try TestHelper.testRead(&cStringParser, expect: string, byteCount: length + 1) { parser, advance in
                    try parser.readCString(
                        byteCount: length + 1,
                        requireNullTerminator: true,
                        encoding: encoding,
                        advance: advance
                    )
                }
                
                try TestHelper.testRead(&rawParser, expect: string, byteCount: length) { parser, advance in
                    try parser.readCString(
                        byteCount: length,
                        requireNullTerminator: false,
                        encoding: encoding,
                        advance: advance
                    )
                }
                
                TestHelper.testFailure(
                    &rawParser,
                    expectedError: CocoaError(.fileReadCorruptFile),
                    reason: "Should fail because there are no terminator bytes in the data"
                ) { try $0.readCString(byteCount: length, requireNullTerminator: true, encoding: encoding, advance: $1) }
            }
            
            TestHelper.testFailure(
                &rawParser,
                expectedError: CocoaError(.fileReadInapplicableStringEncoding),
                reason: "Should fail if the string cannot be rendered in the requested encoding"
            ) { try $0.readString(byteCount: length, encoding: .nonLossyASCII, advance: $1) }
            
            try TestHelper.testRead(&rawParser, expect: string, byteCount: length) { parser, advance in
                try parser.readString(byteCount: length, encoding: encoding, advance: advance)
            }
            
            try TestHelper.testRead(&pascalStringParser, expect: string, byteCount: length + 1) { parser, advance in
                try parser.readPascalString(encoding: encoding, advance: advance)
            }
        }
    }
    
    @Test func testReadFileSystemRepresentation() throws {
        let paths: [(path: String, isDirectory: Bool, (any Error & Equatable)?)] = [
            ("/bin", true, nil),
            ("/usr/bin/true", false, nil),
            ("/etc/zshrc", false, nil),
            (FileManager.default.homeDirectoryForCurrentUser.path, true, nil),
            ("/dev/does/not/exist", true, nil),
            ("/dev/also/does/not/exist", false, nil),
            ("\0\0\0", false, CocoaError(.fileReadUnknown)),
            ("\0\0\0", true, CocoaError(.fileReadUnknown)),
        ]
        
        var data = Data()
        var lengths: [Int] = []
        
        for (path, _, _) in paths {
#if canImport(Darwin)
            let pathData = withExtendedLifetime(path as NSString) {
                let fileSystemRep = $0.fileSystemRepresentation
                return Data(bytes: fileSystemRep, count: strlen(fileSystemRep)) + [0]
            }
#else
            let pathData = try FileManager.default.withFileSystemRepresentation(for: path) {
                guard let fileSystemRep = $0 else { throw CocoaError(.fileReadUnknown) }

                return Data(bytes: fileSystemRep, count: strlen(fileSystemRep)) + [0]
            }
#endif

            data.append(pathData)
            data.append(pathData)

            lengths.append(pathData.count)
        }
        
        var parser = DataParser(data)
        
        for ((path, isDirectory, err), length) in zip(paths, lengths) {
            if let err {
                TestHelper.testFailure(&parser, expectedError: err) {
                    try $0.readFileSystemRepresentation(isDirectory: isDirectory, advance: $1)
                }
                
                TestHelper.testFailure(&parser, expectedError: err) {
                    try $0.readFileSystemRepresentation(isDirectory: nil, advance: $1)
                }
                
                try parser.skipBytes(length)
            } else {
                let expectedURL = URL(fileURLWithPath: path)
                let expectedURLWithDirectory = URL(fileURLWithPath: path, isDirectory: isDirectory)
                
                try TestHelper.testRead(&parser, expect: expectedURL, byteCount: length) { parser, advance in
                    try parser.readFileSystemRepresentation(advance: advance)
                }
                
                try TestHelper.testRead(&parser, expect: expectedURLWithDirectory, byteCount: length) { parser, advance in
                    try parser.readFileSystemRepresentation(isDirectory: isDirectory, advance: advance)
                }
            }
        }
    }
    
    @Test func testReadUUID() throws {
        let data = Data([
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
            0xff, 0xfe, 0xfd, 0xfc, 0xaa, 0xa9, 0xa8, 0xa7, 0xb0, 0xb1, 0xb2, 0xb3, 0xc4, 0xc3, 0xc2, 0xc1
        ])
        
        var parser = DataParser(data)
        
        let uuid1 = UUID(uuid: uuid_t(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
        let uuid2 = UUID(
            uuid: uuid_t(0xff, 0xfe, 0xfd, 0xfc, 0xaa, 0xa9, 0xa8, 0xa7, 0xb0, 0xb1, 0xb2, 0xb3, 0xc4, 0xc3, 0xc2, 0xc1)
        )
        
        #expect(try parser.readUUID(advance: false) == uuid1)
        #expect(try parser.readUUID(advance: true) == uuid1)
        #expect(try parser.readUUID(advance: true) == uuid2)
    }
}
#else
    #warning("Foundation trait disabled - Foundation features not tested")
#endif
