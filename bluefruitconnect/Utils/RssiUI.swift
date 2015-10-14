//
//  RssiUI.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 14/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation


func signalImageForRssi(rssi:Int) -> NSImage {
    
    var index : Int
    
    if rssi == 127 {     // value of 127 reserved for RSSI not available
        index = 0
    }
    else if rssi <= -84 {
        index = 0
    }
    else if rssi <= -72 {
        index = 1
    }
    else if rssi <= -60 {
        index = 2
    }
    else if rssi <= -48 {
        index = 3
    }
    else {
        index = 4
    }
    
    return NSImage(named: "signalstrength\(index)")!
}