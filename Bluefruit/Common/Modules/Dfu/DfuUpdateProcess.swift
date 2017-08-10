//
//  DfuUpdateProcess.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 09/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

#if COMMANDLINE
#else
    import iOSDFULibrary
#endif

protocol DfuUpdateProcessDelegate: class {
    func onUpdateProcessSuccess()
    func onUpdateProcessError(errorMessage: String, infoMessage: String?)
    func onUpdateProgressText(_ message: String)
    func onUpdateProgressValue(_ progress: Double)
}

class DfuUpdateProcess: NSObject {

    private static let kApplicationHexFilename = "application.hex"
    private static let kApplicationIniFilename = "application.bin"     // don't change extensions. dfuOperations will look for these specific extensions

    // Parameters
    weak var delegate: DfuUpdateProcessDelegate?

    fileprivate var dfuController: DFUServiceController?

    func startUpdateForPeripheral(peripheral: CBPeripheral, hexUrl: URL, iniUrl: URL?) {

        let firmware = DFUFirmware(urlToBinOrHexFile: hexUrl, urlToDatFile: iniUrl, type: .application)

        guard let selectedFirmware = firmware, selectedFirmware.valid else {
            delegate?.onUpdateProcessError(errorMessage: "Firmware files not valid", infoMessage: nil)
            return
        }

        guard let centralManager = BleManager.sharedInstance.centralManager else {
            delegate?.onUpdateProcessError(errorMessage: "Bluetooth not ready", infoMessage: nil)
            return
        }
        let initiator = DFUServiceInitiator(centralManager: centralManager, target: peripheral).with(firmware: selectedFirmware)

        // Optional:
        // initiator.forceDfu = true/false; // default false
        // initiator.packetReceiptNotificationParameter = N; // default is 12
        initiator.logger = self; // - to get log info
        initiator.delegate = self; // - to be informed about current state and errors
        initiator.progressDelegate = self; // - to show progress bar
        // initiator.peripheralSelector = ... // the default selector is used

        dfuController = initiator.start()
    }
    
    
    func startUpdateForPeripheral(peripheral: CBPeripheral, zipUrl: URL) {
        let firmware = DFUFirmware(urlToZipFile: zipUrl)
        
        guard let selectedFirmware = firmware, selectedFirmware.valid else {
            delegate?.onUpdateProcessError(errorMessage: "Firmware files not valid", infoMessage: nil)
            return
        }
        
        guard let centralManager = BleManager.sharedInstance.centralManager else {
            delegate?.onUpdateProcessError(errorMessage: "Bluetooth not ready", infoMessage: nil)
            return
        }
        let initiator = DFUServiceInitiator(centralManager: centralManager, target: peripheral).with(firmware: selectedFirmware)

        // Optional:
        // initiator.forceDfu = true/false; // default false
        // initiator.packet1ReceiptNotificationParameter = N; // default is 12
        initiator.logger = self; // - to get log info
        initiator.delegate = self; // - to be informed about current state and errors
        initiator.progressDelegate = self; // - to show progress bar
        // initiator.peripheralSelector = ... // the default selector is used
        
        dfuController = initiator.start()
    }

    func cancel() {
        // Cancel current operation
        let aborted = dfuController?.abort()
        DLog("Aborted: \(aborted ?? false)")
        delegate?.onUpdateProcessError(errorMessage: "Update cancelled", infoMessage: nil)
    }
}

extension DfuUpdateProcess: LoggerDelegate {
    func logWith(_ level: LogLevel, message: String) {
        DLog("DFU: \(message)")
    }
}

extension DfuUpdateProcess: DFUServiceDelegate {
    func dfuStateDidChange(to state: DFUState) {
        let message = state.description()
        delegate?.onUpdateProgressText(message)

        if state == .completed {
            DLog("Dfu completed")
            delegate?.onUpdateProcessSuccess()
        } else if state == .aborted {
            DLog("Dfu aborted")
            delegate?.onUpdateProcessError(errorMessage: "Update aborted", infoMessage: nil)
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        delegate?.onUpdateProcessError(errorMessage: message, infoMessage: nil)
    }
}

extension DfuUpdateProcess: DFUProgressDelegate {
    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        let progress =  Double(progress)/Double(totalParts) + (Double(part)-1)/Double(totalParts)      // [0 - 100]
        delegate?.onUpdateProgressValue(progress)
    }
}
