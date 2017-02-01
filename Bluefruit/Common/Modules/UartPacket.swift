//
//  UartPacket.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

struct UartPacket {      // A packet of data received or sent
    var timestamp: CFAbsoluteTime
    enum TransferMode {
        case tx
        case rx
    }
    var mode: TransferMode
    var data: Data
    
    init(timestamp: CFAbsoluteTime, mode: TransferMode, data: Data) {
        self.timestamp = timestamp
        self.mode = mode
        self.data = data
    }
}
