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
    static let isDebugEnabled = true
    #else
    static let isDebugEnabled = false
    #endif

}
