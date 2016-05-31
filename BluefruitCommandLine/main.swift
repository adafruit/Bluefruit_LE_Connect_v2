//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


let commandLine = CommandLine()

// Process arguments
for argument in Process.arguments {
   
    switch argument.uppercaseString {
    case "-?":
        commandLine.showHelp()
        
    case "-S":
        commandLine.startScanning()
        let _ = readLine(stripNewline: true)
        
    case "-DFU":
//        commandLine.dfu()
        break
        
    default:
        DLog("unknown argument: \(argument)")
    }
}

exit(EXIT_SUCCESS)

