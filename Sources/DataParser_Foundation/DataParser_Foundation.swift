//
//  DataParser_Foundation.swift
//  
//
//  Created by Charles Srstka on 3/10/22.
//

import Foundation
import DataParser

extension DataParser {
    public mutating func readData(count: Int, advance: Bool = true) throws -> Data {
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

    public mutating func readString(byteCount: Int, encoding: String.Encoding, advance: Bool = true) throws -> String {
        let data = try self.readData(count: byteCount, advance: advance)
        guard let string = String(data: data, encoding: encoding) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        return string
    }

    public mutating func readCString(encoding: String.Encoding, advance: Bool = true) throws -> String {
        let data = try self.readCStringBytes(advance: advance)
        return try self.string(from: data, requireNullTerminator: false, encoding: encoding)
    }

    public mutating func readCString(
        byteCount: Int,
        requireNullTerminator: Bool = true,
        encoding: String.Encoding,
        advance: Bool = true
    ) throws -> String {
        let data = try self.readData(count: byteCount, advance: advance)
        return try self.string(from: data, requireNullTerminator: requireNullTerminator, encoding: encoding)
    }

    private mutating func readCStringBytes(advance: Bool) throws -> Data {
        let (length: byteCount, hasTerminator: hasTerminator) = try self.getCStringLength()

        let bytes = try self.readData(count: byteCount, advance: advance)

        if advance && hasTerminator {
            try self.skipBytes(1)
        }

        return bytes
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

    public mutating func readFileSystemRepresentation(
        advance: Bool = true,
        isDirectory: Bool? = nil
    ) throws -> URL {
        let bytes = try self.readCStringBytes(advance: advance)

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

    public mutating func readPascalString(_ encoding: String.Encoding, advance: Bool = true) throws -> String {
        let count: UInt8 = try self.readByte(advance: true)
        defer { if !advance { self.cursor = self.cursor &- 1 } }

        return try self.readString(byteCount: Int(count), encoding: encoding, advance: advance)
    }
}
