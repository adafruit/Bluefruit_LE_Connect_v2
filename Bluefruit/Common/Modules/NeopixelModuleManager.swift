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
//    static let kDefaultComponentValue: UInt16 = 82       // default value: NEO_GRB + NEO_KHZ800
    fileprivate static let kSketchVersion = "Neopixel v2."

    //
    enum Components {
        case rgb
        case rbg
        case grb
        case gbr
        case brg
        case bgr

        case wrgb
        case wrbg
        case wgrb
        case wgbr
        case wbrg
        case wbgr

        case rwgb
        case rwbg
        case rgwb
        case rgbw
        case rbwg
        case rbgw

        case gwrb
        case gwbr
        case grwb
        case grbw
        case gbwr
        case gbrw

        case bwrg
        case bwgr
        case brwg
        case brgw
        case bgwr
        case bgrw

        var value: UInt8 {
            switch self {
            // Offset:         W          R          G          B
            case .rgb: return  ((0 << 6) | (0 << 4) | (1 << 2) | (2))
            case .rbg: return ((0 << 6) | (0 << 4) | (2 << 2) | (1))
            case .grb: return  ((1 << 6) | (1 << 4) | (0 << 2) | (2))
            case .gbr: return  ((2 << 6) | (2 << 4) | (0 << 2) | (1))
            case .brg: return  ((1 << 6) | (1 << 4) | (2 << 2) | (0))
            case .bgr: return  ((2 << 6) | (2 << 4) | (1 << 2) | (0))

                // RGBW NeoPixel permutations; all 4 offsets are distinct
            // Offset:         W          R          G          B
            case .wrgb: return ((0 << 6) | (1 << 4) | (2 << 2) | (3))
            case .wrbg: return ((0 << 6) | (1 << 4) | (3 << 2) | (2))
            case .wgrb: return ((0 << 6) | (2 << 4) | (1 << 2) | (3))
            case .wgbr: return ((0 << 6) | (3 << 4) | (1 << 2) | (2))
            case .wbrg: return ((0 << 6) | (2 << 4) | (3 << 2) | (1))
            case .wbgr: return ((0 << 6) | (3 << 4) | (2 << 2) | (1))

            case .rwgb: return ((1 << 6) | (0 << 4) | (2 << 2) | (3))
            case .rwbg: return ((1 << 6) | (0 << 4) | (3 << 2) | (2))
            case .rgwb: return ((2 << 6) | (0 << 4) | (1 << 2) | (3))
            case .rgbw: return ((3 << 6) | (0 << 4) | (1 << 2) | (2))
            case .rbwg: return ((2 << 6) | (0 << 4) | (3 << 2) | (1))
            case .rbgw: return ((3 << 6) | (0 << 4) | (2 << 2) | (1))

            case .gwrb: return ((1 << 6) | (2 << 4) | (0 << 2) | (3))
            case .gwbr: return ((1 << 6) | (3 << 4) | (0 << 2) | (2))
            case .grwb: return ((2 << 6) | (1 << 4) | (0 << 2) | (3))
            case .grbw: return ((3 << 6) | (1 << 4) | (0 << 2) | (2))
            case .gbwr: return ((2 << 6) | (3 << 4) | (0 << 2) | (1))
            case .gbrw: return ((3 << 6) | (2 << 4) | (0 << 2) | (1))

            case .bwrg: return ((1 << 6) | (2 << 4) | (3 << 2) | (0))
            case .bwgr: return ((1 << 6) | (3 << 4) | (2 << 2) | (0))
            case .brwg: return ((2 << 6) | (1 << 4) | (3 << 2) | (0))
            case .brgw: return ((3 << 6) | (1 << 4) | (2 << 2) | (0))
            case .bgwr: return ((2 << 6) | (3 << 4) | (1 << 2) | (0))
            case .bgrw: return ((3 << 6) | (2 << 4) | (1 << 2) | (0))
            }
        }

        var numComponents: Int {
            switch self {
            case .rgb, .rbg, .grb, .gbr, .brg, .bgr: return 3
            default: return 4
            }
        }

        var name: String {
            switch self {
            case .rgb: return "RGB"
            case .rbg: return "RBG"
            case .grb: return "GRB"
            case .gbr: return "GBR"
            case .brg: return "BRG"
            case .bgr: return "BGR"

            case .wrgb: return "WRGB"
            case .wrbg: return "WRBG"
            case .wgrb: return "WGRB"
            case .wgbr: return "WGBR"
            case .wbrg: return "WBRG"
            case .wbgr: return "WBGR"

            case .rwgb: return "RWGB"
            case .rwbg: return "RWBG"
            case .rgwb: return "RGWB"
            case .rgbw: return "RGBW"
            case .rbwg: return "RBWG"
            case .rbgw: return "RBGW"

            case .gwrb: return "GWRB"
            case .gwbr: return "GWBR"
            case .grwb: return "GRWB"
            case .grbw: return "GRBW"
            case .gbwr: return "GBWR"
            case .gbrw: return "GBRW"

            case .bwrg: return "BWRG"
            case .bwgr: return "BWGR"
            case .brwg: return "BRWG"
            case .brgw: return "BRGW"
            case .bgwr: return "BGWR"
            case .bgrw: return "BGRW"
            }
        }

        static var all: [Components] {
            return [ .rgb, .rbg, .grb, .gbr, .bgr, .wrgb, .wrbg, .wgrb, .wgbr, .wbrg, .wbgr, .rwgb, .rwbg, .rgwb, .rgbw, .rbwg, .rbgw, .gwrb, .gwbr, .grwb, .grbw, .gbwr, .gbrw, .bwrg, .bwgr, .brwg, .brgw, .bgwr, .bgrw]
        }
    }

    struct Board {
        var name = "<No name>"
        var width: UInt8 = 0, height: UInt8 = 0
        var stride: UInt8 = 0

        static func loadStandardBoard(_ standardIndex: Int) -> Board? {
            let path = Bundle.main.path(forResource: "NeopixelBoards", ofType: "plist")!
            guard let boards = NSArray(contentsOfFile: path) as? [[String: AnyObject]] else { DLog("Error: cannot load boards"); return nil }

            let boardData = boards[standardIndex]
            let name = boardData["name"] as! String
            let width = UInt8((boardData["width"] as! NSNumber).intValue)
            let height = UInt8((boardData["height"] as! NSNumber).intValue)
            let stride = UInt8((boardData["stride"] as! NSNumber).intValue)

            let board = NeopixelModuleManager.Board(name: name, width: width, height: height, stride: stride)
            return board
        }
    }

    // Bluetooth Uart
    fileprivate var uartManager: UartPacketManager!
    fileprivate var blePeripheral: BlePeripheral

    // Neopixel
    var isSketchDetected: Bool?
    fileprivate var board: Board?
    fileprivate var components = Components.grb
    fileprivate var is400HzEnabled = false

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
    func start(uartReadyCompletion:@escaping ((Error?) -> Void)) {
        DLog("neopixel start")

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

    func connectNeopixel(completion: @escaping ((Bool) -> Void)) {
        self.checkNeopixelSketch(completion: completion)
    }

    // MARK: - Neopixel Commands
    private func checkNeopixelSketch(completion: @escaping ((Bool) -> (Void))) {

        // Send version command and check if returns a valid response
        DLog("Command: get Version")

        let command: [UInt8] = [0x56]      // V
        let data = Data(bytes: command, count: command.count)

        isSketchDetected = nil      // Reset status
        uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { (data, error) in
            var isSketchDetected = false
            if let data = data as? Data, error == nil, let result = String(data: data, encoding: .utf8) {
                if result.hasPrefix(NeopixelModuleManager.kSketchVersion) {
                    isSketchDetected = true
                } else {
                    DLog("Error: sketch wrong version: \(result). Expecting: \(NeopixelModuleManager.kSketchVersion)")
                }
            } else if let error = error {
                DLog("Error: checkNeopixelSketch: \(error)")
            }

            DLog("isNeopixelAvailable: \(isSketchDetected)")
            self.isSketchDetected = isSketchDetected

            completion(isSketchDetected)
        }
    }

    func setupNeopixel(board device: Board, components: Components, is400HzEnabled: Bool, completion: @escaping ((Bool) -> Void)) {
        DLog("Command: Setup")
//        let pinNumber: UInt8 = 6       // TODO: ask user

        let command: [UInt8] = [0x53, device.width, device.height, device.stride, components.value, is400HzEnabled ? 1:0]            // Command: 'S'
        let data = Data(bytes: command, count: command.count)
        uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { [weak self] (data, error) in
            guard let context = self else { completion(false); return }

            var success = false
            if let data = data as? Data, error == nil, let result = String(data: data, encoding: .utf8) {
                success = result.hasPrefix("OK")
            } else if let error = error {
                DLog("Error: setupNeopixel: \(error)")
            }

            DLog("setup success: \(success)")
            if success {
                context.board = device
                context.components = components
                context.is400HzEnabled = is400HzEnabled
            }
            completion(success)
        }
    }

    func resetBoard() {
        board = nil
    }

    func setPixelColor(_ color: Color, colorW: Float, x: UInt8, y: UInt8, completion: ((Bool) -> Void)? = nil) {
        DLog("Command: set Pixel")
        guard components.numComponents == 3 || components.numComponents == 4 else { DLog("Error: unsupported numComponents: \(components.numComponents)"); return }

        let rgb = colorComponents(color)
        var command: [UInt8] = [0x50, x, y, rgb.red, rgb.green, rgb.blue ]      // Command: 'P'
        if components.numComponents == 4 {
            let colorWValue = UInt8(colorW*255)
            command.append(colorWValue)
        }
        sendCommand(command, completion: completion)
    }

    func clearBoard(color: Color, colorW: Float, completion: ((Bool) -> Void)? = nil) {
        DLog("Command: Clear")
        guard components.numComponents == 3 || components.numComponents == 4 else { DLog("Error: unsupported numComponents: \(components.numComponents)"); return }

        let rgb = colorComponents(color)
        var command: [UInt8] = [0x43, rgb.red, rgb.green, rgb.blue]                 // Command: 'C'
        if components.numComponents == 4 {
            let colorWValue = UInt8(colorW*255)
            command.append(colorWValue)
        }
        sendCommand(command, completion: completion)
    }

    func setBrighness(_ brightness: Float, completion: ((Bool) -> Void)? = nil) {
        DLog("Command: set Brightness: \(brightness)")

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

    func setImage(completion: ((Bool) -> Void)?) {
        DLog("Command: set Image")

        // TODO: implement
        let width: UInt8 = 8
        let height: UInt8 = 4
        var command: [UInt8] = [0x49]                          // Command: 'I'

        let redPixel: [UInt8] = [32, 1, 1 ]
        let blackPixel: [UInt8] = [0, 0, 0 ]

        var imageData: [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.append(contentsOf: i%2==0 ? redPixel : blackPixel)
        }
        command.append(contentsOf: imageData)

        sendCommand(command, completion: completion)
    }

    private func sendCommand(_ command: [UInt8], completion: ((Bool) -> Void)? = nil) {
        let data = Data(bytes: command, count: command.count)
        sendCommand(data: data, completion: completion)
    }

    private func sendCommand(data: Data, completion: ((Bool) -> Void)? = nil) {
        guard board != nil else {
            DLog("setImage: unknown board")
            completion?(false)
            return
        }

        uartManager.sendAndWaitReply(blePeripheral: blePeripheral, data: data) { (data, error) in
            var success = false
            if let data = data as? Data, error == nil, let result = String(data:data, encoding: .utf8) {
                success = result.hasPrefix("OK")
            } else if let error = error {
                DLog("Error: sendDataToUart: \(error)")
            }

            DLog("result: \(success)")
            completion?(success)
        }
    }
}
