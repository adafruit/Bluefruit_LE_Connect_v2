//
//  Int+ToByteArray.swift
//  Bluefruit
//
//  Created by Antonio García on 11/06/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation

// From https://stackoverflow.com/questions/29970204/split-uint32-into-uint8-in-swift

protocol UIntToBytesConvertable {
    var toBytes: [UInt8] { get }
}

extension UIntToBytesConvertable {
    fileprivate func toByteArr<T: FixedWidthInteger>(endian: T, count: Int) -> [UInt8] {
        var _endian = endian
        let bytePtr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](bytePtr)
    }
}

extension UInt16: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian, count: MemoryLayout<UInt16>.size)
    }
}

extension UInt32: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,  count: MemoryLayout<UInt32>.size)
    }
}

extension UInt64: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian, count: MemoryLayout<UInt64>.size)
    }
}
