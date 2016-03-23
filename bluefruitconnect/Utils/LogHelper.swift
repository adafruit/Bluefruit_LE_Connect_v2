//
//  LogHelper.swift


import Foundation

// dLog and aLog macros to abbreviate NSLog.
// Note: Add -D DEBUG to "Swift Compiler - Custom Flags" build section
// Use like this:
//   dLog("Log this!")

#if DEBUG
    func DLog(@autoclosure message:  () -> String, filename: NSString = #file, function: String = #function, line: Int = #line) {
        NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message())
    }
    #else
    func DLog(@autoclosure message:  () -> String, filename: String = #file, function: String = #function, line: Int = #line) {
    }
#endif

func ALog(message: String, filename: NSString = #file, function: String = #function, line: Int = #line) {
    NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message)
}