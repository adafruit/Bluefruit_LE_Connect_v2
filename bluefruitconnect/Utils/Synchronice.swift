//
//  Synchronice.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


func synchronize(lock: AnyObject, closure: () -> Void) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}