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

    // Export
    fileprivate static let kExportFormats: [ExportFormat] = [.txt, .csv, .json/*, .xml*/, .bin]
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var baseTextView: UITextView!
    @IBOutlet weak var statsLabel: UILabel!
    @IBOutlet weak var statsLabeliPadLeadingConstraint: NSLayoutConstraint!         // remove ipad or iphone depending on the platform
    @IBOutlet weak var statsLabeliPhoneLeadingConstraint: NSLayoutConstraint!       // remove ipad or iphone depending on the platform

    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var sendInputButton: UIButton!
    @IBOutlet weak var keyboardSpacerHeightConstraint: NSLayoutConstraint!
    
    fileprivate var mqttBarButtonItem: UIBarButtonItem!
    fileprivate var mqttBarButtonItemImageView : UIImageView?
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
    
    enum ExportFormat: String {
        case txt = "txt"
        case csv = "csv"
        case json = "json"
        case xml = "xml"
        case bin = "bin"
    }
    
    fileprivate var uartData: UartPacketManager!
    fileprivate var txColor = Preferences.uartSentDataColor
    fileprivate var rxColor = Preferences.uartReceveivedDataColor
    fileprivate let timestampDateFormatter = DateFormatter()
    fileprivate var tableCachedDataBuffer: [UartPacket]?
    fileprivate var textCachedBuffer = NSMutableAttributedString()
    
    private let keyboardPositionNotifier = KeyboardPositionNotifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("peripherallist_unnamed")
        let title = String(format: localizationManager.localizedString("uart_navigation_title_format"), arguments: [name])
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
        
        if !isInMultiUartMode() {
            // Mqtt init
            mqttBarButtonItemImageView = UIImageView(image: UIImage(named: "mqtt_disconnected")!.tintWithColor(self.view.tintColor))      // use a uiimageview as custom barbuttonitem to allow frame animations
            mqttBarButtonItemImageView!.tintColor = self.view.tintColor
            mqttBarButtonItemImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UartModeViewController.onClickMqtt)))
            
            let mqttManager = MqttManager.sharedInstance
            if MqttSettings.sharedInstance.isConnected {
                mqttManager.delegate = self
                mqttManager.connectFromSavedSettings()
            }
        }
        
        // Init Uart
        uartData = UartPacketManager(delegate: self, isPacketCacheEnabled: true, isMqttEnabled: true)
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
        
        registerNotifications(enabled: true)
        
        // Update the navgation bar items
        if var rightButtonItems = navigationController?.navigationItem.rightBarButtonItems, rightButtonItems.count == 2 {
            
            if traitCollection.userInterfaceIdiom == .pad {
                // Remove more item
                rightButtonItems.remove(at: 0)
                
                // Add mqtt bar item
                if !isInMultiUartMode() {
                    mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                    rightButtonItems.append(mqttBarButtonItem)
                }
            }
            else {
                // Add mqtt bar item
                if !isInMultiUartMode() {
                    mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                    rightButtonItems.append(mqttBarButtonItem)
                }
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
        setupUart()
        
        // MQTT
        if !isInMultiUartMode() {
            let mqttManager = MqttManager.sharedInstance
            if MqttSettings.sharedInstance.isConnected {
                mqttManager.delegate = self
            }
            mqttUpdateStatusUI()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        registerNotifications(enabled: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        
        baseTableView.enh_cancelPendingReload()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        uartData = nil
        
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
    fileprivate func isInMultiUartMode() -> Bool {
        return blePeripheral == nil
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "uartSettingsSegue"  {
            if let controller = segue.destination.popoverPresentationController {
                controller.delegate = self
                //controller.backgroundColor = UIColor.lightGray
                
                let uartSettingsViewController = segue.destination as! UartSettingsViewController
                uartSettingsViewController.onClickClear = { [unowned self] in
                    self.onClickClear(self)
                }
                uartSettingsViewController.onClickExport = { [unowned self] in
                    self.onClickExport(self)
                }
            }
        }
    }
    
    
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
    
    // MARK: - UART
    fileprivate func setupUart() {
        updateUartReadyUI(isReady: false)
        
        if isInMultiUartMode() {
            let blePeripherals = BleManager.sharedInstance.connectedPeripherals()
            for blePeripheral in blePeripherals {
                blePeripheral.uartEnable(uartRxHandler: uartData.rxPacketReceived) { [weak self] error in
                    guard let context = self else {
                        return
                    }
                    
                    let peripheralName = blePeripheral.name ?? blePeripheral.identifier.uuidString
                    DispatchQueue.main.async { [unowned context] in
                        guard error == nil else {
                            DLog("Error initializing uart")
                            context.dismiss(animated: true, completion: { [weak self] () -> Void in
                                if let context = self {
                                    showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized for peripheral: \(peripheralName)")
                                    
                                    BleManager.sharedInstance.disconnect(from: blePeripheral)
                                }
                            })
                            return
                        }
                        
                        // Done
                        DLog("Uart enabled for \(peripheralName)")
                        
                    }
                }
            }
        }
        else {
            blePeripheral?.uartEnable(uartRxHandler: uartData.rxPacketReceived) { [weak self] error in
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
        }
    }
    
    
    
    // MARK: - UI Updates
    private func reloadDataUI() {
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text
        
        baseTableView.isHidden = displayMode == .text
        baseTextView.isHidden = displayMode == .table
        
        switch displayMode {
        case .text:
            
            textCachedBuffer.setAttributedString(NSAttributedString())
            let dataPackets = uartData.packetsCache()
            for dataPacket in dataPackets {
                onUartPacketText(dataPacket)
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
    
    private func updateUartReadyUI(isReady: Bool) {
        inputTextField.isEnabled = isReady
        inputTextField.backgroundColor = isReady ? UIColor.white : UIColor.black.withAlphaComponent(0.1)
        sendInputButton.isEnabled = isReady
    }

    // MARK: - UI Actions
    func onClickMqtt() {
        let viewController = storyboard!.instantiateViewController(withIdentifier: "UartMqttSettingsViewController")
        viewController.modalPresentationStyle = .popover
        if let popovoverController = viewController.popoverPresentationController
        {
            popovoverController.barButtonItem = mqttBarButtonItem
            popovoverController.delegate = self
           // popovoverController.backgroundColor = UIColor.lightGray
        }
        present(viewController, animated: true, completion: nil)
    }

    @IBAction func onClickSend(_ sender: AnyObject) {
        guard let blePeripheral = blePeripheral else { return }
        
        var newText = inputTextField.text ?? ""
        
        // Eol
        if Preferences.uartIsAutomaticEolEnabled {
            newText += "\n"
        }
        
        uartData.send(blePeripheral: blePeripheral, text: newText)
        inputTextField.text = ""
    }
    
    @IBAction func onInputTextFieldEdidtingDidEndOnExit(_ sender: UITextField) {
        onClickSend(sender)
    }
    
    @IBAction func onClickClear(_ sender: AnyObject) {
        uartData.clearPacketsCache()
        reloadDataUI()
    }
    
    @IBAction func onClickExport(_ sender: AnyObject) {
        let uartRxCache = uartData.packetsCache()
        guard !uartRxCache.isEmpty else {
            showDialogWarningNoTextToExport()
            return
        }
    
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: "Export data", message: "Choose the prefered format:", preferredStyle: .actionSheet)
        
        for exportFormat in UartModeViewController.kExportFormats {
            let exportAction = UIAlertAction(title: exportFormat.rawValue, style: .default) { [unowned self] (_) in
                
                var exportObject: AnyObject?
                
                switch(exportFormat) {
                case .txt:
                    exportObject = UartDataExport.packetsAsText(uartRxCache) as AnyObject
                case .csv:
                    exportObject = UartDataExport.packetsAsCsv(uartRxCache) as AnyObject
                case .json:
                    exportObject = UartDataExport.packetsAsJson(uartRxCache) as AnyObject
                case .xml:
                    exportObject = UartDataExport.packetsAsXml(uartRxCache) as AnyObject
                case .bin:
                    exportObject = UartDataExport.packetsAsBinary(uartRxCache) as AnyObject
                }
                
                self.export(object: exportObject)
            }
            alertController.addAction(exportAction)
        }
        
        let cancelAction = UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler:nil)
        alertController.addAction(cancelAction)
        
        alertController.popoverPresentationController?.sourceView = exportButton
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func export(object: AnyObject?) {
        if let object = object {
            // TODO: replace randomly generated iOS filenames: https://thomasguenzel.com/blog/2015/04/16/uiactivityviewcontroller-nsdata-with-filename/
            
            let activityViewController = UIActivityViewController(activityItems: [object], applicationActivities: nil)
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
            tableCachedDataBuffer = uartData.packetsCache()
        }
        else {
            tableCachedDataBuffer = uartData.packetsCache().filter({ (dataChunk: UartPacket) -> Bool in
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
    
    func onUartPacket(_ packet: UartPacket) {
        // Check that the view has been initialized before updating UI
        guard isViewLoaded && view.window != nil &&  baseTableView != nil else {
            return
        }
        
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text

        switch displayMode {
        case .text:
            onUartPacketText(packet)
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        case .table:
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls

        }

        updateBytesUI()
    }
    
    func reloadData() {
        let displayMode: UartModeViewController.DisplayMode = Preferences.uartIsDisplayModeTimestamp ? .table : .text
        switch displayMode {
        case .text:
            baseTextView.attributedText = textCachedBuffer
            
            let textLength = textCachedBuffer.length
            if textLength > 0 {
                let range = NSMakeRange(textLength - 1, 1)
                baseTextView.scrollRangeToVisible(range)
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
    
    fileprivate func onUartPacketText(_ packet: UartPacket) {
        if (Preferences.uartIsEchoEnabled || packet.mode == .rx) {
            let color = packet.mode == .tx ? txColor : rxColor
            
            if let attributedString = attributedStringFromData(packet.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartModeViewController.dataFont) {
                textCachedBuffer.append(attributedString)
            }
        }
    }
    
    func mqttUpdateStatusUI() {
        guard let imageView = mqttBarButtonItemImageView, let tintColor = self.view.tintColor else { return }
        
        let status = MqttManager.sharedInstance.status
        
        switch status {
        case .connecting:
            let imageFrames = [
                UIImage(named:"mqtt_connecting1")!.tintWithColor(tintColor),
                UIImage(named:"mqtt_connecting2")!.tintWithColor(tintColor),
                UIImage(named:"mqtt_connecting3")!.tintWithColor(tintColor)
            ]
            imageView.animationImages = imageFrames
            imageView.animationDuration = 0.5 * Double(imageFrames.count)
            imageView.animationRepeatCount = 0
            imageView.startAnimating()
            
        case .connected:
            imageView.stopAnimating()
            imageView.image = UIImage(named:"mqtt_connected")!.tintWithColor(tintColor)
            
        default:
            imageView.stopAnimating()
            imageView.image = UIImage(named:"mqtt_disconnected")!.tintWithColor(tintColor)
        }
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

// MARK: - UIPopoverPresentationControllerDelegate
extension UartModeViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        
        // MQTT
        let mqttManager = MqttManager.sharedInstance
        if MqttSettings.sharedInstance.isConnected {
            mqttManager.delegate = self
        }
        mqttUpdateStatusUI()
    }
}


// MARK: - KeyboardPositionNotifierDelegate
extension UartModeViewController: KeyboardPositionNotifierDelegate {
    
    func onKeyboardPositionChanged(keyboardFrame: CGRect, keyboardShown: Bool) {
        var spacerHeight = keyboardFrame.height
        spacerHeight -= StyleConfig.tabbarHeight
        keyboardSpacerHeightConstraint.constant = max(spacerHeight, 0)
    }
}


// MARK: - MqttManagerDelegate
extension UartModeViewController: MqttManagerDelegate {
    func onMqttConnected() {
        DispatchQueue.main.async { [unowned self] in
            self.mqttUpdateStatusUI()
        }
    }
    
    func onMqttDisconnected() {
        DispatchQueue.main.async { [unowned self] in
            self.mqttUpdateStatusUI()
        }
    }
    
    func onMqttMessageReceived(message: String, topic: String) {
        guard let blePeripheral = blePeripheral else { return }
        
        DispatchQueue.main.async { [unowned self] in
            self.uartData.send(blePeripheral: blePeripheral, text: message, wasReceivedFromMqtt: true)
        }
    }
    
    func onMqttError(message: String) {
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        let isConnectionError = status == .connecting
        
        DispatchQueue.main.async { [unowned self] in
            self.mqttError(message: message, isConnectionError: isConnectionError)
        }
    }
}
