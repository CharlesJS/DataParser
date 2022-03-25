//
//  ContiguousBytes.swift
//  
//
//  Created by Charles Srstka on 3/12/22.
//

protocol ContiguousBytes {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}
