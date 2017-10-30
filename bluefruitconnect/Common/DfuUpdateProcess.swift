//
//  DfuUpdateProcess.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 09/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol DfuUpdateProcessDelegate: class {
    func onUpdateProcessSuccess()
    func onUpdateProcessError(errorMessage: String, infoMessage: String?)
    func onUpdateProgressText(message: String)
    func onUpdateProgressValue(progress: Double)
}

class DfuUpdateProcess : NSObject {
    
    private static let kApplicationHexFilename = "application.hex"
    private static let kApplicationIniFilename = "application.bin"     // don't change extensions. dfuOperations will look for these specific extensions
    
    // Parameters
    private var peripheral: CBPeripheral?
    private var hexUrl: NSURL?
    private var iniUrl: NSURL?
    private var deviceInfoData : DeviceInfoData?
    weak var delegate: DfuUpdateProcessDelegate?
    
    // DFU data
    private var dfuOperations : DFUOperations?
    private var isDfuStarted = false
    private var isDFUCancelled = false
    
    private var isConnected = false
    private var isDFUVersionExits = false
    private var isTransferring  = false
    private var dfuVersion: Int32 = -1
    
    private var currentTransferPercentage: Int32 = -1
    
    func startUpdateForPeripheral(peripheral: CBPeripheral, hexUrl: NSURL, iniUrl: NSURL?, deviceInfoData: DeviceInfoData) {
        self.peripheral = peripheral
        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.deviceInfoData = deviceInfoData
        currentTransferPercentage = -1
        
        dfuOperations = DFUOperations(delegate: self)
        
        // Download files
        delegate?.onUpdateProgressText(message: "Opening hex file")      // command line doesnt have localizationManager
        //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_hex_message"))
        
        DataDownloader.downloadData(from: hexUrl as URL) { [weak self] (data) in
            self?.downloadedFirmwareData(data: data)
        }
    }
    
    private func downloadedFirmwareData(data: Data?) {
        // Single hex file needed
        guard let data = data else {
            showSoftwareDownloadError()
            return
        }
        
        let bootloaderVersion = deviceInfoData!.bootloaderVersion()
        let useHexOnly = bootloaderVersion == deviceInfoData!.defaultBootloaderVersion()
        if (useHexOnly) {
            let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
            do { try data.write(to: fileUrl, options: .atomicWrite) } catch { onError(error.localizedDescription) }
            startDfuOperation()
        }
        else {
            delegate?.onUpdateProgressText(message: "Opening init file")     // command line doesnt have localizationManager
            //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_init_message"))
            
            guard let iniUrl = self.iniUrl else {
                DLog(message: "Error iniUrl is empty")
                return
            }
            
            DataDownloader.downloadData(from: iniUrl as URL, withCompletionHandler: {[weak self]  (iniData) -> Void in
                self?.downloadedFirmwareHexAndInitData(hexData: data, iniData: iniData)
                })
        }
    }
    
    private func downloadedFirmwareHexAndInitData(hexData: Data?, iniData: Data?) {
        //  hex + dat file needed
        guard let hexData = hexData, let iniData = iniData else {
            showSoftwareDownloadError()
            return
        }
        
        let hexPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
        let hexFileUrl = NSURL.fileURL(withPath: hexPath)
        
        do {
            try hexData.write(to: hexFileUrl, options: .atomicWrite)
        } catch { DLog(message: "Error saving hex file. Original error: \(error.localizedDescription)")}
        
        let initPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
        let iniFileUrl = NSURL.fileURL(withPath: initPath)
        
        do {
            try iniData.write(to: iniFileUrl, options: .atomicWrite)
        } catch { DLog(message: "Error saving ini file. Original error: \(error.localizedDescription)") }
        
        startDfuOperation()
    }
    
    private func showSoftwareDownloadError() {
        delegate?.onUpdateProcessError(errorMessage: "Software download error", infoMessage: "Please check your internet connection and try again later")
    }
    
    private func startDfuOperation() {
        guard let peripheral = peripheral else {
            DLog(message: "startDfuOperation error: No peripheral defined")
            return
        }
        
        DLog(message: "startDfuOperation");
        isDfuStarted = false
        isDFUCancelled = false
        delegate?.onUpdateProgressText(message: "DFU Init")
        
        // Files should be ready at NSTemporaryDirectory/application.hex (and application.dat if needed)
        if let centralManager = BleManager.sharedInstance.centralManager {
            //            BleManager.sharedInstance.stopScan()
            
            dfuOperations = DFUOperations(delegate: self)
            dfuOperations!.setCentralManager(centralManager)
            dfuOperations!.connectDevice(peripheral)
        }
    }
    
    /*
    func startDfuOperationBypassingChecksWithPeripheral(peripheral: CBPeripheral, hexData: NSData, iniData: NSData?) -> Bool {
        // This funcion bypass all checks and start the dfu operation with the data provided. Used by the command line app
        
        // Set peripheral
        self.peripheral = peripheral
        
        // Simulate deviceInfoData. Fake the bootloaderversion to the defaultBootloaderVersion if only an hex file is provided or a newer version if both hex and ini files are provided
        deviceInfoData = DeviceInfoData()
        if iniData != nil {
            deviceInfoData?.firmwareRevision = ", 1.0"
        }
        
        // Copy files to where dfu will read them
        let hexPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
        let hexFileUrl = NSURL.fileURLWithPath(hexPath)
        let hexDataWritten = hexData.writeToURL(hexFileUrl, atomically: true)
        if (!hexDataWritten) {
            DLog("Error saving hex file")
            return false
        }
        
        if let iniData = iniData {
            let initPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
            let iniFileUrl = NSURL.fileURLWithPath(initPath)
            let initDataWritten = iniData.writeToURL(iniFileUrl, atomically: true)
            if (!initDataWritten) {
                DLog("Error saving ini file")
                return false
            }
        }

        startDfuOperation()
        return true
    }
    */
    
    func cancel() {
        // Cancel current operation
        dfuOperations?.cancelDFU()
    }
}

// MARK: - DFUOperationsDelegate
extension DfuUpdateProcess : DFUOperationsDelegate {
    func onDeviceConnected(_ peripheral: CBPeripheral) {
        DLog(message: "DFUOperationsDelegate - onDeviceConnected");
        isConnected = true
        isDFUVersionExits = false
        dfuVersion = -1
        
    }
    
    func onDeviceConnected(withVersion: CBPeripheral) {
        DLog(message: "DFUOperationsDelegate - onDeviceConnectedWithVersion");
        isConnected = true
        isDFUVersionExits = true
        dfuVersion = -1
    }
    
    func onDeviceDisconnected(_ peripheral: CBPeripheral!) {
        DLog(message: "DFUOperationsDelegate - onDeviceDisconnected");
        if (dfuVersion != 1) {
            isTransferring = false
            isConnected = false
            
            if (dfuVersion == 0)
            {
                onError("The legacy bootloader on this device is not compatible with this application")
            }
            else
            {
                onError("Update error")
            }
        }
        else {
            let delayInSeconds = 3.0;
            // dispatch_time(DISPATCH_TIME_NOW, Int64(delayInSeconds * Double(NSEC_PER_SEC)))
            let delayTime = DispatchTime.now() + (delayInSeconds * Double(NSEC_PER_SEC))
            DispatchQueue.main.asyncAfter(deadline: delayTime){ [unowned self] in
                self.dfuOperations?.connectDevice(peripheral)
            }
        }
    }
    
    func onReadDFUVersion(_ version: Int32) {
        DLog(message: "DFUOperationsDelegate - onReadDFUVersion: \(version)")
        
        guard dfuOperations != nil && deviceInfoData != nil else {
            onError("Internal error")
            return
        }
        
        dfuVersion = version;
        if (dfuVersion == 1) {
            delegate?.onUpdateProgressText(message: "DFU set bootloader mode")
            dfuOperations!.setAppToBootloaderMode()
        }
        else if (dfuVersion > 1 && !isDFUCancelled && !isDfuStarted)
        {
            // Ready to start
            isDfuStarted = true
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let defaultBootloaderVersion  = deviceInfoData!.defaultBootloaderVersion()
            let useHexOnly = (bootloaderVersion == defaultBootloaderVersion)
            
            DLog(message: "Updating")
            delegate?.onUpdateProgressText(message: "Updating")
            if (useHexOnly)
            {
                let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
                dfuOperations!.performDFU(onFile: fileURL, firmwareType: APPLICATION)
            }
            else {
                let hexFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
                let iniFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
                
                dfuOperations!.performDFUOnFile(withMetaData: hexFileURL, firmwareMetaDataURL: iniFileURL, firmwareType: APPLICATION)
            }
        }
    }
    
    func onDFUStarted() {
        DLog(message: "DFUOperationsDelegate - onDFUStarted")
        isTransferring = true
    }
    
    func onDFUCancelled() {
        DLog(message: "DFUOperationsDelegate - onDFUCancelled")
        
        // Disconnected while updating
        isDFUCancelled = true
        onError("Update cancelled")
    }
    
    func onSoftDeviceUploadStarted() {
        DLog(message: "DFUOperationsDelegate - onSoftDeviceUploadStarted")
        
    }
    
    func onSoftDeviceUploadCompleted() {
        DLog(message: "DFUOperationsDelegate - onBootloaderUploadStarted")
        
    }
    
    func onBootloaderUploadStarted() {
        DLog(message: "DFUOperationsDelegate - onSoftDeviceUploadCompleted")
        
    }
    
    func onBootloaderUploadCompleted() {
        DLog(message: "DFUOperationsDelegate - onBootloaderUploadCompleted")
        
    }
    
    
    func onTransferPercentage(_ percentage: Int32) {
        DLog(message: "DFUOperationsDelegate - onTransferPercentage: \(percentage)")
        
        if currentTransferPercentage != percentage {
            currentTransferPercentage = percentage
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.onUpdateProgressValue(progress: Double(percentage))
                }
        }
    }
    
    func onSuccessfulFileTranferred() {
        DLog(message: "DFUOperationsDelegate - onSuccessfulFileTranferred")
        
        DispatchQueue.main.async {  [weak self] in
            self?.delegate?.onUpdateProcessSuccess()
            }
    }
    
    func onError(_ errorMessage: String!) {
        
        DLog(message: "DFUOperationsDelegate - onError: \(errorMessage)" )
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onUpdateProcessError(errorMessage: errorMessage, infoMessage: nil)
            }
    }
}
