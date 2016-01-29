//
//  LogHelper.swift


import Foundation

// dLog and aLog macros to abbreviate NSLog.
// Use like this:
//
//   dLog("Log this!")
//
#if DEBUG
    func DLog(@autoclosure message:  () -> String, filename: NSString = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
        NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message())
    }
    #else
    func DLog(@autoclosure message:  () -> String, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    }
#endif

func ALog(message: String, filename: NSString = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message)
}