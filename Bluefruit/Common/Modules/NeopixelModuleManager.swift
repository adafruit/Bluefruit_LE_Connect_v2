//
//  NeopixelModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 24/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreImage

class NeopixelModuleManager: NSObject {
    // Constants
    static let kDefaultType: UInt16 = 82       // default value: NEO_GRB + NEO_KHZ800
    
    //
    struct Board {
        var name = "<No name>"
        var width: UInt8 = 0, height: UInt8 = 0
        var components: UInt8 = 3
        var stride: UInt8 = 0
        var type: UInt16 = kDefaultType
        
        static func loadStandardBoard(_ standardIndex: Int, type: UInt16 = kDefaultType) -> Board {
            let path = Bundle.main.path(forResource: "NeopixelBoards", ofType: "plist")!
            let boards = NSArray(contentsOfFile: path) as? [[String: AnyObject]]
            
            let boardData = boards![standardIndex]
            let name = boardData["name"] as! String
            let width = UInt8((boardData["width"] as! NSNumber).intValue)
            let height = UInt8((boardData["height"] as! NSNumber).intValue)
            let components = UInt8((boardData["components"] as! NSNumber).intValue)
            let stride = UInt8((boardData["stride"] as! NSNumber).intValue)
            
            let board = NeopixelModuleManager.Board(name: name, width: width, height: height, components: components, stride: stride, type: type)
            return board
        }
    }
    
    // Bluetooth Uart
    fileprivate var uartManager: UartPacketManager!
    fileprivate var blePeripheral: BlePeripheral
  
    // Neopixel
    var isSketchDetected: Bool?
    var board: Board?
    
    init(blePeripheral: BlePeripheral) {
        self.blePeripheral = blePeripheral
        super.init()
        
        // Init Uart
        uartManager = UartPacketManager(delegate: nil, isPacketCacheEnabled: false, isMqttEnabled: false)
    }
    
    deinit {
        DLog("neopixel deinit")
        stop()
    }

    // MARK: - Start / Stop

    func start(uartReadyCompletion:@escaping ((Error?)->(Void))) {
        DLog("neopixel start");


        // Enable Uart
        blePeripheral.uartEnable(uartRxHandler: uartManager.rxPacketReceived) { error in
            uartReadyCompletion(error)
        }
    }
    
    func stop() {
        DLog("neopixel stop")

        blePeripheral.reset()
    }
    
    func isReady() -> Bool {
        return blePeripheral.isUartEnabled()
    }
    
    func isBoardConfigured() -> Bool {
        return board != nil
    }
    
    func connectNeopixel(completion: @escaping ((Bool)->(Void))) {
        self.checkNeopixelSketch(completion: completion)
    }
  
    // MARK: - Neopixel Commands
    private func checkNeopixelSketch(completion: @escaping ((Bool)->(Void))) {
        
        // Send version command and check if returns a valid response
        DLog("Command: get Version")
        
        let command: [UInt8] = [0x56]      // V
        let data = Data(bytes: command, count: command.count)
        
        uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { (data, error) in
            var isSketchDetected = false
            if let data = data as? Data, error == nil, let result = String(data: data, encoding: .utf8) {
                isSketchDetected = result.hasPrefix("Neopixel")
            }
            else if let error = error {
                DLog("Error: checkNeopixelSketch: \(error)")
            }
            
            DLog("isNeopixelAvailable: \(isSketchDetected)")
            self.isSketchDetected = isSketchDetected
            
            completion(isSketchDetected)
        }
    }
    
    func setupNeopixel(device: Board, completion: @escaping ((Bool)->(Void))) {
        DLog("Command: Setup")
//        let pinNumber: UInt8 = 6       // TODO: ask user
        let pixelType: UInt16 = device.type
        
        let command: [UInt8] = [0x53, device.width, device.height, device.components, device.stride, /*pinNumber,*/ UInt8(pixelType), UInt8((UInt(pixelType) >> 8) & 0xff) ]            // Command: 'S'
        let data = Data(bytes: command, count: command.count)
            uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { (data, error) in
            var success = false
            if let data = data as? Data, error == nil, let result = String(data: data, encoding: .utf8) {
                success = result.hasPrefix("OK")
            }
            else if let error = error {
                DLog("Error: setupNeopixel: \(error)")
            }
            
            DLog("setup success: \(success)")
            if success {
                self.board = device
            }
            completion(success)
        }
    }
    
    func resetBoard() {
        board = nil
    }
    
    func setPixelColor(_ color: Color, x: UInt8, y: UInt8, completion: ((Bool)->())? = nil) {
        DLog("Command: set Pixel")
        if board?.components == 3
        {
            let components = colorComponents(color)
            let command: [UInt8] = [0x50, x, y, components.red, components.green, components.blue ]      // Command: 'P'
            sendCommand(command, completion: completion)
        }
    }
    
    func clearBoard(color: Color, completion: ((Bool)->())? = nil) {
        DLog("Command: Clear");
        
        if board?.components == 3
        {
            let components = colorComponents(color)
            let command: [UInt8] = [0x43, components.red, components.green, components.blue ]          // Command: 'C'
            sendCommand(command, completion: completion)
        }
    }
    
    func setBrighness(_ brightness: Float, completion: ((Bool)->())? = nil) {
        DLog("Command: set Brightness: \(brightness)");
        
        let brightnessValue = UInt8(brightness*255)
        let command: [UInt8] = [0x42, brightnessValue ]          // Command: 'C'
        sendCommand(command, completion: completion)
    }
    
    private func colorComponents(_ color: Color) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let colorComponents = color.cgColor.components
        let r = UInt8((colorComponents?[0])! * 255)
        let g = UInt8((colorComponents?[1])! * 255)
        let b = UInt8((colorComponents?[2])! * 255)
        
        return (r, g, b)
    }
    
    func setImage(completion: ((Bool)->())?) {
        DLog("Command: set Image");
    
        // todo: implement
        let width : UInt8 = 8
        let height : UInt8 = 4
        var command : [UInt8] = [0x49]                          // Command: 'I'
        
        let redPixel : [UInt8] = [32, 1, 1 ]
        let blackPixel : [UInt8] = [0, 0, 0 ]
        
        var imageData : [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.append(contentsOf: i%2==0 ? redPixel : blackPixel)
        }
        command.append(contentsOf: imageData)
        
        sendCommand(command, completion: completion)
    }
    
    private func sendCommand(_ command: [UInt8], completion: ((Bool)->())? = nil) {
        let data = Data(bytes: command, count: command.count)
        sendCommand(data: data, completion: completion)
    }
    
    private func sendCommand(data: Data, completion: ((Bool)->())? = nil) {
        guard board != nil else {
            DLog("setImage: unknown board")
            completion?(false)
            return
        }
        
        uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { (data, error) in
            var success = false
            if let data = data as? Data, error == nil, let result = String(data:data, encoding: .utf8) {
                success = result.hasPrefix("OK")
            }
            else if let error = error {
                DLog("Error: sendDataToUart: \(error)")
            }
            
            DLog("result: \(success)")
            completion?(success)
        }
    }
}
