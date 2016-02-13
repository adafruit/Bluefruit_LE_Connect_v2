//
//  UartDataChunk.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class UartDataChunk {      // A chunk of data received or sent
    var timestamp : CFAbsoluteTime
    enum TransferMode {
        case TX
        case RX
    }
    var mode : TransferMode
    var data : NSData
    
    init(timestamp: CFAbsoluteTime, mode: TransferMode, data: NSData) {
        self.timestamp = timestamp
        self.mode = mode
        self.data = data
    }
}