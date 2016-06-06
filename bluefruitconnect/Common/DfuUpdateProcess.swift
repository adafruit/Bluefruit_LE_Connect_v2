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
        delegate?.onUpdateProgressText("Opening hex file")      // command line doesnt have localizationManager
        //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_hex_message"))
        DataDownloader.downloadDataFromURL(hexUrl) {[weak self] (data) -> Void in
            self?.downloadedFirmwareData(data)
        }
    }
    
    private func downloadedFirmwareData(data: NSData?) {
        // Single hex file needed
        if let data = data {
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let useHexOnly = bootloaderVersion == deviceInfoData!.defaultBootloaderVersion()
            if (useHexOnly) {
                let path = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
                let fileUrl = NSURL.fileURLWithPath(path)
                data.writeToURL(fileUrl, atomically: true)
                startDfuOperation()
            }
            else {
                delegate?.onUpdateProgressText("Opening init file")     // command line doesnt have localizationManager
                //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_init_message"))
                DataDownloader.downloadDataFromURL(iniUrl, withCompletionHandler: {[weak self]  (iniData) -> Void in
                    self?.downloadedFirmwareHexAndInitData(data, iniData: iniData)
                    })
            }
        }
        else {
            showSoftwareDownloadError()
        }
    }
    
    private func downloadedFirmwareHexAndInitData(hexData: NSData?, iniData: NSData?) {
        //  hex + dat file needed
        if (hexData != nil && iniData != nil)
        {
            let hexPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
            let hexFileUrl = NSURL.fileURLWithPath(hexPath)
            let hexDataWritten = hexData!.writeToURL(hexFileUrl, atomically: true)
            if (!hexDataWritten) {
                DLog("Error saving hex file")
            }
            
            let initPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
            let iniFileUrl = NSURL.fileURLWithPath(initPath)
            let initDataWritten = iniData!.writeToURL(iniFileUrl, atomically: true)
            if (!initDataWritten) {
                DLog("Error saving ini file")
            }
            
            startDfuOperation()
        }
        else {
            showSoftwareDownloadError()
        }
    }
    
    private func showSoftwareDownloadError() {
        delegate?.onUpdateProcessError("Software download error", infoMessage: "Please check your internet connection and try again later")
    }
    
    private func startDfuOperation() {
        guard let peripheral = peripheral else {
            DLog("startDfuOperation error: No peripheral defined")
            return
        }
        
        DLog("startDfuOperation");
        isDfuStarted = false
        isDFUCancelled = false
        delegate?.onUpdateProgressText("DFU Init")
        
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
    func onDeviceConnected(peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceConnected");
        isConnected = true
        isDFUVersionExits = false
        dfuVersion = -1
        
    }
    
    func onDeviceConnectedWithVersion(peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceConnectedWithVersion");
        isConnected = true
        isDFUVersionExits = true
        dfuVersion = -1
    }
    
    func onDeviceDisconnected(peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceDisconnected");
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
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delayInSeconds * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) { [unowned self] in
                self.dfuOperations?.connectDevice(peripheral)
            }
        }
    }
    
    func onReadDFUVersion(version: Int32) {
        DLog("DFUOperationsDelegate - onReadDFUVersion: \(version)")
        
        guard dfuOperations != nil && deviceInfoData != nil else {
            onError("Internal error")
            return
        }
        
        dfuVersion = version;
        if (dfuVersion == 1) {
            delegate?.onUpdateProgressText("DFU set bootloader mode")
            dfuOperations!.setAppToBootloaderMode()
        }
        else if (dfuVersion > 1 && !isDFUCancelled && !isDfuStarted)
        {
            // Ready to start
            isDfuStarted = true
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let defaultBootloaderVersion  = deviceInfoData!.defaultBootloaderVersion()
            let useHexOnly = (bootloaderVersion == defaultBootloaderVersion)
            
            DLog("Updating")
            delegate?.onUpdateProgressText("Updating")
            if (useHexOnly)
            {
                let fileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename))
                dfuOperations!.performDFUOnFile(fileURL, firmwareType: APPLICATION)
            }
            else {
                let hexFileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename))
                let iniFileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationIniFilename))
                
                dfuOperations!.performDFUOnFileWithMetaData(hexFileURL, firmwareMetaDataURL: iniFileURL, firmwareType: APPLICATION)
            }
        }
    }
    
    func onDFUStarted() {
        DLog("DFUOperationsDelegate - onDFUStarted")
        isTransferring = true
    }
    
    func onDFUCancelled() {
        DLog("DFUOperationsDelegate - onDFUCancelled")
        
        // Disconnected while updating
        isDFUCancelled = true
        onError("Update cancelled")
    }
    
    func onSoftDeviceUploadStarted() {
        DLog("DFUOperationsDelegate - onSoftDeviceUploadStarted")
        
    }
    
    func onSoftDeviceUploadCompleted() {
        DLog("DFUOperationsDelegate - onBootloaderUploadStarted")
        
    }
    
    func onBootloaderUploadStarted() {
        DLog("DFUOperationsDelegate - onSoftDeviceUploadCompleted")
        
    }
    
    func onBootloaderUploadCompleted() {
        DLog("DFUOperationsDelegate - onBootloaderUploadCompleted")
        
    }
    
    
    func onTransferPercentage(percentage: Int32) {
        DLog("DFUOperationsDelegate - onTransferPercentage: \(percentage)")
        
        if currentTransferPercentage != percentage {
            currentTransferPercentage = percentage
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                self?.delegate?.onUpdateProgressValue(Double(percentage))
                })
        }
    }
    
    func onSuccessfulFileTranferred() {
        DLog("DFUOperationsDelegate - onSuccessfulFileTranferred")
        
        dispatch_async(dispatch_get_main_queue(), {  [weak self] in
            self?.delegate?.onUpdateProcessSuccess()
            })
    }
    
    func onError(errorMessage: String!) {
        
        DLog("DFUOperationsDelegate - onError: \(errorMessage)" )
        
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            self?.delegate?.onUpdateProcessError(errorMessage, infoMessage: nil)
            })
    }
}