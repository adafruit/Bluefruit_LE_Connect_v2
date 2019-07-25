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
    func sendImage(_ image: UIImage) {
        guard let imagePixels32Bit = image.pixelData32bitRGB() else {
            self.delegate?.onImageTransferFinished(error: ImageTransferError.decodeError)
            return
        }
        
        // Convert 32bit color data to 24bit
        let imagePixels24Bit = imagePixels32Bit.enumerated().filter({ index, _ in
            index % 4 != 3
        }).map { $0.1 }
        
        // Command: '!I'
        var command: [UInt8] = [0x21, 0x49]       // ! + Command + width + height
        command.append(contentsOf: UInt16(image.size.width).toBytes)
        command.append(contentsOf: UInt16(image.size.height).toBytes)
        command.append(contentsOf: imagePixels24Bit)
        
        sendCommandWithCrc(command)
    }
    
    private func sendCommandWithCrc(_ command: [UInt8]) {
        var data = Data(bytes: command, count: command.count)
        data.appendCrc()
        sendCommand(data: data)
    }
    
    private func sendCommand(data: Data) {
        
        let kPacketWithResponseEveryPacketCount = 1     // Note: dont use bigger numbers or it will drop packets for big enough images
        uartManager.sendEachPacketSequentially(blePeripheral: blePeripheral, data: data, withResponseEveryPacketCount: kPacketWithResponseEveryPacketCount, progress: { progress in
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
