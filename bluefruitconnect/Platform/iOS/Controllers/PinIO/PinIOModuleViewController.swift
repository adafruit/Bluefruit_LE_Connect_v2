//
//  PinIOModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PinIOModuleViewController: ModuleViewController {

    // Constants
    private let SYSEX_START: UInt8 = 0xF0
    private let SYSEX_END: UInt8 = 0xF7
    private let CAPABILITY_QUERY_TIMEOUT = 5.0

    private let DEFAULT_CELL_COUNT = 20
    private let LAST_DIGITAL_PIN = 8
    private let FIRST_ANALOG_PIN = 14

    
    private let DIGITAL_PIN_SECTION = 0
    private let ANALOG_PIN_SECTION = 1
    private let FIRST_DIGITAL_PIN = 3
    private let LAST_ANALOG_PIN = 19
    private let PORT_COUNT = 3


    // Types
    enum UartStatus {
        case SendData           // Default mode
        case QueryCapabilities
        case QueryAnalogMapping
    }
    
    struct PinData {
        enum Mode {
            case Unknown
            case Input
            case Output
            case Analog
            case PWM
            case Servo
        }
        
        enum Output {
            case Low
            case High
        }
        
        var pinId: UInt8
        var pinNumber: UInt8
        var isDigital: Bool
        
        var mode: Mode
        var output: Output
        var pmw = 0
    }
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private var tableRowOpen: Int?
    
    // Data
    private var uartStatus = UartStatus.SendData
    private var queryCapabilitiesTimer : NSTimer?
    
    private var pins = [PinData]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        reset()
        startQueryCapabilitiesProcess()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "didReceiveData:", name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
        
        cancelQueryCapabilitiesTimer()
    }
    
    private func reset() {
        uartStatus == .SendData
        
        // Reset Firmata
        let bytes:[UInt8] = [0xff]
        let data = NSData(bytes: bytes, length: bytes.count)
        UartManager.sharedInstance.sendData(data)
    }
    

    // MARK: - Query Capabilities
    private func startQueryCapabilitiesProcess() {
        guard uartStatus == .SendData else {
            DLog("error: queryCapabilities with status=\(uartStatus)")
            return
        }
        
        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("pinio_capabilityquery_querying_title"), preferredStyle: .Alert)
        
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .Cancel, handler: { [unowned self] (_) -> Void in
            self.endPinQuery()
        }))
        
        self.presentViewController(alertController, animated: true) {[unowned self] () -> Void in
            // Query Capabilities
            self.queryCapabilities()
        }
    }
 
    private var queryCapabilitiesDataBuffer = [UInt8]()
    private func queryCapabilities() {
        // Set status
        self.uartStatus = .QueryCapabilities
        self.queryCapabilitiesDataBuffer.removeAll()
        
        // Query Capabilities
        let bytes:[UInt8] = [self.SYSEX_START, 0x6B, self.SYSEX_END]
        let data = NSData(bytes: bytes, length: bytes.count)
        
        UartManager.sharedInstance.sendData(data)
        self.queryCapabilitiesTimer = NSTimer.scheduledTimerWithTimeInterval(self.CAPABILITY_QUERY_TIMEOUT, target: self, selector: "cancelQueryCapabilities", userInfo: nil, repeats: false)
    }
    
    private func receivedQueryCapabilities(data: NSData) {
        cancelQueryCapabilitiesTimer()
        
        // Read received packet
        var dataBytes = [UInt8](count: 20, repeatedValue: 0)
        data.getBytes(&dataBytes, length: data.length)
        
        for byte in dataBytes {
            queryCapabilitiesDataBuffer.append(byte)
            if byte == SYSEX_END {
                DLog("Capabilities received")
                queryAnalogMapping()
            }
        }
    }
    
    func cancelQueryCapabilities() {
        presentedViewController?.dismissViewControllerAnimated(true, completion: { () -> Void in
            DLog("QueryCapabilities not found")
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: localizationManager.localizedString("pinio_capabilityquery_expired_title"), message: localizationManager.localizedString("pinio_capabilityquery_expired_message"), preferredStyle: .Alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler:{ (_) -> Void in
                    self.endPinQuery()
            })
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    private func cancelQueryCapabilitiesTimer() {
        queryCapabilitiesTimer?.invalidate()
        queryCapabilitiesTimer = nil
    }
    
    // MARK: - Query AnalogMapping
    private var queryAnalogMappingDataBuffer = [UInt8]()

    private func queryAnalogMapping() {
        // Set status
        self.uartStatus = .QueryCapabilities
        self.queryAnalogMappingDataBuffer.removeAll()

            // Query Analog Mapping
        let bytes:[UInt8] = [self.SYSEX_START, 0x69, self.SYSEX_END]
        let data = NSData(bytes: bytes, length: bytes.count)
        
        UartManager.sharedInstance.sendData(data)
    }
    
    private func receivedAnalogMapping(data: NSData) {
        // Read received packet
        var dataBytes = [UInt8](count: 20, repeatedValue: 0)
        data.getBytes(&dataBytes, length: data.length)
        
        for byte in dataBytes {
            queryCapabilitiesDataBuffer.append(byte)
            if byte == SYSEX_END {
                DLog("Capabilities received")
                endPinQuery()
            }
        }
    }

    private func endPinQuery() {
        presentedViewController?.dismissViewControllerAnimated(true, completion: nil)

        cancelQueryCapabilitiesTimer()
        uartStatus = .SendData
        
        if queryCapabilitiesDataBuffer.count > 0 && queryAnalogMappingDataBuffer.count > 0 {
            parseCapabilities()
        }
        else {
            initializeDefaultCells()
            enableReadReports()
        }
        
        // Clean received data
        queryCapabilitiesDataBuffer.removeAll()
        queryAnalogMappingDataBuffer.removeAll()
        
        // Refresh
        baseTableView.reloadData()
    }
    
    private func parseCapabilities() {
    }

    
    
    // MARK: -
    
    private func initializeDefaultCells() {
        pins.removeAll()

        for i in 0..<DEFAULT_CELL_COUNT {
            var pin: PinData?
            if ((i == 3) || (i == 5) || (i == 6)) {     // PWM pins
                pin = PinData(pinId: UInt8(pins.count), pinNumber: UInt8(i), isDigital: true, mode: .Input, output: .Low, pmw: 0)
            }
            else if (i >= FIRST_DIGITAL_PIN && i <= LAST_DIGITAL_PIN) {    // Digital pin
                pin = PinData(pinId: UInt8(pins.count), pinNumber: UInt8(i), isDigital: true, mode: .Input, output: .Low, pmw: 0)
            }
            
            if let pin = pin {
                pins.append(pin)
            }
        }
    }
    
    private func enableReadReports() {
        
        //Enable Read Reports by port
        let ports:[UInt8] = [0,1,2]
        for port in ports {
            let data0:UInt8 = 0xD0 + port        //start port 0 digital reporting (0xD0 + port#)
            let data1:UInt8 = 1                  //enable
            let bytes:[UInt8] = [data0, data1]
            let data = NSData(bytes: bytes, length: 2)
            UartManager.sharedInstance.sendData(data)
        }
        
        /*
        //Set all pin modes active
        for cell in cells {
            modeControlChanged(cell!.modeControl)
        }
*/
    }
    
    /*
    private func sendData(data: NSData, completionHandler: (response: NSData)->()) -> Bool {
        guard responseDelegate == nil else {
            DLog("sendData error: waiting for a previous response")
            return false
        }
        
        responseDelegate = completionHandler
        UartManager.sharedInstance.sendData(data)
        return true
    }
*/
    
    func didReceiveData(notification: NSNotification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
            switch uartStatus {
            case .QueryCapabilities:
                receivedQueryCapabilities(dataChunk.data)
            case .QueryAnalogMapping:
                receivedAnalogMapping(dataChunk.data)
            default:
                DLog("received \(dataChunk.data.length) bytes")
                break
            }
        }
    }
    
    func stringForPinMode(mode: PinData.Mode)-> String {
        var modeString: String
        
        switch mode {
        case .Input:
            modeString = "Input"
        case .Output:
            modeString = "Output"
        case .Analog:
            modeString = "Analog"
        case .PWM:
            modeString = "PWM"
        case .Servo:
            modeString = "Servo"
        default:
            modeString = "NOT FOUND"
        }

        return modeString
    }

}

// MARK: - UITableViewDataSource
extension PinIOModuleViewController : UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pins.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString("pinio_pins_header")
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let reuseIdentifier = "PinCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath)
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let localizationManager = LocalizationManager.sharedInstance

        let pin = pins[indexPath.row]
        let pinCell = cell as! PinIOTableViewCell
        let analogName = pin.isDigital ? "":", Analog \(Int(pin.pinNumber)-FIRST_ANALOG_PIN)"
        pinCell.nameLabel.text = "Pin \(pin.pinNumber)\(analogName)"
        pinCell.modeLabel.text = stringForPinMode(pin.mode)
        
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        if let tableRowOpen = tableRowOpen where indexPath.row == tableRowOpen {
            let pinOpen = pins[tableRowOpen]
            return pinOpen.mode == .Input || pinOpen.mode == .Analog ? 110 : 150
        }
        else {
            return 44
        }
    }
}

// MARK:  UITableViewDelegate
extension PinIOModuleViewController : UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
