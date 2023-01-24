//
//  DataParser_Foundation.swift
//  
//
//  Created by Charles Srstka on 3/10/22.
//

import Foundation
@_spi(DataParserInternal) import DataParser

extension DataParser {
    public mutating func readData(count: some BinaryInteger, advance: Bool = true) throws -> Data {
        let count = Int(count)
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)

        do {
            try self.copyToPointer(ptr, count: count, advance: advance)

            return Data(bytesNoCopy: ptr, count: count, deallocator: .custom { ptr, _ in
                ptr.deallocate()
            })
        } catch {
            ptr.deallocate()
            throw error
        }
    }

    public mutating func readDataToEnd(advance: Bool = true) throws -> Data {
        return try self.readData(count: self.bytesLeft, advance: advance)
    }

    public mutating func readString(
        byteCount: some BinaryInteger,
        encoding: String.Encoding,
        advance: Bool = true
    ) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let data = try parser.readData(count: byteCount, advance: advance)
            guard let string = String(data: data, encoding: encoding) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            return string
        }
    }

    public mutating func readCString(encoding: String.Encoding, advance: Bool = true) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let data = try parser.readCStringBytes(advance: advance)
            return try parser.string(from: data, requireNullTerminator: false, encoding: encoding)
        }
    }

    public mutating func readCString(
        byteCount: some BinaryInteger,
        requireNullTerminator: Bool = true,
        encoding: String.Encoding,
        advance: Bool = true
    ) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let data = try parser.readData(count: byteCount, advance: advance)
            return try parser.string(from: data, requireNullTerminator: requireNullTerminator, encoding: encoding)
        }
    }

    private mutating func readCStringBytes(advance: Bool) throws -> Data {
        try self._makeAtomic(advance: advance) { parser in
            let (length: byteCount, hasTerminator: hasTerminator) = try parser.getCStringLength()

            let bytes = try parser.readData(count: byteCount, advance: advance)

            if advance && hasTerminator {
                try parser.skipBytes(1)
            }

            return bytes
        }
    }
    
    private func string(from data: Data, requireNullTerminator: Bool, encoding: String.Encoding) throws -> String {
        let nullIdx: Data.Index = try {
            if let idx = data.firstIndex(where: { $0 == 0 }) {
                return idx
            } else if requireNullTerminator {
                throw CocoaError(.fileReadCorruptFile)
            } else {
                return data.endIndex
            }
        }()

        switch encoding {
        case .utf8:
            return String(decoding: data[..<nullIdx], as: UTF8.self)
        default:
            guard let string = String(bytes: data[..<nullIdx], encoding: encoding) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            return string
        }
    }

    public mutating func readFileSystemRepresentation(isDirectory: Bool? = nil, advance: Bool = true) throws -> URL {
        try self._makeAtomic(advance: advance) { parser in
            let bytes = try parser.readCStringBytes(advance: advance)

            return try bytes.withUnsafeBytes { bytes in
                if let isDirectory = isDirectory {
                    let path = bytes.bindMemory(to: CChar.self)

                    guard let url = CFURLCreateFromFileSystemRepresentation(
                        kCFAllocatorDefault,
                        path.baseAddress,
                        path.count,
                        isDirectory
                    ) else {
                        throw CocoaError(.fileReadUnknown)
                    }

                    return url as URL
                } else {
                    let path: String

                    if let ptr = bytes.bindMemory(to: Int8.self).baseAddress {
                        path = FileManager.default.string(withFileSystemRepresentation: ptr, length: bytes.count)
                    } else {
                        throw CocoaError(.fileReadUnknown)
                    }

                    return URL(fileURLWithPath: path)
                }
            }
        }
    }

    public mutating func readPascalString(encoding: String.Encoding, advance: Bool = true) throws -> String {
        try self._makeAtomic(advance: advance) { parser in
            let count: UInt8 = try parser.readByte(advance: true)
            return try parser.readString(byteCount: Int(count), encoding: encoding, advance: advance)
        }
    }
}
