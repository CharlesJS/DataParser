//
//  ByteOrder.swift
//
//  Created by Charles Srstka on 3/6/22.
//

public enum ByteOrder {
    case host
    case little
    case big

    private static let hostIsLittleEndian = UInt16(littleEndian: 0x1234) == 0x1234

    public var isBig: Bool { !self.isLittle }

    public var isLittle: Bool {
        switch self {
        case .host:
            return ByteOrder.hostIsLittleEndian
        case .little:
            return true
        case .big:
            return false
        }
    }

    public var isHost: Bool {
        switch self {
        case .host:
            return true
        case .little:
            return ByteOrder.hostIsLittleEndian
        case .big:
            return !ByteOrder.hostIsLittleEndian
        }
    }
}
