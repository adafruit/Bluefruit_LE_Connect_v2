//
//  UartModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import UIColor_Hex

class UartModeViewController: PeripheralModeViewController {
    // Config
    fileprivate static var dataFont = UIFont(name: "CourierNewPSMT", size: 14)! //Font.systemFontOfSize(Font.systemFontSize())

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var baseTextView: UITextView!
    @IBOutlet weak var statsLabel: UILabel!
    @IBOutlet weak var statsLabeliPadLeadingConstraint: NSLayoutConstraint!         // remove ipad or iphone depending on the platform
    @IBOutlet weak var statsLabeliPhoneLeadingConstraint: NSLayoutConstraint!       // remove ipad or iphone depending on the platform

    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var sendInputButton: UIButton!
    @IBOutlet weak var keyboardSpacerHeightConstraint: NSLayoutConstraint!
    
    private var mqttBarButtonItem: UIBarButtonItem!
    private var mqttBarButtonItemImageView : UIImageView?
    @IBOutlet weak var moreOptionsNavigationItem: UIBarButtonItem!
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var controlsView: UIView!
    @IBOutlet weak var inputControlsStackView: UIStackView!
    
    @IBOutlet weak var showEolSwitch: UISwitch!
    @IBOutlet weak var addEolSwitch: UISwitch!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var displayModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var dataModeSegmentedControl: UISegmentedControl!
    
    // Data
    enum DisplayMode {
        case text           // Display a TextView with all uart data as a String
        case table          // Display a table where each data chunk is a row
    }
    
    fileprivate var uartData: UartPacketManager!// = UartPacketManager(delegate: self)
    fileprivate var txColor = Preferences.uartSentDataColor
    fileprivate var rxColor = Preferences.uartReceveivedDataColor
    fileprivate let timestampDateFormatter = DateFormatter()
    fileprivate var tableCachedDataBuffer: [UartPacket]?
    fileprivate var textCachedBuffer = NSMutableAttributedString()
    
    private let keyboardPositionNotifier = KeyboardPositionNotifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        assert(blePeripheral != nil)

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("peripherallist_unnamed")
        let title = String(format: localizationManager.localizedString("uart_navigation_title_format"), arguments: [name])
        //tabBarController?.navigationItem.title = title
        navigationController?.navigationItem.title = title

        // Init Data
        keyboardPositionNotifier.delegate = self
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss")

        // Setup tableView
        // Note: Don't use automatic height because its to slow with a large amount of rows
        baseTableView.layer.borderWidth = 1
        baseTableView.layer.borderColor = UIColor.lightGray.cgColor
        
        // Setup textview
        baseTextView.layer.borderWidth = 1
        baseTextView.layer.borderColor = UIColor.lightGray.cgColor

        // Setup controls
        displayModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_timestamp"), forSegmentAt: 0)
        displayModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_text"), forSegmentAt: 1)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_ascii"), forSegmentAt: 0)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_hex"), forSegmentAt: 1)
        
        // Init options layout
        if traitCollection.userInterfaceIdiom == .pad {            // iPad
            self.view.removeConstraint(statsLabeliPhoneLeadingConstraint)
            
            // Resize input UISwitch controls
            for subStackView in inputControlsStackView.subviews {
                for subview in subStackView.subviews {
                    if let switchView = subview as? UISwitch {
                        switchView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                    }
                }
            }
        }
        else {            // iPhone
            self.view.removeConstraint(statsLabeliPadLeadingConstraint)
            statsLabel.textAlignment = .left
            inputControlsStackView.isHidden = true
        }
        
         // Mqtt init
         mqttBarButtonItemImageView = UIImageView(image: UIImage(named: "mqtt_disconnected")!.tintWithColor(self.view.tintColor))      // use a uiimageview as custom barbuttonitem to allow frame animations
         mqttBarButtonItemImageView!.tintColor = self.view.tintColor
         mqttBarButtonItemImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UartModeViewController.onClickMqtt)))
         
        /*
         let mqttManager = MqttManager.sharedInstance
         if (MqttSettings.sharedInstance.isConnected) {
         mqttManager.delegate = uartData
         mqttManager.connectFromSavedSettings()
         }
         */
        
        // Init Uarts
        uartData = UartPacketManager(delegate: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Hide top controls on iPhone
         if traitCollection.userInterfaceIdiom == .phone {
            controlsView.isHidden = true
        }
    }
    
    deinit {
        uartData = nil
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        registerNotifications(enabled: true)
        
        // Update the navgation bar items
        if var rightButtonItems = navigationController?.navigationItem.rightBarButtonItems, rightButtonItems.count == 2 {
            
            if traitCollection.userInterfaceIdiom == .pad {
                // Remove more item
                rightButtonItems.remove(at: 0)
                
                // Add mqtt bar item
                mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                rightButtonItems.append(mqttBarButtonItem)
            }
            else {
                // Add mqtt bar item
                mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                rightButtonItems.append(mqttBarButtonItem)
            }
            
             navigationController!.navigationItem.rightBarButtonItems = rightButtonItems
        }
        
        // UI
        reloadDataUI()
        showEolSwitch.isOn = Preferences.uartIsAutomaticEolEnabled
        addEolSwitch.isOn = Preferences.uartIsEchoEnabled
        displayModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsDisplayModeTimestamp ? 0:1
        dataModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsInHexMode ? 1:0

        // Enable Uart
        updateUartReadyUI(isReady: false)
        blePeripheral?.uartEnable(uartRxHandler: uartData.uartRxPacketReceived) { [weak self] error in
            guard let context = self else {
                return
            }
            
            DispatchQueue.main.async { [unowned context] in
                guard error == nil else {
                    DLog("Error initializing uart")
                    context.dismiss(animated: true, completion: { [weak self] () -> Void in
                        if let context = self {
                            showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")
                            
                            if let blePeripheral = context.blePeripheral {
                                BleManager.sharedInstance.disconnect(from: blePeripheral)
                            }
                        }
                    })
                    return
                }
                
                // Done
                DLog("Uart enabled")
                context.updateUartReadyUI(isReady: true)
            }
        }

        
        /*
        // MQTT
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
        }
        mqttUpdateStatusUI()
 */
    }
    
    private func updateUartReadyUI(isReady: Bool) {
        inputTextField.isEnabled = isReady
        inputTextField.backgroundColor = isReady ? UIColor.white : UIColor.black.withAlphaComponent(0.1)
  
    }
    
    /*
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        baseTableView.enh_cancelPendingReload()
        
        if !Config.uartShowAllUartCommunication {
            uartData.dataBufferEnabled = false
        }
        registerNotifications(false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "uartSettingsSegue"  {
            if let controller = segue.destination.popoverPresentationController {
                controller.delegate = self
                
                let uartSettingsViewController = segue.destination as! UartSettingsViewController
                uartSettingsViewController.onClickClear = {
                    self.onClickClear(self)
                }
                uartSettingsViewController.onClickExport = {
                    self.onClickExport(self)
                }
            }
        }
    }

    */
    
    // MARK: - BLE Notifications
    private var didUpdatePreferencesObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdatePreferencesObserver = notificationCenter.addObserver(forName: .didUpdatePreferences, object: nil, queue: OperationQueue.main, using: didUpdatePreferences)
        }
        else {
            if let didUpdatePreferencesObserver = didUpdatePreferencesObserver {notificationCenter.removeObserver(didUpdatePreferencesObserver)}
        }
    }

    private func didUpdatePreferences(notification: Notification) {
        txColor = Preferences.uartSentDataColor
        rxColor = Preferences.uartReceveivedDataColor
        reloadDataUI()
    }

    
    // MARK: - UI Updates
    private func reloadDataUI() {
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text
        
        baseTableView.isHidden = displayMode == .text
        baseTextView.isHidden = displayMode == .table
        
        switch(displayMode) {
        case .text:
            
            textCachedBuffer.setAttributedString(NSAttributedString())
            let dataPackets = uartData.rxCache()
            for dataPacket in dataPackets {
                addPacketToUIText(dataPacket)
            }
            baseTextView.attributedText = textCachedBuffer
            reloadData()
            
        case .table:
            reloadData()
        }
        
        updateBytesUI()
    }
    
    fileprivate func updateBytesUI() {
        let localizationManager = LocalizationManager.sharedInstance
        let sentBytesMessage = String(format: localizationManager.localizedString("uart_sentbytes_format"), arguments: [uartData.sentBytes])
        let receivedBytesMessage = String(format: localizationManager.localizedString("uart_recievedbytes_format"), arguments: [uartData.receivedBytes])
        
        statsLabel.text = String(format: "%@     %@", arguments: [sentBytesMessage, receivedBytesMessage])
    }

    // MARK: - UI Actions
    func onClickMqtt() {
        /*
        let viewController = storyboard!.instantiateViewController(withIdentifier: "UartMqttSettingsViewController")
        viewController.modalPresentationStyle = .popover
        if let popovoverController = viewController.popoverPresentationController
        {
            popovoverController.barButtonItem = mqttBarButtonItem
            popovoverController.delegate = self
        }
        present(viewController, animated: true, completion: nil)
 */
    }
/*
    @IBAction func onClickSend(sender: AnyObject) {
        let text = inputTextField.text != nil ? inputTextField.text! : ""
        
        var newText = text
        // Eol
        if (Preferences.uartIsAutomaticEolEnabled)  {
            newText += "\n"
        }
        
        uartData.sendMessageToUart(newText)
        inputTextField.text = ""
    }
    
    @IBAction func onInputTextFieldEdidtingDidEndOnExit(sender: UITextField) {
        onClickSend(sender)
    }
    
    @IBAction func onClickClear(sender: AnyObject) {
        uartData.clearData()
        reloadDataUI()
    }
    
    @IBAction func onClickExport(sender: AnyObject) {
        let dataBuffer = self.uartData.dataBuffer
        guard dataBuffer.count>0 else {
            showDialogWarningNoTextToExport()
            return;
        }
        
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: "Export data", message: "Choose the prefered format:", preferredStyle: .actionSheet)
        
        for exportFormat in UartModuleManager.kExportFormats {
            let exportAction = UIAlertAction(title: exportFormat.rawValue, style: .Default) {[unowned self] (_) in
                
                var exportData: AnyObject?
                
                switch(exportFormat) {
                case .txt:
                    exportData = UartDataExport.dataAsText(dataBuffer)
                case .csv:
                    exportData = UartDataExport.dataAsCsv(dataBuffer)
                case .json:
                    exportData = UartDataExport.dataAsJson(dataBuffer)
                case .xml:
                    exportData = UartDataExport.dataAsXml(dataBuffer)
                case .bin:
                    exportData = UartDataExport.dataAsBinary(dataBuffer)
                }
                self.exportData(exportData)
            }
            alertController.addAction(exportAction)
        }
        
        let cancelAction = UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler:nil)
        alertController.addAction(cancelAction)
        
        alertController.popoverPresentationController?.sourceView = exportButton
        self.present(alertController, animated: true, completion: nil)
    }
     */
 
    
    private func exportData(data: AnyObject?) {
        if let data = data {
            // TODO: replace randomly generated iOS filenames: https://thomasguenzel.com/blog/2015/04/16/uiactivityviewcontroller-nsdata-with-filename/
            
            let activityViewController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = exportButton
            
            navigationController?.present(activityViewController, animated: true, completion: nil)
            
        }
        else {
            DLog("exportString with empty text")
            showDialogWarningNoTextToExport()
        }
    }
 
    private func showDialogWarningNoTextToExport() {
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("uart_export_nodata"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    @IBAction func onShowEchoValueChanged(_ sender: UISwitch) {
        Preferences.uartIsEchoEnabled = sender.isOn
    }
    
    @IBAction func onAddEolValueChanged(_ sender: UISwitch) {
        Preferences.uartIsAutomaticEolEnabled = sender.isOn
    }
    
    @IBAction func onDisplayModeChanged(_ sender: UISegmentedControl) {
        Preferences.uartIsDisplayModeTimestamp = sender.selectedSegmentIndex == 0
        
    }
    
    @IBAction func onDataModeChanged(_ sender: UISegmentedControl) {
        Preferences.uartIsInHexMode = sender.selectedSegmentIndex == 1
    }
    
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("uart_help_text"), title: localizationManager.localizedString("uart_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension UartModeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if Preferences.uartIsEchoEnabled  {
            tableCachedDataBuffer = uartData.rxCache()
        }
        else {
            tableCachedDataBuffer = uartData.rxCache().filter({ (dataChunk: UartPacket) -> Bool in
                dataChunk.mode == .rx
            })
        }
        
        return tableCachedDataBuffer?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "TimestampCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath as IndexPath)
        
        // Data binding in cellForRowAtIndexPath to avoid problems with multiple-line labels and dyanmic tableview height calculation
        let dataChunk = tableCachedDataBuffer![indexPath.row]
        let date = Date(timeIntervalSinceReferenceDate: dataChunk.timestamp)
        let dateString = timestampDateFormatter.string(from: date)
        let modeString = LocalizationManager.sharedInstance.localizedString(dataChunk.mode == .rx ? "uart_timestamp_direction_rx" : "uart_timestamp_direction_tx")
        let color = dataChunk.mode == .tx ? txColor : rxColor
        
        let timestampCell = cell as! UartTimetampTableViewCell

        timestampCell.timeStampLabel.text = String(format: "%@ %@", arguments: [dateString, modeString])
        
        if let attributedText = attributedStringFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartModeViewController.dataFont), attributedText.length > 0 {
            timestampCell.dataLabel.attributedText = attributedText
        }
        else {
            timestampCell.dataLabel.attributedText = NSAttributedString(string: " ")        // space to maintain height
        }
 
        timestampCell.contentView.backgroundColor = indexPath.row%2 == 0 ? UIColor.white : UIColor(hex: 0xeeeeee)
        return cell
    }
}

// MARK: UITableViewDelegate
extension UartModeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}


// MARK: - UartModuleDelegate
extension UartModeViewController: UartPacketManagerDelegate {
    
    func addPacketToUI(packet: UartPacket) {
        // Check that the view has been initialized before updating UI
        guard isViewLoaded && view.window != nil &&  baseTableView != nil else {
            return
        }
        
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text

        switch displayMode {
        case .text:
            addPacketToUIText(packet)
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        case .table:
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        }

        updateBytesUI()
    }
    
    func reloadData() {
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text
        switch(displayMode) {
        case .text:
            baseTextView.attributedText = textCachedBuffer
            
            let textLength = textCachedBuffer.length
            if textLength > 0 {
                let range = NSMakeRange(textLength - 1, 1);
                baseTextView.scrollRangeToVisible(range);
            }
            
        case .table:
            baseTableView.reloadData()
            if let tableCachedDataBuffer = tableCachedDataBuffer {
                if tableCachedDataBuffer.count > 0 {
                    let lastIndex = IndexPath(row: tableCachedDataBuffer.count-1, section: 0)
                    baseTableView.scrollToRow(at: lastIndex, at: .bottom, animated: false)
                }
            }
        }
    }
    
    fileprivate func addPacketToUIText(_ packet: UartPacket) {
        
        if (Preferences.uartIsEchoEnabled || packet.mode == .rx) {
            let color = packet.mode == .tx ? txColor : rxColor
            
            if let attributedString = attributedStringFromData(packet.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartModeViewController.dataFont) {
                textCachedBuffer.append(attributedString)
            }
        }
    }

    func mqttUpdateStatusUI() {
        /*
        if let imageView = mqttBarButtonItemImageView {
            let status = MqttManager.sharedInstance.status
            let tintColor = self.view.tintColor
            
            switch (status) {
            case .Connecting:
                let imageFrames = [
                    UIImage(named:"mqtt_connecting1")!.tintWithColor(tintColor),
                    UIImage(named:"mqtt_connecting2")!.tintWithColor(tintColor),
                    UIImage(named:"mqtt_connecting3")!.tintWithColor(tintColor)
                ]
                imageView.animationImages = imageFrames
                imageView.animationDuration = 0.5 * Double(imageFrames.count)
                imageView.animationRepeatCount = 0;
                imageView.startAnimating()
                
            case .Connected:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_connected")!.tintWithColor(tintColor)
                
            default:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_disconnected")!.tintWithColor(tintColor)
            }
        }
 */
    }

    func mqttError(message: String, isConnectionError: Bool) {
        let localizationManager = LocalizationManager.sharedInstance

        let alertMessage = isConnectionError ? localizationManager.localizedString("uart_mqtt_connectionerror_title") : message
        let alertController = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
}


/*
// MARK: - CBPeripheralDelegate
extension UartModeViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        uartData.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        uartData.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        uartData.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        
        // Check if ready
        if uartData.isReady() {
            // Enable input
            dispatch_get_main_queue().asynchronously(DispatchQueue.mainexecute: { [unowned self] in
                if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                    self.inputTextField.isEnabled = true
                    self.inputTextField.backgroundColor = UIColor.whiteColor
                }
                });
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        uartData.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
    }
}



// MARK: - UIPopoverPresentationControllerDelegate
extension UartModeViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyleForPresentationController(PC: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {

        // MQTT
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
        }
        mqttUpdateStatusUI()
    }
}
 */

// MARK: - KeyboardPositionNotifierDelegate
extension UartModeViewController: KeyboardPositionNotifierDelegate {
    
    func onKeyboardPositionChanged(keyboardFrame: CGRect, keyboardShown: Bool) {
        var spacerHeight = keyboardFrame.height
        spacerHeight -= StyleConfig.tabbarHeight
        keyboardSpacerHeightConstraint.constant = max(spacerHeight, 0)
    }
}


