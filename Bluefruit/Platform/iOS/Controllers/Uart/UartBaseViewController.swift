//
//  UartBaseViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

import UIKit
import UIColor_Hex

class UartBaseViewController: PeripheralModeViewController {
    // Config
    fileprivate static var dataRxFont = UIFont(name: "CourierNewPSMT", size: 14)!
    fileprivate static var dataTxFont = UIFont(name: "CourierNewPS-BoldMT", size: 14)!
    
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
    fileprivate var mqttBarButtonItemImageView: UIImageView?
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
        case table          // Display a table where each data packet is a row
    }
    
    enum ExportFormat: String {
        case txt = "txt"
        case csv = "csv"
        case json = "json"
        case xml = "xml"
        case bin = "bin"
    }
    
    internal var uartData: UartPacketManagerBase!
    fileprivate let timestampDateFormatter = DateFormatter()
    fileprivate var tableCachedDataBuffer: [UartPacket]?
    fileprivate var textCachedBuffer = NSMutableAttributedString()
    
    private let keyboardPositionNotifier = KeyboardPositionNotifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        let localizationManager = LocalizationManager.shared
        displayModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_timestamp"), forSegmentAt: 0)
        displayModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_text"), forSegmentAt: 1)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_ascii"), forSegmentAt: 0)
        dataModeSegmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_hex"), forSegmentAt: 1)
        
        // Init options layout
        if UI_USER_INTERFACE_IDIOM() == .pad { //traitCollection.userInterfaceIdiom == .pad {            // iPad
            self.view.removeConstraint(statsLabeliPhoneLeadingConstraint)
            
            // Resize input UISwitch controls
            for subStackView in inputControlsStackView.subviews {
                for subview in subStackView.subviews {
                    if let switchView = subview as? UISwitch {
                        switchView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                    }
                }
            }
        } else {            // iPhone
            self.view.removeConstraint(statsLabeliPadLeadingConstraint)
            statsLabel.textAlignment = .left
            inputControlsStackView.isHidden = true
        }
        
        if !isInMultiUartMode() {
            // Mqtt init
            mqttBarButtonItemImageView = UIImageView(image: UIImage(named: "mqtt_disconnected")!.tintWithColor(self.view.tintColor))      // use a uiimageview as custom barbuttonitem to allow frame animations
            mqttBarButtonItemImageView!.tintColor = self.view.tintColor
            mqttBarButtonItemImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickMqtt)))
            
            if MqttSettings.shared.isConnected {
                let mqttManager = MqttManager.shared
                mqttManager.delegate = self
                mqttManager.connectFromSavedSettings()
            }
        }
        
        // Localization
        sendInputButton.setTitle(localizationManager.localizedString("uart_send_action"), for: .normal)
        
        
        // Note: uartData should be initialized on the subclasses
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Hide top controls on iPhone
        if UI_USER_INTERFACE_IDIOM() == .phone {// traitCollection.userInterfaceIdiom == .phone {
            controlsView.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        registerNotifications(enabled: true)
        
        // Update the navigation bar items
        if var rightButtonItems = navigationItem.rightBarButtonItems, rightButtonItems.count == 2 {
            
            if UI_USER_INTERFACE_IDIOM() == .pad { // traitCollection.userInterfaceIdiom == .pad {
                // Remove more item
                rightButtonItems.remove(at: 0)
                
                // Add mqtt bar item
                if !isInMultiUartMode() {
                    mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                    rightButtonItems.append(mqttBarButtonItem)
                }
            } else {
                // Add mqtt bar item
                if !isInMultiUartMode() {
                    mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
                    rightButtonItems.append(mqttBarButtonItem)
                }
            }
            
            navigationItem.rightBarButtonItems = rightButtonItems
        }
        
        // UI
        reloadDataUI()
        reloadControlsUI()
        
        // Enable Uart
        setupUart()
        
        // MQTT
        if !isInMultiUartMode() {
            if MqttSettings.shared.isConnected {
                MqttManager.shared.delegate = self
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
        
        let mqttManager = MqttManager.shared
        mqttManager.disconnect()
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "uartSettingsSegue" {
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
    private weak var didUpdatePreferencesObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdatePreferencesObserver = notificationCenter.addObserver(forName: .didUpdatePreferences, object: nil, queue: .main) { [weak self] _ in
                self?.reloadDataUI()
            }
        } else {
            if let didUpdatePreferencesObserver = didUpdatePreferencesObserver {notificationCenter.removeObserver(didUpdatePreferencesObserver)}
        }
    }
    
    // MARK: - UART
    internal func isInMultiUartMode() -> Bool {
        assert(false, "Should be implemented by subclasses")
        return false
    }
    
    internal func setupUart() {
        assert(false, "Should be implemented by subclasses")
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
    
    fileprivate func reloadControlsUI() {
        showEolSwitch.isOn = Preferences.uartIsAutomaticEolEnabled
        addEolSwitch.isOn = Preferences.uartIsEchoEnabled
        displayModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsDisplayModeTimestamp ? 0:1
        dataModeSegmentedControl.selectedSegmentIndex = Preferences.uartIsInHexMode ? 1:0
    }
    
    fileprivate func updateBytesUI() {
        let localizationManager = LocalizationManager.shared
        let sentBytesMessage = String(format: localizationManager.localizedString("uart_sentbytes_format"), arguments: [uartData.sentBytes])
        let receivedBytesMessage = String(format: localizationManager.localizedString("uart_receivedbytes_format"), arguments: [uartData.receivedBytes])
        
        statsLabel.text = String(format: "%@     %@", arguments: [sentBytesMessage, receivedBytesMessage])
    }
    
    internal func updateUartReadyUI(isReady: Bool) {
        inputTextField.isEnabled = isReady
        inputTextField.backgroundColor = isReady ? UIColor.white : UIColor.black.withAlphaComponent(0.1)
        sendInputButton.isEnabled = isReady
    }
    
    internal func send(message: String) {
        assert(false, "Should be implemented by subclasses")
    }
    
    // MARK: - UI Actions
    @objc func onClickMqtt() {
        let viewController = storyboard!.instantiateViewController(withIdentifier: "UartMqttSettingsViewController")
        viewController.modalPresentationStyle = .popover
        if let popovoverController = viewController.popoverPresentationController {
            popovoverController.barButtonItem = mqttBarButtonItem
            popovoverController.delegate = self
            // popovoverController.backgroundColor = UIColor.lightGray
        }
        present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func onClickSend(_ sender: AnyObject) {
        //guard let blePeripheral = blePeripheral else { return }
        
        var newText = inputTextField.text ?? ""
        
        // Eol
        if Preferences.uartIsAutomaticEolEnabled {
            newText += Preferences.uartEolCharacters
        }
        
        send(message: newText)
        
        inputTextField.text = ""
        inputTextField.resignFirstResponder()
    }
    
    
    @IBAction func onInputTextFieldEdidtingDidEndOnExit(_ sender: UITextField) {
        onClickSend(sender)
    }
    
    @IBAction func onClickClear(_ sender: AnyObject) {
        uartData.clearPacketsCache()
        reloadDataUI()
    }
    
    @IBAction func onClickExport(_ sender: AnyObject) {
        let packets = uartData.packetsCache()
        guard !packets.isEmpty else {
            showDialogWarningNoTextToExport()
            return
        }
        
        let localizationManager = LocalizationManager.shared
        let alertController = UIAlertController(title: localizationManager.localizedString("uart_export_format_title"), message: localizationManager.localizedString("uart_export_format_subtitle"), preferredStyle: .actionSheet)
        let isHexFormat = Preferences.uartIsInHexMode
        
        for exportFormat in UartModeViewController.kExportFormats {
            let exportAction = UIAlertAction(title: exportFormat.rawValue, style: .default) { [unowned self] _ in
                
                var exportObject: AnyObject?
                
                switch exportFormat {
                case .txt:
                    exportObject = UartDataExport.packetsAsText(packets, isHexFormat: isHexFormat) as AnyObject
                case .csv:
                    exportObject = UartDataExport.packetsAsCsv(packets, isHexFormat: isHexFormat) as AnyObject
                case .json:
                    exportObject = UartDataExport.packetsAsJson(packets, isHexFormat: isHexFormat) as AnyObject
                case .xml:
                    exportObject = UartDataExport.packetsAsXml(packets, isHexFormat: isHexFormat) as AnyObject
                case .bin:
                    exportObject = UartDataExport.packetsAsBinary(packets) as AnyObject
                }
                
                self.export(object: exportObject)
            }
            alertController.addAction(exportAction)
        }
        
        let cancelAction = UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler:nil)
        alertController.addAction(cancelAction)
        
        alertController.popoverPresentationController?.sourceView = exportButton
        alertController.popoverPresentationController?.sourceRect = exportButton.bounds
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func export(object: AnyObject?) {
        if let object = object {
            // TODO: replace randomly generated iOS filenames: https://thomasguenzel.com/blog/2015/04/16/uiactivityviewcontroller-nsdata-with-filename/
            
            let activityViewController = UIActivityViewController(activityItems: [object], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = exportButton
            activityViewController.popoverPresentationController?.sourceRect = exportButton.bounds
            
            navigationController?.present(activityViewController, animated: true, completion: nil)
        } else {
            DLog("exportString with empty text")
            showDialogWarningNoTextToExport()
        }
    }
    
    private func showDialogWarningNoTextToExport() {
        let localizationManager = LocalizationManager.shared
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
        let localizationManager = LocalizationManager.shared
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("uart_help_text"), title: localizationManager.localizedString("uart_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
    
    // MARK: - Style
    internal func colorForPacket(packet: UartPacket) -> UIColor {
        assert(false, "Should be implemented by subclasses")
        return .black
    }
    
    fileprivate func fontForPacket(packet: UartPacket) -> UIFont {
        let font = packet.mode == .tx ? UartModeViewController.dataTxFont : UartModeViewController.dataRxFont
        return font
    }
}

// MARK: - UITableViewDataSource
extension UartBaseViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if Preferences.uartIsEchoEnabled {
            tableCachedDataBuffer = uartData.packetsCache()
        } else {
            tableCachedDataBuffer = uartData.packetsCache().filter({ (dataPacket: UartPacket) -> Bool in
                dataPacket.mode == .rx
            })
        }
        
        return tableCachedDataBuffer?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "TimestampCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath)
        
        // Data binding in cellForRowAtIndexPath to avoid problems with multiple-line labels and dynamic tableview height calculation
        let dataPacket = tableCachedDataBuffer![indexPath.row]
        let date = Date(timeIntervalSinceReferenceDate: dataPacket.timestamp)
        let dateString = timestampDateFormatter.string(from: date)
        let modeString = LocalizationManager.shared.localizedString(dataPacket.mode == .rx ? "uart_timestamp_direction_rx" : "uart_timestamp_direction_tx")
        let color = colorForPacket(packet: dataPacket)
        let font = fontForPacket(packet: dataPacket)
        
        let timestampCell = cell as! UartTimetampTableViewCell
        
        timestampCell.timeStampLabel.text = String(format: "%@ %@", arguments: [dateString, modeString])
        
        if let attributedText = attributedStringFromData(dataPacket.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: font), attributedText.length > 0 {
            timestampCell.dataLabel.attributedText = attributedText
        } else {
            timestampCell.dataLabel.attributedText = NSAttributedString(string: " ")        // space to maintain height
        }
        
        timestampCell.contentView.backgroundColor = indexPath.row%2 == 0 ? UIColor.white : UIColor(hex: 0xeeeeee)
        return cell
    }
}

// MARK: UITableViewDelegate
extension UartBaseViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

// MARK: - UartPacketManagerDelegate
extension UartBaseViewController: UartPacketManagerDelegate {
    
    func onUartPacket(_ packet: UartPacket) {
        // Check that the view has been initialized before updating UI
        guard isViewLoaded && view.window != nil && baseTableView != nil else { return }
        
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
    
    @objc func reloadData() {
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
        guard Preferences.uartIsEchoEnabled || packet.mode == .rx else { return }
        
        let color = colorForPacket(packet: packet)
        let font = fontForPacket(packet: packet)
        
        if let attributedString = attributedStringFromData(packet.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: font) {
            textCachedBuffer.append(attributedString)
        }
    }
    
    func mqttUpdateStatusUI() {
        guard let imageView = mqttBarButtonItemImageView, let tintColor = self.view.tintColor else { return }
        
        let status = MqttManager.shared.status
        
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
        let localizationManager = LocalizationManager.shared
        
        let alertMessage = isConnectionError ? localizationManager.localizedString("uart_mqtt_connectionerror_title") : message
        let alertController = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension UartBaseViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        // Note: same delegate used for MQTT popover and Export popover
        
        // MQTT
        let mqttManager = MqttManager.shared
        if MqttSettings.shared.isConnected {
            mqttManager.delegate = self
        }
        mqttUpdateStatusUI()
    }
}

// MARK: - KeyboardPositionNotifierDelegate
extension UartBaseViewController: KeyboardPositionNotifierDelegate {
    
    func onKeyboardPositionChanged(keyboardFrame: CGRect, keyboardShown: Bool) {
        var spacerHeight = keyboardFrame.height
        spacerHeight -= StyleConfig.tabbarHeight
        keyboardSpacerHeightConstraint.constant = max(spacerHeight, 0)
    }
}

// MARK: - MqttManagerDelegate
extension UartBaseViewController: MqttManagerDelegate {
    func onMqttConnected() {
        DispatchQueue.main.async {
            self.mqttUpdateStatusUI()
        }
    }
    
    func onMqttDisconnected() {
        DispatchQueue.main.async {
            self.mqttUpdateStatusUI()
        }
    }
    
    @objc func onMqttMessageReceived(message: String, topic: String) {
        assert(false, "should be overrided by subclasses")
    }
    
    func onMqttError(message: String) {
        let mqttManager = MqttManager.shared
        let status = mqttManager.status
        let isConnectionError = status == .connecting
        
        DispatchQueue.main.async {
            self.mqttError(message: message, isConnectionError: isConnectionError)
        }
    }
}

