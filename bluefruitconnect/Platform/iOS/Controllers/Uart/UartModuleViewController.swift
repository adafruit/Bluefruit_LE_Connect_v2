//
//  UartModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import UIColor_Hex

class UartModuleViewController: ModuleViewController {

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
    private let uartData = UartModuleManager()
    private var txColor = Preferences.uartSentDataColor
    private var rxColor = Preferences.uartReceveivedDataColor
    private let timestampDateFormatter = DateFormatter()
    private var tableCachedDataBuffer: [UartDataChunk]?
    private var textCachedBuffer = NSMutableAttributedString()
    
    private let keyboardPositionNotifier = KeyboardPositionNotifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Peripheral should be connected
        uartData.delegate = self
        uartData.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        guard uartData.blePeripheral != nil else {
            DLog(message: "Error: Uart: blePeripheral is nil")
            return
        }
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = uartData.blePeripheral!.name != nil ? uartData.blePeripheral!.name! : localizationManager.localizedString(key: "peripherallist_unnamed")
        let title = String(format: localizationManager.localizedString(key: "uart_navigation_title_format"), arguments: [name])
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
        displayModeSegmentedControl.setTitle(localizationManager.localizedString(key: "uart_settings_displayMode_timestamp"), forSegmentAt: 0)
        displayModeSegmentedControl.setTitle(localizationManager.localizedString(key: "uart_settings_displayMode_text"), forSegmentAt: 1)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString(key: "uart_settings_dataMode_ascii"), forSegmentAt: 0)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString(key: "uart_settings_dataMode_hex"), forSegmentAt: 1)
        
        // Init options layout
        if traitCollection.userInterfaceIdiom == .pad {            // iPad
            // moreOptionsNavigationItem.enabled = false
            
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
        mqttBarButtonItemImageView = UIImageView(image: UIImage(named: "mqtt_disconnected")!.tintWithColor(color: self.view.tintColor))      // use a uiimageview as custom barbuttonitem to allow frame animations
        mqttBarButtonItemImageView!.tintColor = self.view.tintColor
        mqttBarButtonItemImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UartModuleViewController.onClickMqtt)))
        
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
            mqttManager.connectFromSavedSettings()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Hide top controls on iPhone
        if traitCollection.userInterfaceIdiom == .phone {
            controlsView.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        registerNotifications(register: true)
        
        uartData.dataBufferEnabled = true
        
        // Update the navgation bar items
        if var rightButtonItems = navigationController?.navigationItem.rightBarButtonItems, rightButtonItems.count == 2 {
        //if var rightButtonItems = tabBarController?.navigationItem.rightBarButtonItems where rightButtonItems.count == 2 {
            
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
            
           // tabBarController!.navigationItem.rightBarButtonItems = rightButtonItems
             navigationController!.navigationItem.rightBarButtonItems = rightButtonItems
        }
        
        // UI
        reloadDataUI()
        showEolSwitch.isOn = Preferences.uartIsAutomaticEolEnabled
        addEolSwitch.isOn = Preferences.uartIsEchoEnabled
        displayModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsDisplayModeTimestamp ? 0:1
        dataModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsInHexMode ? 1:0

        // Check if characteristics are ready
        let isUartReady = uartData.isReady()
        inputTextField.isEnabled = isUartReady
        inputTextField.backgroundColor = isUartReady ? UIColor.white : UIColor.black.withAlphaComponent(0.1)
        
        // MQTT
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
        }
        mqttUpdateStatusUI()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        baseTableView.enh_cancelPendingReload()
        
        if !Config.uartShowAllUartCommunication {
            uartData.dataBufferEnabled = false
        }
        registerNotifications(register: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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
    
    // MARK: - Preferences
    func registerNotifications(register : Bool) {
        
        let notificationCenter =  NotificationCenter.default
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(UartModuleViewController.preferencesUpdated), name: .didUpdatePreferences, object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: .didUpdatePreferences, object: nil)
        }
    }
    
    @objc func preferencesUpdated(notification : NSNotification) {
        txColor = Preferences.uartSentDataColor
        rxColor = Preferences.uartReceveivedDataColor
        reloadDataUI()
    }
    
    // MARK: - UI Updates
    func reloadDataUI() {
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.Table : UartModuleManager.DisplayMode.Text
        
        baseTableView.isHidden = displayMode == .Text
        baseTextView.isHidden = displayMode == .Table
        
        switch(displayMode) {
        case .Text:
            
            textCachedBuffer.setAttributedString(NSAttributedString())
            for dataChunk in uartData.dataBuffer {
                addChunkToUIText(dataChunk: dataChunk)
            }
            baseTextView.attributedText = textCachedBuffer
            reloadData()
            
        case .Table:
            reloadData()
        }
        
        updateBytesUI()
    }

    func updateBytesUI() {
        if let blePeripheral = uartData.blePeripheral {
            let localizationManager = LocalizationManager.sharedInstance
            let sentBytesMessage = String(format: localizationManager.localizedString(key: "uart_sentbytes_format"), arguments: [blePeripheral.uartData.sentBytes])
            let receivedBytesMessage = String(format: localizationManager.localizedString(key: "uart_recievedbytes_format"), arguments: [blePeripheral.uartData.receivedBytes])
            
            statsLabel.text = String(format: "%@     %@", arguments: [sentBytesMessage, receivedBytesMessage])
        }
    }
    
    // MARK: - UI Actions
    @objc func onClickMqtt() {
        let viewController = storyboard!.instantiateViewController(withIdentifier: "UartMqttSettingsViewController")
        viewController.modalPresentationStyle = .popover
        if let popovoverController = viewController.popoverPresentationController
        {
            popovoverController.barButtonItem = mqttBarButtonItem
            popovoverController.delegate = self
        }
        present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func onClickSend(_ sender: Any) {
        let text = inputTextField.text != nil ? inputTextField.text! : ""
        
        var newText = text
        // Eol
        if (Preferences.uartIsAutomaticEolEnabled)  {
            newText += "\n"
        }
        
        uartData.sendMessageToUart(text: newText)
        inputTextField.text = ""
    }
    
    @IBAction func onInputTextFieldEdidtingDidEndOnExit(_ sender: UITextField) {
        onClickSend(sender)
    }
    
    @IBAction func onClickClear(_ sender: Any) {
        uartData.clearData()
        reloadDataUI()
    }
    
    @IBAction func onClickExport(_ sender: Any) {
        let dataBuffer = self.uartData.dataBuffer
        guard dataBuffer.count>0 else {
            showDialogWarningNoTextToExport()
            return;
        }
        
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: "Export data", message: "Choose the prefered format:", preferredStyle: .actionSheet)
        
        for exportFormat in UartModuleManager.kExportFormats {
            let exportAction = UIAlertAction(title: exportFormat.rawValue, style: .default) {[unowned self] (_) in
                
                var exportData: AnyObject?
                
                switch(exportFormat) {
                case .txt:
                    exportData = UartDataExport.dataAsText(dataBuffer: dataBuffer) as AnyObject
                case .csv:
                    exportData = UartDataExport.dataAsCsv(dataBuffer: dataBuffer) as AnyObject
                case .json:
                    exportData = UartDataExport.dataAsJson(dataBuffer: dataBuffer) as AnyObject
                case .xml:
                    exportData = UartDataExport.dataAsXml(dataBuffer: dataBuffer) as AnyObject
                case .bin:
                    exportData = UartDataExport.dataAsBinary(dataBuffer: dataBuffer)
                }
                self.exportData(data: exportData)
            }
            alertController.addAction(exportAction)
        }
        
        let cancelAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_cancel"), style: .cancel, handler:nil)
        alertController.addAction(cancelAction)
        
        alertController.popoverPresentationController?.sourceView = exportButton
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    private func exportData(data: AnyObject?) {
        if let data = data {
            // TODO: replace randomly generated iOS filenames: https://thomasguenzel.com/blog/2015/04/16/uiactivityviewcontroller-nsdata-with-filename/
            
            let activityViewController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = exportButton
            
            navigationController?.present(activityViewController, animated: true, completion: nil)
            
        }
        else {
            DLog(message: "exportString with empty text")
            showDialogWarningNoTextToExport()
        }
    }
    
    private func showDialogWarningNoTextToExport() {
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString(key: "uart_export_nodata"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler:nil)
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
        helpViewController.setHelp(message: localizationManager.localizedString(key: "uart_help_text"), title: localizationManager.localizedString(key: "uart_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension UartModuleViewController : UITableViewDataSource {
    
    private static var dataFont = UIFont(name: "CourierNewPSMT", size: 14)! //Font.systemFontOfSize(Font.systemFontSize())
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (Preferences.uartIsEchoEnabled)  {
            tableCachedDataBuffer = uartData.dataBuffer
        }
        else {
            tableCachedDataBuffer = uartData.dataBuffer.filter({ (dataChunk : UartDataChunk) -> Bool in
                dataChunk.mode == .RX
            })
        }
        
        return tableCachedDataBuffer!.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "TimestampCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath)
        
        // Data binding in cellForRowAtIndexPath to avoid problems with multiple-line labels and dyanmic tableview height calculation
        let dataChunk = tableCachedDataBuffer![indexPath.row]
        let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
        let dateString = timestampDateFormatter.string(from: date as Date)
        let modeString = LocalizationManager.sharedInstance.localizedString(key: dataChunk.mode == .RX ? "uart_timestamp_direction_rx" : "uart_timestamp_direction_tx")
        let color = dataChunk.mode == .TX ? txColor : rxColor
        
        let timestampCell = cell as! UartTimetampTableViewCell

        timestampCell.timeStampLabel.text = String(format: "%@ %@", arguments: [dateString, modeString])
        
        if let attributedText = UartModuleManager.attributeTextFromData(data: dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartModuleViewController.dataFont), attributedText.length > 0 {
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
extension UartModuleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}

// MARK: - UartModuleDelegate
extension UartModuleViewController: UartModuleDelegate {
    
    func addChunkToUI(dataChunk : UartDataChunk) {
        // Check that the view has been initialized before updating UI
        guard isViewLoaded && view.window != nil &&  baseTableView != nil else {
            return
        }
        
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.Table : UartModuleManager.DisplayMode.Text

        switch(displayMode) {
        case .Text:
            addChunkToUIText(dataChunk: dataChunk)
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        case .Table:
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        }

        updateBytesUI()
    }
    
    func reloadData() {
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.Table : UartModuleManager.DisplayMode.Text
        switch(displayMode) {
        case .Text:
            baseTextView.attributedText = textCachedBuffer
            
            let textLength = textCachedBuffer.length
            if textLength > 0 {
                let range = NSMakeRange(textLength - 1, 1);
                baseTextView.scrollRangeToVisible(range);
            }
            
        case .Table:
            baseTableView.reloadData()
            if let tableCachedDataBuffer = tableCachedDataBuffer {
                if tableCachedDataBuffer.count > 0 {
                    let lastIndex = NSIndexPath(row: tableCachedDataBuffer.count-1, section: 0)
                    baseTableView.scrollToRow(at: lastIndex as IndexPath as IndexPath, at: UITableViewScrollPosition.bottom, animated: false)
                }
            }
        }
    }
    
    private func addChunkToUIText(dataChunk : UartDataChunk) {
        
        if (Preferences.uartIsEchoEnabled || dataChunk.mode == .RX) {
            let color = dataChunk.mode == .TX ? txColor : rxColor
            
            if let attributedString = UartModuleManager.attributeTextFromData(data: dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartModuleViewController.dataFont) {
                textCachedBuffer.append(attributedString)
            }
        }
    }

    func mqttUpdateStatusUI() {
        if let imageView = mqttBarButtonItemImageView {
            let status = MqttManager.sharedInstance.status
            let tintColor = self.view.tintColor
            
            switch (status) {
            case .Connecting:
                let imageFrames = [
                    UIImage(named:"mqtt_connecting1")!.tintWithColor(color: tintColor!),
                    UIImage(named:"mqtt_connecting2")!.tintWithColor(color: tintColor!),
                    UIImage(named:"mqtt_connecting3")!.tintWithColor(color: tintColor!)
                ]
                imageView.animationImages = imageFrames
                imageView.animationDuration = 0.5 * Double(imageFrames.count)
                imageView.animationRepeatCount = 0;
                imageView.startAnimating()
                
            case .Connected:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_connected")!.tintWithColor(color: tintColor!)
                
            default:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_disconnected")!.tintWithColor(color: tintColor!)
            }
        }
    }

    func mqttError(message: String, isConnectionError: Bool) {
        let localizationManager = LocalizationManager.sharedInstance

        let alertMessage = isConnectionError ? localizationManager.localizedString(key: "uart_mqtt_connectionerror_title"): message
        let alertController = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler:nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension UartModuleViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        uartData.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        uartData.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        uartData.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        
        // Check if ready
        if uartData.isReady() {
            // Enable input
            DispatchQueue.main.async { [unowned self] in
                if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                    self.inputTextField.isEnabled = true
                    self.inputTextField.backgroundColor = UIColor.white
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        uartData.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
    }
}

// MARK: - KeyboardPositionNotifierDelegate
extension UartModuleViewController: KeyboardPositionNotifierDelegate {
    
    func onKeyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool) {
        var spacerHeight = keyboardFrame.height
        /*
        if let tabBarHeight = self.tabBarController?.tabBar.bounds.size.height {
            spacerHeight -= tabBarHeight
        }
*/
        spacerHeight -= StyleConfig.tabbarHeight;     // tabbarheight
        keyboardSpacerHeightConstraint.constant = max(spacerHeight, 0)

    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension UartModuleViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyleForPresentationController(PC: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {

        // MQTT
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
        }
        mqttUpdateStatusUI()
    }
}
