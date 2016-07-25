//
//  PinIOModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PinIOModuleViewController: ModuleViewController {

    private let pinIO = PinIOModuleManager()
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private var tableRowOpen: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table
        baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
  
        // Init
        pinIO.delegate = self
    
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery

        if (UartManager.sharedInstance.isReady()) {
            setupFirmata()
        }
        else {
            DLog("Wait for uart to be ready to start PinIO setup")

            let notificationCenter =  NSNotificationCenter.defaultCenter()
            notificationCenter.addObserver(self, selector: #selector(PinIOModuleViewController.uartIsReady(_:)), name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        }
    }

    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.setupFirmata()
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
       
        DLog("PinIO viewWillAppear")
        pinIO.start()
        
        if pinIO.pins.count == 0 && !pinIO.isQueryingCapabilities() {
            startQueryCapabilitiesProcess()
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    
        // if a dialog is being shown, dismiss it. For example: when querying capabilities but a didmodifyservices callback is received and pinio is removed from the tabbar
        if let presentedViewController = presentedViewController {
            presentedViewController.dismissViewControllerAnimated(true, completion: nil)
        }
        
        DLog("PinIO viewWillDisappear")
        pinIO.stop()
    }
    
    private func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        tableRowOpen = nil
        baseTableView.reloadData()
        if isViewLoaded() && view.window != nil {     // if is visible
            startQueryCapabilitiesProcess()
        }
    }
    
    private func startQueryCapabilitiesProcess() {
        guard !pinIO.isQueryingCapabilities() else {
            DLog("error: queryCapabilities called while querying capabilities")
            return
        }

        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("pinio_capabilityquery_querying_title"), preferredStyle: .Alert)
        
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .Cancel, handler: { [weak self] (_) -> Void in
            self?.pinIO.endPinQuery(true)
            }))

        self.presentViewController(alertController, animated: true) {[weak self] () -> Void in
            // Query Capabilities
            self?.pinIO.queryCapabilities()
        }
    }
    
    func defaultCapabilitiesAssumedDialog() {
        
        DLog("QueryCapabilities not found")
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: localizationManager.localizedString("pinio_capabilityquery_expired_title"), message: localizationManager.localizedString("pinio_capabilityquery_expired_message"), preferredStyle: .Alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler:{ (_) -> Void in
        })
        alertController.addAction(okAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    @IBAction func onClickQuery(sender: AnyObject) {
        setupFirmata()
    }
    
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewControllerWithIdentifier("HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("pinio_help_text"), title: localizationManager.localizedString("pinio_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .Popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        presentViewController(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension PinIOModuleViewController : UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pinIO.pins.count
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
        let pin = pinIO.pins[indexPath.row]
        let pinCell = cell as! PinIOTableViewCell
        pinCell.setPin(pin)

        pinCell.tag = indexPath.row
        pinCell.delegate = self
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if let tableRowOpen = tableRowOpen where indexPath.row == tableRowOpen {
            let pinOpen = pinIO.pins[tableRowOpen]
            return pinOpen.mode == .Input || pinOpen.mode == .Analog ? 100 : 160
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

// MARK:  PinIoTableViewCellDelegate
extension PinIOModuleViewController : PinIoTableViewCellDelegate {
    func onPinToggleCell(pinIndex: Int) {
        // Change open row
        tableRowOpen = pinIndex == tableRowOpen ? nil: pinIndex
 
        // Animate changes
        baseTableView.beginUpdates()
        baseTableView.endUpdates()
    }
    func onPinModeChanged(mode: PinIOModuleManager.PinData.Mode, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setControlMode(pin, mode: mode)
        
        baseTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: pinIndex, inSection: 0)], withRowAnimation: .None)
    }
    func onPinDigitalValueChanged(value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin, value: value)
        
        baseTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: pinIndex, inSection: 0)], withRowAnimation: .None)
    }
    func onPinAnalogValueChanged(value: Float, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin, value: Int(value)) {
            baseTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: pinIndex, inSection: 0)], withRowAnimation: .None)
        }
    }
}

extension PinIOModuleViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(isDefaultConfigurationAssumed: Bool) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.baseTableView.reloadData()
            
            self.presentedViewController?.dismissViewControllerAnimated(true, completion: { () -> Void in
                if isDefaultConfigurationAssumed {
                    self.defaultCapabilitiesAssumedDialog()
                }
            })
            
            })
    }
    
    func onPinIODidReceivePinState() {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            
            self.baseTableView.reloadData()
  
            })
    }
}