//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


func main() {
    
    enum Command: String {
        case Version = "--version"
        case VersionShort = "--v"
        case Help = "--help"
        case HelpShort = "--?"

        case Scan = "scan"
        case Dfu = "dfu"
        case Update = "update"
    }
    
    enum Parameter: String {
        case PeripheralUuid = "--uuid"
        case PeripheralUuidShort = "-u"
        case HexFile = "--hex"
        case HexFileShort = "-h"
        case IniFile = "--init"
        case IniFileShort = "-i"
        case ShowBetaVersions = "--enable-beta"
        case ShowBetaVersionsShort = "-b"
    }
    
    // Data
    let group = dispatch_group_create()
    let queue = dispatch_queue_create("", DISPATCH_QUEUE_CONCURRENT)
    let commandLine = CommandLine()
    
    var command: Command?
    var peripheralUuid: String?
    var hexUrl: NSURL?
    var iniUrl: NSURL?
    var showBetaVersions = false
    
    let currentDirectoryUrl = NSURL(fileURLWithPath: NSFileManager.defaultManager().currentDirectoryPath)
    
    // Process arguments
    var arguments = Process.arguments
    arguments.removeFirst()     // remove path
    var skipNextArgument = false
    for (index, argument) in arguments.enumerate() {
        
        if !skipNextArgument {
            
            switch argument.lowercaseString {
            
            case Command.Version.rawValue, Command.VersionShort.rawValue:
                command = .Version
                
            case Command.Help.rawValue, Command.HelpShort.rawValue:
                command = .Help
                
            case Command.Scan.rawValue:
                command = .Scan
                
            case Command.Dfu.rawValue:
                command = .Dfu

            case Command.Update.rawValue:
                command = .Update
                
            case Parameter.PeripheralUuid.rawValue, Parameter.PeripheralUuidShort.rawValue:
                peripheralUuid = nil
                if arguments.count >= index+1 {
                    peripheralUuid = arguments[index+1]
                    skipNextArgument = true
                }
                
                if peripheralUuid == nil {
                    print("\(Parameter.PeripheralUuid.rawValue) needs a valid peripheral identifier")
                }
                
            case Parameter.HexFile.rawValue, Parameter.HexFileShort.rawValue:
                hexUrl = nil
                if arguments.count >= index+1 {
                    let hexFileName = arguments[index+1]
                    hexUrl = currentDirectoryUrl.URLByAppendingPathComponent(hexFileName)
                    
                    //                DLog("hex: \(hexFileName!)")
                    skipNextArgument = true
                }
                
                if hexUrl == nil {
                    print("\(Parameter.HexFile.rawValue) needs a valid file name")
                }
                
            case Parameter.IniFile.rawValue, Parameter.IniFileShort.rawValue:
                iniUrl = nil
                if arguments.count >= index+1 {
                    let iniFileName = arguments[index+1]
                    iniUrl = currentDirectoryUrl.URLByAppendingPathComponent(iniFileName)
                    skipNextArgument = true
                }

                if iniUrl == nil {
                    print("\(Parameter.IniFile.rawValue) needs a valid file name")
                }
                
            case Parameter.ShowBetaVersions.rawValue, Parameter.ShowBetaVersionsShort.rawValue:
                showBetaVersions = true

            default:
                print("Unknown argument: \(argument)")
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
    if let command = command {
        switch command {
        case .Version:
            commandLine.showVersion()

        case .Help:
            commandLine.showHelp()

        case .Scan:
            print("Scanning...")
            commandLine.startScanning()
            let _ = readLine(stripNewline: true)
        
        case .Dfu:
            print("DFU Update")
            
            // Check input parameters
            guard let hexUrl = hexUrl else {
                print(".hex file not defined")
                exit(EXIT_FAILURE)
            }
            
            if peripheralUuid == nil {
                peripheralUuid = commandLine.askUserForPeripheral()
            }
            
            guard let peripheralUuid = peripheralUuid else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }
            
            print("\tUUID: \(peripheralUuid)")
            print("\tHex:  \(hexUrl)")
            if let iniUrl = iniUrl {
                print("\tInit: \(iniUrl)")
            }
            
            // Launch dfu
            dispatch_group_async(group, queue) {
                commandLine.dfuPeripheralWithUUIDString(peripheralUuid, hexUrl: hexUrl, iniUrl: iniUrl)
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            
        case .Update:
            print("Automatic Update")
            
            let serverUrl = NSURL(string: "https://raw.githubusercontent.com/adafruit/Adafruit_BluefruitLE_Firmware/master/releases.xml")!
            
            var releases: [NSObject : AnyObject]? = nil
            let downloadReleasesSemaphore = dispatch_semaphore_create(0)
            dispatch_group_async(group, queue) {
                commandLine.downloadFirmwareUpdatesDatabaseFromUrl(serverUrl, showBetaVersions: showBetaVersions, completionHandler: { (boardInfo) in
                    DLog("releases downloaded")
                    releases = boardInfo
                    dispatch_semaphore_signal(downloadReleasesSemaphore)
                })
            }
            
            // Check input parameters
            if peripheralUuid == nil {
                peripheralUuid = commandLine.askUserForPeripheral()
            }
            
            guard let peripheralUuid = peripheralUuid else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }

            dispatch_semaphore_wait(downloadReleasesSemaphore, DISPATCH_TIME_FOREVER)      // Wait for server download
            
            guard releases != nil else {
                print("Error downloading updates info from: \(serverUrl)")
                exit(EXIT_FAILURE)
            }
            
            // Launch dfu
            dispatch_group_async(group, queue) {
                commandLine.dfuPeripheralWithUUIDString(peripheralUuid, releases: releases)
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
        default:
            print("Unknown command: \(command.rawValue)")
            break
        }
    }
    else {
        commandLine.showHelp()
    }
    
    exit(EXIT_SUCCESS)
}


let runloop = CFRunLoopGetCurrent()
CFRunLoopPerformBlock(runloop, kCFRunLoopDefaultMode) { () -> Void in
    dispatch_async(dispatch_queue_create("main", nil)) {
        main()
        CFRunLoopStop(runloop)
    }
}
CFRunLoopRun()
