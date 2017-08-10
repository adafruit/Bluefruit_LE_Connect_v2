//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Based on http://rachid.koucha.free.fr/tech_corner/pty_pdip.htmlbc

// TTY
//let isTtyEnabled = true

func main() {
//func main(fds: Int32, fdm: Int32) {

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
        case zipFile = "--zip"
        case zipFileShort = "-z"
        case showBetaVersions = "--enable-beta"
        case showBetaVersionsShort = "-b"
        case ignoreDFUChecks = "--ignore-warnings"
    }

    // Data
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "", attributes: DispatchQueue.Attributes.concurrent)
    let commandLine = CommandLine()

    var command: Command?
    var peripheralIdentifier: UUID?
    var hexUrl: URL?
    var iniUrl: URL?
    var zipUrl: URL?
    var showBetaVersions = false
    var ignoreDFUChecks = false


    /*
    if isTtyEnabled {
        close(fdm)
    }
   
    var serialPort: ORSSerialPort?
    
    if isTtyEnabled {
        serialPort = ORSSerialPort(path: "/dev/ttys005")
        if serialPort == nil {
            print("Error opening serial port");
        }
        serialPort?.open()
    }
 */

    /*
    // TTY
    if isTtyEnabled {
        var fdm, fds: Int32
        
        // Disable bufffer
        setbuf(stdout, nil)
        
        // Open
        fdm = posix_openpt(O_RDWR);
        if (fdm < 0) {
            print(stderr, "Error \(errno) on posix_openpt()\n")
            exit(EXIT_FAILURE)
        }
        
        var rc = grantpt(fdm)
        if rc != 0
        {
            print(stderr, "Error \(errno) on grantpt()\n");
            exit(EXIT_FAILURE)
        }
        
        rc = unlockpt(fdm)
        if rc != 0
        {
            print(stderr, "Error \(errno) on unlockpt()\n");
            exit(EXIT_FAILURE)
        }
        
        // Open the slave side ot the PTY
        fds = open(ptsname(fdm), O_RDWR)
        let name = String(utf8String: UnsafePointer<CChar>(ptsname(fdm)))
        print("The master side is named: \(name ?? "<unknown>")\n")
        

        
    }*/

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
                
            case Parameter.ignoreDFUChecks.rawValue:
                ignoreDFUChecks = true

            case Parameter.hexFile.rawValue, Parameter.hexFileShort.rawValue:
                hexUrl = nil
                if arguments.count >= index+1 {
                    let hexFileName = arguments[index+1]
                    hexUrl = createAbsoluteUrlWith(hexFileName)

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
                    iniUrl = createAbsoluteUrlWith(iniFileName)
                    skipNextArgument = true
                }

                if iniUrl == nil {
                    print("\(Parameter.iniFile.rawValue) needs a valid file name")
                }

            case Parameter.zipFile.rawValue, Parameter.zipFileShort.rawValue:
                zipUrl = nil
                if arguments.count >= index+1 {
                    let zipFileName = arguments[index+1]
                    zipUrl = createAbsoluteUrlWith(zipFileName)
                    skipNextArgument = true
                }
                
                if zipUrl == nil {
                    print("\(Parameter.zipFile.rawValue) needs a valid file name")
                }

            case Parameter.showBetaVersions.rawValue, Parameter.showBetaVersionsShort.rawValue:
                showBetaVersions = true

            default:
                print("Unknown argument: \(argument)")
            }
        } else {
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
            if zipUrl == nil && hexUrl == nil {
               print (".zip or .hex files needed to perform update")
                exit(EXIT_FAILURE)
            }
            
            if peripheralIdentifier == nil {
                peripheralIdentifier = commandLine.askUserForPeripheral()
            }

            guard let peripheralIdentifier = peripheralIdentifier else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }

            if ignoreDFUChecks {
                print("\tIgnore DFU warnings")
            }
            
            print("\tUUID: \(peripheralIdentifier)")
            
            if let hexUrl = hexUrl {
                print("\tHex:  \(hexUrl)")
                if let iniUrl = iniUrl {
                    print("\tInit: \(iniUrl)")
                }
                
                // Launch dfu
                queue.async(group: group) {
                    commandLine.dfuPeripheral(uuid: peripheralIdentifier, hexUrl: hexUrl, iniUrl: iniUrl, ignorePreChecks: ignoreDFUChecks)
                }
            }
            else if let zipUrl = zipUrl {
                print("\tZip:  \(zipUrl)")
                // Launch dfu
                queue.async(group: group) {
                    commandLine.dfuPeripheral(uuid: peripheralIdentifier, zipUrl: zipUrl, ignorePreChecks: ignoreDFUChecks)
                }
            }
            else {
                print("Argument validation error");
                exit(EXIT_FAILURE)
            }
            
            let _ = group.wait(timeout: DispatchTime.distantFuture)

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

            let _ = downloadReleasesSemaphore.wait(timeout: DispatchTime.distantFuture)      // Wait for server download

            guard releases != nil else {
                print("Error downloading updates info from: \(serverUrl)")
                exit(EXIT_FAILURE)
            }

            // Launch dfu
            queue.async(group: group) {
                commandLine.dfuPeripheral(uuid: peripheralIdentifier, releases: releases, ignorePreChecks: ignoreDFUChecks)
            }
            let _ = group.wait(timeout: DispatchTime.distantFuture)
            DLog("update finished")

        default:
            print("Unknown command: \(command.rawValue)")
            break
        }
    } else {
        commandLine.showHelp()
    }

    exit(EXIT_SUCCESS)
}

func createAbsoluteUrlWith(_ pathComponent: String) -> URL? {
    var result: URL?
    
    let isAbsolute = pathComponent.hasPrefix(".") || pathComponent.hasPrefix("/")
    if isAbsolute {
        result = NSURL.fileURL(withPath: pathComponent) 
    }
    else {
        let currentDirectoryUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        result = currentDirectoryUrl.appendingPathComponent(pathComponent)
    }
    
    return result
}

/*
func master(fds: Int32, fdm: Int32) {
    close(fds)

    let input = [CChar](repeatElement(0, count: 150))

    while true {
         // Operator's entry (standard input = terminal)
        let message = "Master sertup\n"
        let messageChar = UnsafePointer<CChar>(message)
        write(1, messageChar, message.characters.count)

        let input2 = UnsafeMutablePointer(mutating: input)
        let rc = read(0, input2, 150)
        if rc > 0 {
            // Send the input to the child process through the PTY 
            write(fdm, input2, rc)

            // Get the child's answer through the PTY 
            let input3 = UnsafeMutablePointer(mutating: input)
            let rc = read(fdm, input3, 150-1)
            if rc > 0 {
                // Make the answer NUL terminated to display it as a string
                input3[rc] = CChar("\0")!

                DLog("-: input")
            }
        }
    }
}
 */

// Disable bufffer
setbuf(stdout, nil)

let runloop = CFRunLoopGetCurrent()
CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue) { () -> Void in
    /*
    var fdm: Int32 = 0
    var fds: Int32 = 0

    // TTY
    if isTtyEnabled {
        
        // Disable bufffer
        setbuf(stdout, nil)
        
        // Open
        fdm = posix_openpt(O_RDWR);
        if (fdm < 0) {
            print(stderr, "Error \(errno) on posix_openpt()\n")
            exit(EXIT_FAILURE)
        }
        
        var rc = grantpt(fdm)
        if rc != 0
        {
            print(stderr, "Error \(errno) on grantpt()\n");
            exit(EXIT_FAILURE)
        }
        
        rc = unlockpt(fdm)
        if rc != 0
        {
            print(stderr, "Error \(errno) on unlockpt()\n");
            exit(EXIT_FAILURE)
        }
        
        // Open the slave side ot the PTY
        fds = open(ptsname(fdm), O_RDWR)
        let name = String(utf8String: UnsafePointer<CChar>(ptsname(fdm)))
        print("The master side is named: \(name ?? "<unknown>")\n")
    }*/

    DispatchQueue(label: "main", attributes: []).async {
        //main(fds: fds, fdm: fdm)
        main()
        CFRunLoopStop(runloop)
    }
    /*
    if isTtyEnabled {
        DispatchQueue(label: "child", attributes: []).async {
            master(fds: fds, fdm: fdm)
            //        CFRunLoopStop(runloop)
        }
    }*/

}
CFRunLoopRun()
