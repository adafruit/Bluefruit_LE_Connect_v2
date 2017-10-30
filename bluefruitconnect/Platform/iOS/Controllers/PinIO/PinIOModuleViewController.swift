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
          DLog(message: "Wait for uart to be ready to start PinIO setup")

            let notificationCenter =  NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(PinIOModuleViewController.uartIsReady), name: .uartDidBecomeReady, object: nil)
        }
    }

    @objc func uartIsReady(notification: NSNotification) {
      DLog(message: "Uart is ready")
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: .uartDidBecomeReady, object: nil)
        
       DispatchQueue.main.async { [unowned self] in
            self.setupFirmata()
      }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
  override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
    DLog(message: "PinIO viewWillAppear")
        pinIO.start()
        
        if pinIO.pins.count == 0 && !pinIO.isQueryingCapabilities() {
            startQueryCapabilitiesProcess()
        }
    }
    
  override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
        // if a dialog is being shown, dismiss it. For example: when querying capabilities but a didmodifyservices callback is received and pinio is removed from the tabbar
        if let presentedViewController = presentedViewController {
          presentedViewController.dismiss(animated: true, completion: nil)
        }
        
    DLog(message: "PinIO viewWillDisappear")
        pinIO.stop()
    }
    
    private func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        tableRowOpen = nil
        baseTableView.reloadData()
      if isViewLoaded && view.window != nil {     // if is visible
            startQueryCapabilitiesProcess()
        }
    }
    
    private func startQueryCapabilitiesProcess() {
        guard !pinIO.isQueryingCapabilities() else {
          DLog(message: "error: queryCapabilities called while querying capabilities")
            return
        }

        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString(key: "pinio_capabilityquery_querying_title"), preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString(key: "dialog_cancel"), style: .cancel, handler: { [weak self] (_) -> Void in
            self?.pinIO.endPinQuery(abortQuery: true)
            }))

        self.present(alertController, animated: true) {[weak self] () -> Void in
            // Query Capabilities
            self?.pinIO.queryCapabilities()
        }
    }
    
    func defaultCapabilitiesAssumedDialog() {
        
        DLog(message: "QueryCapabilities not found")
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: localizationManager.localizedString(key: "pinio_capabilityquery_expired_title"), message: localizationManager.localizedString(key: "pinio_capabilityquery_expired_message"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler:{ (_) -> Void in
        })
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    @IBAction func onClickQuery(sender: AnyObject) {
        setupFirmata()
    }
    
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
      helpViewController.setHelp(message: localizationManager.localizedString(key: "pinio_help_text"), title: localizationManager.localizedString(key: "pinio_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension PinIOModuleViewController : UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pinIO.pins.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString(key: "pinio_pins_header")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PinCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath as IndexPath)
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let pin = pinIO.pins[indexPath.row]
        let pinCell = cell as! PinIOTableViewCell
        pinCell.setPin(pin: pin)

        pinCell.tag = indexPath.row
        pinCell.delegate = self
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: IndexPath) -> CGFloat {
        if let tableRowOpen = tableRowOpen, indexPath.row == tableRowOpen {
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
        pinIO.setControlMode(pin: pin, mode: mode)
        
        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0) as IndexPath], with: .none)
    }
    func onPinDigitalValueChanged(value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin: pin, value: value)
        
        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0) as IndexPath], with: .none)
    }
    func onPinAnalogValueChanged(value: Float, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin: pin, value: Int(value)) {
            baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0) as IndexPath], with: .none)
        }
    }
}

extension PinIOModuleViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(isDefaultConfigurationAssumed: Bool) {
        DispatchQueue.main.async { [unowned self] in
            self.baseTableView.reloadData()
            
            self.presentedViewController?.dismiss(animated: true, completion: { () -> Void in
                if isDefaultConfigurationAssumed {
                    self.defaultCapabilitiesAssumedDialog()
                }
            })
            
            }
    }
    
    func onPinIODidReceivePinState() {
        DispatchQueue.main.async { [unowned self] in
            
            self.baseTableView.reloadData()
  
            }
    }
}
