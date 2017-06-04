//
//  LogHelper.swift

import Foundation

func DLog(_ message: String, function: String = #function) {
    #if DEBUG
        NSLog("%@, %@", function, message)
    #endif
}
