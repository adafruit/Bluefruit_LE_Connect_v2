//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

enum Order: String {
    case Version = "-v"
    case Help = "-?"
    case Scan = "-scan"
    case Dfu = "-dfu"
}

enum Parameter: String {
    case PeripheralUuid = "uuid"
    case HexFile = "hex"
    case IniFile = "ini"
}

let commandLine = CommandLine()

var order: Order?
var peripheralUuid: String?
var hexFileName: String?
var iniFileName: String?

// Process arguments
var arguments = Process.arguments
arguments.removeFirst()     // remove path
var skipNextArgument = false
for (index, argument) in arguments.enumerate() {
    
    if !skipNextArgument {
        
        switch argument.lowercaseString {
        case Order.Help.rawValue:
            order = .Help
            
        case Order.Scan.rawValue:
            order = .Scan
            
        case Order.Dfu.rawValue:
            order = .Dfu
            
        case Parameter.PeripheralUuid.rawValue:
            peripheralUuid = nil
            if arguments.count >= index+1 {
                peripheralUuid = arguments[index+1]
            }
            
            if peripheralUuid == nil {
                print("\(Parameter.PeripheralUuid.rawValue) needs a valid peripheral identifier")
            }
            
        case Parameter.HexFile.rawValue:
            hexFileName = nil
            if arguments.count >= index+1 {
                hexFileName = arguments[index+1]
//                DLog("hex: \(hexFileName!)")
                skipNextArgument = true
            }
            
            if hexFileName == nil {
                print("\(Parameter.HexFile.rawValue) needs a valid file name")
            }
            
        case Parameter.IniFile.rawValue:
            iniFileName = nil
            if arguments.count >= index+1 {
                iniFileName = arguments[index+1]
                skipNextArgument = true
           }
            
            if iniFileName == nil {
                print("\(Parameter.IniFile.rawValue) needs a valid file name")
            }
            
        default:
            /*
             if argument.hasSuffix(".hex") {
             hexFileName = argument
             }
             else if argument.hasSuffix(".ini") {
             hexFileName = argument
             }
             else {
             DLog("unknown argument: \(argument)")
             }
             */
            DLog("unknown argument: \(argument)")
            
        }
    }
    else {
        skipNextArgument = false
    }
}

// Check Bluetooth Errors
let errorMessage = commandLine.checkBluetoothErrors()
guard errorMessage == nil else {
    print(errorMessage)
    exit(EXIT_FAILURE)
}


// Execute order
if let order = order {
    switch order {
    case .Help:
        commandLine.showHelp()
        
    case .Scan:
        commandLine.startScanning()
        let _ = readLine(stripNewline: true)
        
    case .Dfu:
        guard let hexFileName = hexFileName else {
            print(".hex file not defined")
            exit(EXIT_FAILURE)
        }
        
        if peripheralUuid == nil {
            print("Select a peripheral for dfu. Scanning...")
            
            commandLine.startScanningAndShowIndex(true)
            let peripheralIndexString = readLine(stripNewline: true)
            //0DLog("selected: \(peripheralIndexString)")
            if let peripheralIndexString = peripheralIndexString, peripheralIndex = Int(peripheralIndexString) where peripheralIndex>=0 && peripheralIndex < commandLine.discoveredPeripheralsIdentifiers.count {
                peripheralUuid = commandLine.discoveredPeripheralsIdentifiers[peripheralIndex]
                
                print("Selected UUID: \(peripheralUuid!)")
            }
       
        }
      
        guard let peripheralUuid = peripheralUuid else {
            print("Peripheral UUID invalid")
            exit(EXIT_FAILURE)
        }
        
        commandLine.dfuPeripheralWithUUIDString(peripheralUuid, hexPath: hexFileName, iniPath: iniFileName)
      
    default:
        break
    }
}

exit(EXIT_SUCCESS)

