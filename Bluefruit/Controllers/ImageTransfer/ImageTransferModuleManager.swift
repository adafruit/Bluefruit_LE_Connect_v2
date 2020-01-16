//
//  ImageTransferModuleManager.swift
//  iOS
//
//  Created by Antonio García on 11/06/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation

protocol ImageTransferModuleManagerDelegate: class {
    func onImageTransferUartIsReady(error: Error?)
    func onImageTransferProgress(progress: Float)
    func onImageTransferFinished(error: Error?)
}

class ImageTransferModuleManager: NSObject {
    // Constants
    fileprivate static let kSketchVersion = "ImageTransfer v1."

     // Data structs
    enum ImageTransferError: LocalizedError {
        case decodeError
        
        var errorDescription: String? {
            var result = "<unknown>"
            switch self {
            case .decodeError:
                result = "Decode error"
            }
            
            return result
        }
    }

    // Data
    fileprivate var blePeripheral: BlePeripheral
    fileprivate var uartManager: UartPacketManager!

    // Params
    weak var delegate: ImageTransferModuleManagerDelegate?
    
    // MARK: -
    init(blePeripheral: BlePeripheral, delegate: ImageTransferModuleManagerDelegate) {
        self.blePeripheral = blePeripheral
        self.delegate = delegate
        super.init()
        
        // Init Uart
        uartManager = UartPacketManager(delegate: nil, isPacketCacheEnabled: false, isMqttEnabled: false)
    }
    
    deinit {
        DLog("imagetransfer deinit")
    }
    
    // MARK: - Start / Stop
    func start() {
        DLog("imagetransfer start")
        
        // Enable Uart
        blePeripheral.uartEnable(uartRxHandler: uartManager.rxPacketReceived) { [weak self] error in
            self?.delegate?.onImageTransferUartIsReady(error: error)
        }
    }
    
    func stop() {
        DLog("imagetransfer stop")
        
        blePeripheral.reset()
    }
    
    func isReady() -> Bool {
        return blePeripheral.isUartEnabled()
    }
    
    // MARK: - ImageTransfer Commands
    func sendImage(_ image: UIImage, packetWithResponseEveryPacketCount: Int, isColorSpace24Bit: Bool) {
        guard let imagePixels32Bit = image.pixelData32bitRGB() else {
            self.delegate?.onImageTransferFinished(error: ImageTransferError.decodeError)
            return
        }
        
        let imagePixels: [UInt8]
        if isColorSpace24Bit {
            // Convert 32bit color data to 24bit (888)
            imagePixels = imagePixels32Bit.enumerated().filter({ index, _ in
                index % 4 != 3
            }).map { $0.1 }
        }
        else {
            // Convert 32bit color data to 16bit (565)
            var r: UInt8 = 0, g: UInt8 = 0
            var pixels = [UInt8]()
            
            for (i, value) in imagePixels32Bit.enumerated() {
                let j = i % 4
                if j == 0 {
                    r = value
                }
                else if j == 1 {
                    g = value
                }
                else if j == 2 {
                    let b = value
                    
                    let rgb16 = (UInt16(r & 0xF8) << 8) | (UInt16(g & 0xFC) << 3) | UInt16(b >> 3)
                    pixels.append(contentsOf: rgb16.toBytes)
                }
            }
            
            imagePixels = pixels
        }
        
        // Command: '!I'
        var command: [UInt8] = [0x21, 0x49]       // ! + Command + width + height
        command.append( UInt8(isColorSpace24Bit ? 24:16) )  // Color space 
        command.append(contentsOf: UInt16(image.size.width).toBytes)
        command.append(contentsOf: UInt16(image.size.height).toBytes)
        command.append(contentsOf: imagePixels)
        
        sendCommandWithCrc(command, packetWithResponseEveryPacketCount: packetWithResponseEveryPacketCount)
    }
    
    private func sendCommandWithCrc(_ command: [UInt8], packetWithResponseEveryPacketCount: Int) {
        var data = Data(bytes: command, count: command.count)
        data.appendCrc()
        sendCommand(data: data, packetWithResponseEveryPacketCount: packetWithResponseEveryPacketCount)
    }
    
    private func sendCommand(data: Data, packetWithResponseEveryPacketCount: Int) {
        
//        let kPacketWithResponseEveryPacketCount = 1     // Note: dont use bigger numbers or it will drop packets for big enough images
        uartManager.sendEachPacketSequentially(blePeripheral: blePeripheral, data: data, withResponseEveryPacketCount: packetWithResponseEveryPacketCount, progress: { progress in
            self.delegate?.onImageTransferProgress(progress: progress)
        }) { error in
            DLog("result: \(error ==  nil)")
            self.delegate?.onImageTransferFinished(error: error)
        }
    }
    
    func cancelCurrentSendCommand() {
        uartManager.cancelOngoingSendPacketSequentiallyInMainThread(blePeripheral: blePeripheral)
    }
}
