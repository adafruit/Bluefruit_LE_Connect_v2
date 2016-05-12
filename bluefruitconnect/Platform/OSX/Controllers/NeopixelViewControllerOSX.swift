//
//  NeopixelViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class NeopixelViewControllerOSX: NSViewController {

    // Config
    private static let kShouldAutoconnectToNeopixel = true
    
    // Constants
    private static let kUartTimeout = 5.0       // seconds
    
    // UI
    @IBOutlet weak var statusImageView: NSImageView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    
    // Bluetooth Uart
    private let uartData = UartManager.sharedInstance
    private var uartResponseDelegate : ((NSData?)->Void)?
    private var uartResponseTimer : NSTimer?
    
    // Neopixel
    private var isNeopixelSketchAvailable : Bool?
    private var isSendingData = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    deinit {
        cancelUartResponseTimer()
    }

    
    func start() {
        DLog("neopixel start");
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(NeopixelViewControllerOSX.didReceiveData(_:)), name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
    }
    
    func stop() {
        DLog("neopixel stop");
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
        
        cancelUartResponseTimer()
    }
    
    func connectNeopixel() {
        start()
        if NeopixelViewControllerOSX.kShouldAutoconnectToNeopixel {
            self.checkNeopixelSketch()
        }

    }
    
    // MARK: Notifications
    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
             self.connectNeopixel()
            })
    }

    // MARK: - Neopixel Commands
    private func checkNeopixelSketch() {
        
        // Send version command and check if returns a valid response
        DLog("Ask Version...")
        let text = "V"
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            sendDataToUart(data) { [unowned self] responseData in
                var isNeopixelSketchAvailable = false
                if let data = responseData, result = NSString(data:data, encoding: NSUTF8StringEncoding) as? String {
                    isNeopixelSketchAvailable = result.hasPrefix("Neopixel")
                }
 
                DLog("isNeopixelAvailable: \(isNeopixelSketchAvailable)")
                self.isNeopixelSketchAvailable = isNeopixelSketchAvailable
                
                dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                    self.updateUI()
                    });
            }
        }
    }
    
    private func updateUI() {

        var statusText = "Connecting..."
        statusImageView.image = NSImage(named: "NSStatusNone")
        if let isNeopixelSketchAvailable = isNeopixelSketchAvailable {
            statusText = isNeopixelSketchAvailable ? "Neopixel: Ready" : "Neopixel: Not available"
            
            statusImageView.image = NSImage(named: isNeopixelSketchAvailable ?"NSStatusAvailable":"NSImageNameStatusUnavailable")
        }

        statusLabel.stringValue = statusText
        sendButton.enabled = isNeopixelSketchAvailable == true && !isSendingData
    }
    
    
    // MARK: - Uart
    private func sendDataToUart(data: NSData, completionHandler: (response: NSData?)->Void) {
        guard uartResponseDelegate == nil && uartResponseTimer == nil else {
            DLog("sendDataToUart error: waiting for a previous response")
            return
        }
        
        uartResponseTimer = NSTimer.scheduledTimerWithTimeInterval(NeopixelViewControllerOSX.kUartTimeout, target: self, selector: #selector(NeopixelViewControllerOSX.uartResponseTimeout), userInfo: nil, repeats: false)
        uartResponseDelegate = completionHandler
        uartData.sendData(data)
    }
    
    
    func didReceiveData(notification: NSNotification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
            if let uartResponseDelegate = uartResponseDelegate {
                self.uartResponseDelegate = nil
                cancelUartResponseTimer()
                uartResponseDelegate(dataChunk.data)
            }
        }
    }
    
    func uartResponseTimeout() {
        DLog("uartResponseTimeout")
        if let uartResponseDelegate = uartResponseDelegate {
            self.uartResponseDelegate = nil
            cancelUartResponseTimer()
            uartResponseDelegate(nil)
        }
    }
    
    private func cancelUartResponseTimer() {
        uartResponseTimer?.invalidate()
        uartResponseTimer = nil
    }
    
    // MARK: - Actions
    @IBAction func onClickSend(sender: AnyObject) {
        let data = NSMutableData()
        
        let width : UInt8 = 8
        let height : UInt8 = 4
        let command : [UInt8] = [0x44, width, height ]           // Command: 'D', Width: 8, Height: 8
        data.appendBytes(command, length: command.count)

        let redPixel : [UInt8] = [32, 1, 1 ]
        let blackPixel : [UInt8] = [0, 0, 0 ]
        
        var imageData : [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.appendContentsOf(i%2==0 ? redPixel : blackPixel)
        }
        data.appendBytes(imageData, length: imageData.count)
        
        //DLog("Send data: \(hexString(data))")
        /*
        if let message = NSString(data: data, encoding: NSUTF8StringEncoding) {
            DLog("Send data: \(message)")
        }
*/
        
        isSendingData = true
        sendDataToUart(data) { [unowned self] responseData in
            var success = false
            if let data = responseData, result = NSString(data:data, encoding: NSUTF8StringEncoding) as? String {
                success = result.hasPrefix("OK")
                }
            
            DLog("configured: \(success)")
            self.isSendingData = false
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                self.updateUI()
                });
        }
    }
}

// MARK: - DetailTab
extension NeopixelViewControllerOSX : DetailTab {
    func tabWillAppear() {
        uartData.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        if (uartData.isReady()) {
            connectNeopixel()
        }
        else {
            DLog("Wait for uart to be ready to start PinIO setup")
            
            let notificationCenter =  NSNotificationCenter.defaultCenter()
            notificationCenter.addObserver(self, selector: #selector(NeopixelViewControllerOSX.uartIsReady(_:)), name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        }
        
        updateUI()
    }
    
    func tabWillDissapear() {
        stop()
    }
    
    func tabReset() {
    }
}
