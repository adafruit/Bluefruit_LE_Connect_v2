//
//  LogHelper.swift
//  BluefruitPlayground
//
//  Created by Antonio García on 10/10/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation

// Note: check that Build Settings -> Project -> Active Compilation Conditions -> Debug, has DEBUG

func DLog(_ message: String, function: String = #function) {
    if _isDebugAssertConfiguration() {
        NSLog("%@, %@", function, message)
    }
}
