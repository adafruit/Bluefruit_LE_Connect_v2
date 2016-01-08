//
//  UpdateDialogViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

protocol UpdateDialogViewControlerDelegate {
    func onUpdateDialogCancel()
    func onUpdateDialogSuccess()
    func onUpdateDialogError(errorMessage : String)
}

class UpdateDialogViewController: NSViewController {

    @IBOutlet private weak var progressLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressPercentageLabel: NSTextField!
    
    private static let kApplicationHexFilename = "application.hex"
    private static let kApplicationIniFilename = "application.bin"     // don't change extensions. dfuOperations will look for these specific extensions
    
    // Parameters
    private var peripheral : CBPeripheral?
    private var hexUrl : NSURL?
    private var iniUrl : NSURL?
    private var deviceInfoData : DeviceInfoData?
    var delegate : UpdateDialogViewControlerDelegate?
    
    // DFU data
    private var dfuOperations : DFUOperations?
    private var isDfuStarted = false
    private var isDFUCancelled = false
    
    private var isConnected = false
    private var isDFUVersionExits = false
    private var isTransferring  = false
    private var dfuVersion : Int32 = -1

    
    func setUpdateParameters(peripheral : CBPeripheral, hexUrl : NSURL, iniUrl: NSURL?, deviceInfoData : DeviceInfoData) {
        self.peripheral = peripheral
        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.deviceInfoData = deviceInfoData
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Note: parameters should be set before this method is called
        guard peripheral != nil && hexUrl != nil && deviceInfoData != nil
        else {
            DLog("Error: update parameters not set")
            return
        }
        
        dfuOperations = DFUOperations(delegate: self)
        
        // Download files
        setProgressText("Downloading hex file")
        FirmwareUpdater.downloadDataFromURL(hexUrl) {[weak self] (data) -> Void in
            self?.downloadedFirmwareData(data)
        }
        
        // Setup StatusManager
        StatusManager.sharedInstance.updateDialogViewController = self
    }
    
    func setProgressText(text : String) {
        progressLabel.stringValue = text
    }
    
    func setProgress(value : Double) {
        progressIndicator.indeterminate = false
        progressIndicator.doubleValue = value
        progressPercentageLabel.stringValue = String(format: "%1.0f%%", value);
    }
    
    func downloadedFirmwareData(data : NSData?) {
        // Single hex file needed
        if let data = data {
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let useHexOnly = bootloaderVersion == deviceInfoData!.defaultBootloaderVersion()
            if (useHexOnly) {
                let path = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationHexFilename)
                let fileUrl = NSURL.fileURLWithPath(path)
                data.writeToURL(fileUrl, atomically: true)
                startDfuOperation()
            }
            else {
                setProgressText("Downloading init file")
                FirmwareUpdater.downloadDataFromURL(iniUrl, withCompletionHandler: {[weak self]  (iniData) -> Void in
                    self?.downloadedFirmwareHexAndInitData(data, iniData: iniData)
                })
            }
        }
        else {
            showSoftwareDownloadError()
        }
    }
    
    func downloadedFirmwareHexAndInitData(hexData: NSData?, iniData:NSData?) {
        //  hex + dat file needed
        if (hexData != nil && iniData != nil)
        {
            let hexPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationHexFilename)
            let hexFileUrl = NSURL.fileURLWithPath(hexPath)
            let hexDataWritten = hexData!.writeToURL(hexFileUrl, atomically: true)
            if (!hexDataWritten) {
                DLog("Error saving hex file")
            }
            
            let initPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationIniFilename)
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
    
    
    func showSoftwareDownloadError() {
        let alert = NSAlert()
        alert.messageText = "Software download error"
        alert.informativeText = "Please check your internet connection and try again later"
        alert.addButtonWithTitle("Ok")
        alert.alertStyle = .WarningAlertStyle
        
        alert.beginSheetModalForWindow(self.view.window!, completionHandler: { [unowned self](modalResponse) -> Void in
            if (modalResponse == NSAlertFirstButtonReturn) {
                self.dismissViewController(self)
            }
            })
    }
    
    func startDfuOperation() {
        isDfuStarted = false
        isDFUCancelled = false
        setProgressText("DFU Init")
        
         // Files should be ready at NSTemporaryDirectory/application.hex (and application.dat if needed)
        if let centralManager = BleManager.sharedInstance.centralManager {
//            BleManager.sharedInstance.stopScan()
            
            dfuOperations!.setCentralManager(centralManager)
            dfuOperations!.connectDevice(peripheral)
        }
    }
  
    
    @IBAction func onClickCancel(sender: AnyObject) {
        // Cancel current operation
        dfuOperations!.cancelDFU()
        
        
        // Dismiss
        if let delegate = self.delegate {
            delegate.onUpdateDialogCancel()
        }
    }
}

// MARK: - DFUOperationsDelegate
extension UpdateDialogViewController : DFUOperationsDelegate {
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
            setProgressText("DFU set bootloader mode")
            dfuOperations!.setAppToBootloaderMode()
        }
        else if (dfuVersion > 1 && !isDFUCancelled && !isDfuStarted)
        {
            // Ready to start
            isDfuStarted = true
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let defaultBootloaderVersion  = deviceInfoData!.defaultBootloaderVersion()
            let useHexOnly = (bootloaderVersion == defaultBootloaderVersion)
            
            setProgressText("Updating")
            if (useHexOnly)
            {
                let fileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationHexFilename))
                dfuOperations!.performDFUOnFile(fileURL, firmwareType:APPLICATION)
            }
            else {
                let hexFileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationHexFilename))
                let iniFileURL = NSURL(fileURLWithPath: (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(UpdateDialogViewController.kApplicationIniFilename))
                
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
        
        dispatch_async(dispatch_get_main_queue(), {
            self.setProgress(Double(percentage))
        })
    }
    
    func onSuccessfulFileTranferred() {
        DLog("DFUOperationsDelegate - onSuccessfulFileTranferred")
        
        dispatch_async(dispatch_get_main_queue(), {
            self.dismissViewController(self)
            if let delegate = self.delegate {
                delegate.onUpdateDialogSuccess()
            }
        })
    }
    
    func onError(errorMessage: String!) {
        
        DLog("DFUOperationsDelegate - onError: \(errorMessage)" )
        
        dispatch_async(dispatch_get_main_queue(), {
            self.dismissViewController(self)
            if let delegate = self.delegate {
                delegate.onUpdateDialogError(errorMessage)
            }
        })

    }
}
