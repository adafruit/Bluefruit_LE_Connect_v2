//
//  RssiUI.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 14/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

#if os(OSX)
    public typealias Image = NSImage
#else
    public typealias Image = UIImage
    
#endif

func signalImageForRssi(rssi:Int) -> Image {
    
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
    
    return Image(named: "signalstrength\(index)")!
}