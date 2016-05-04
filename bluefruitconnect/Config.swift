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
    
    // Peripheral list
//    static let peripheralListShowOnlyWithUart = Config.DEBUG && false
//    static let peripheralListSelectToConnect = Config.DEBUG && false
    
    // Uart
    static let uartShowAllUartCommunication = Config.DEBUG && true
    static let uartLogSend = Config.DEBUG && true
    static let uartLogReceive = Config.DEBUG && true
    
    
    // Enabled Modules
    #if os(OSX)
    
    static let isUartModuleEnabled = true
    static let isPinIOModuleEnabled = true
    static let isControllerModuleEnabled = false        // Note: not implemented yet
    static let isDfuModuleEnabled = true
    static let isNeoPixelModuleEnabled = Config.DEBUG && false
    
    #else       // iOS, tvOS
    
    static let isUartModuleEnabled = true
    static let isPinIOModuleEnabled = true
    static let isControllerModuleEnabled = true
    static let isDfuModuleEnabled = true
    static let isNeoPixelModuleEnabled = true
    #endif
    
}