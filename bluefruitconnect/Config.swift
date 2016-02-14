//
//  Config.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 13/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


struct Config {

    #if DEBUG
    static let DEBUG = true
    #else
    static let DEBUG = false
    #endif
    
    // Uart
    static let uartShowAllUartCommunication = Config.DEBUG && true
    static let uartLogSend = Config.DEBUG && true
    static let uartLogReceive = Config.DEBUG && true
    
}