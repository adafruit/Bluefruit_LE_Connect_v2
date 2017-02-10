//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Based on http://rachid.koucha.free.fr/tech_corner/pty_pdip.htmlbc

func main() {
    
    enum Command: String {
        case version = "--version"
        case versionShort = "--v"
        case help = "--help"
        case helpShort = "--?"

        case scan = "scan"
        case dfu = "dfu"
        case update = "update"
    }
    
    enum Parameter: String {
        case peripheralUuid = "--uuid"
        case peripheralUuidShort = "-u"
        case hexFile = "--hex"
        case hexFileShort = "-h"
        case iniFile = "--init"
        case iniFileShort = "-i"
        case showBetaVersions = "--enable-beta"
        case showBetaVersionsShort = "-b"
    }
    
    // Data
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "", attributes: DispatchQueue.Attributes.concurrent)
    let commandLine = CommandLine()
    
    var command: Command?
    var peripheralIdentifier: UUID?
    var hexUrl: URL?
    var iniUrl: URL?
    var showBetaVersions = false
    
    let currentDirectoryUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    // Process arguments
    var arguments = Swift.CommandLine.arguments
    arguments.removeFirst()     // remove path
    var skipNextArgument = false
    for (index, argument) in arguments.enumerated() {
        
        if !skipNextArgument {
            
            switch argument.lowercased() {
            
            case Command.version.rawValue, Command.versionShort.rawValue:
                command = .version
                
            case Command.help.rawValue, Command.helpShort.rawValue:
                command = .help
                
            case Command.scan.rawValue:
                command = .scan
                
            case Command.dfu.rawValue:
                command = .dfu

            case Command.update.rawValue:
                command = .update
                
            case Parameter.peripheralUuid.rawValue, Parameter.peripheralUuidShort.rawValue:
                peripheralIdentifier = nil
                if arguments.count >= index+1 {
                    peripheralIdentifier = UUID(uuidString: arguments[index+1])
                    skipNextArgument = true
                }
                
                if peripheralIdentifier == nil {
                    print("\(Parameter.peripheralUuid.rawValue) needs a valid peripheral identifier")
                }
                
            case Parameter.hexFile.rawValue, Parameter.hexFileShort.rawValue:
                hexUrl = nil
                if arguments.count >= index+1 {
                    let hexFileName = arguments[index+1]
                    hexUrl = currentDirectoryUrl.appendingPathComponent(hexFileName)
                    
                    //                DLog("hex: \(hexFileName!)")
                    skipNextArgument = true
                }
                
                if hexUrl == nil {
                    print("\(Parameter.hexFile.rawValue) needs a valid file name")
                }
                
            case Parameter.iniFile.rawValue, Parameter.iniFileShort.rawValue:
                iniUrl = nil
                if arguments.count >= index+1 {
                    let iniFileName = arguments[index+1]
                    iniUrl = currentDirectoryUrl.appendingPathComponent(iniFileName)
                    skipNextArgument = true
                }

                if iniUrl == nil {
                    print("\(Parameter.iniFile.rawValue) needs a valid file name")
                }
                
            case Parameter.showBetaVersions.rawValue, Parameter.showBetaVersionsShort.rawValue:
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
        print(errorMessage ?? "<Unknown Bluetooth Error>")
        exit(EXIT_FAILURE)
    }
    
    // Execute order
    if let command = command {
        switch command {
        case .version:
            commandLine.showVersion()

        case .help:
            commandLine.showHelp()

        case .scan:
            print("Scanning...")
            commandLine.startScanning()
            let _ = readLine(strippingNewline: true)
        
        case .dfu:
            print("DFU Update")
            
            // Check input parameters
            guard let hexUrl = hexUrl else {
                print(".hex file not defined")
                exit(EXIT_FAILURE)
            }
            
            if peripheralIdentifier == nil {
                peripheralIdentifier = commandLine.askUserForPeripheral()
            }
            
            guard let peripheralIdentifier = peripheralIdentifier else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }
            
            print("\tUUID: \(peripheralIdentifier)")
            print("\tHex:  \(hexUrl)")
            if let iniUrl = iniUrl {
                print("\tInit: \(iniUrl)")
            }
            
            // Launch dfu
            queue.async(group: group) {
                commandLine.dfuPeripheral(uuid: peripheralIdentifier, hexUrl: hexUrl, iniUrl: iniUrl)
            }
            group.wait(timeout: DispatchTime.distantFuture)
            
            
        case .update:
            print("Automatic Update")
            
            let serverUrl = URL(string: "https://raw.githubusercontent.com/adafruit/Adafruit_BluefruitLE_Firmware/master/releases.xml")!
            
            var releases: [AnyHashable: Any]? = nil
            let downloadReleasesSemaphore = DispatchSemaphore(value: 0)
            queue.async(group: group) {
                commandLine.downloadFirmwareUpdatesDatabase(url: serverUrl, showBetaVersions: showBetaVersions, completionHandler: { (boardInfo) in
                    DLog("releases downloaded")
                    releases = boardInfo
                    downloadReleasesSemaphore.signal()
                })
            }
            
            // Check input parameters
            if peripheralIdentifier == nil {
                peripheralIdentifier = commandLine.askUserForPeripheral()
            }
            
            guard let peripheralIdentifier = peripheralIdentifier else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }

            downloadReleasesSemaphore.wait(timeout: DispatchTime.distantFuture)      // Wait for server download
            
            guard releases != nil else {
                print("Error downloading updates info from: \(serverUrl)")
                exit(EXIT_FAILURE)
            }
            
            // Launch dfu
            queue.async(group: group) {
                commandLine.dfuPeripheral(uuid: peripheralIdentifier, releases: releases)
            }
            group.wait(timeout: DispatchTime.distantFuture)
            
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
CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue) { () -> Void in
    DispatchQueue(label: "main", attributes: []).async {
        main()
        CFRunLoopStop(runloop)
    }
}
CFRunLoopRun()
