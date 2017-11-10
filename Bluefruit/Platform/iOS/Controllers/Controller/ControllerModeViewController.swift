//
//  ControllerModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerModeViewController: PeripheralModeViewController {

    // Constants
    fileprivate static let kPollInterval = 0.25

    fileprivate static let kSensorTitleKeys: [String] = ["controller_sensor_quaternion", "controller_sensor_accelerometer", "controller_sensor_gyro", "controller_sensor_magnetometer", "controller_sensor_location"]
    fileprivate static let kModuleTitleKeys: [String] = ["controller_module_pad", "controller_module_colorpicker"]

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var uartWaitingLabel: UILabel!

    // Data
    fileprivate var controllerData: ControllerModuleManager!
    fileprivate var contentItems = [Int]()
    fileprivate weak var controllerPadViewController: ControllerPadViewController?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("controller_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("controller_tab_title")
        
        // Init
        assert(blePeripheral != nil)
        controllerData = ControllerModuleManager(blePeripheral: blePeripheral!, delegate: self)

        updateUartUI(isReady: false)

        //
        updateContentItemsFromSensorsEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isMovingToParentViewController {       // To keep streaming data when pushing a child view
            controllerData.start(pollInterval: ControllerModeViewController.kPollInterval) { [unowned self] in
                self.baseTableView.reloadData()
            }

            // Watch
            WatchSessionManager.sharedInstance.updateApplicationContext(mode: .controller)

            // Notifications
            registerNotifications(enabled: true)
        } else {
            // Disable cache if coming back grom Control Pad
            controllerData.isUartRxCacheEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParentViewController {     // To keep streaming data when pushing a child view
            controllerData.stop()

            // Watch
            WatchSessionManager.sharedInstance.updateApplicationContext(mode: .connected)

            // Notifications
            registerNotifications(enabled: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        DLog("ControllerModeViewController deinit")
    }

    // MARK: - UI
    fileprivate func updateUartUI(isReady: Bool) {
        // Setup UI
        uartWaitingLabel.isHidden = isReady
        baseTableView.isHidden = !isReady
    }

    fileprivate let kDetailItemOffset = 100
    fileprivate func updateContentItemsFromSensorsEnabled() {
        var items = [Int]()
        var i = 0
        for j in 0..<ControllerModuleManager.numSensors {
            let isSensorEnabled = controllerData.isSensorEnabled(index: j)
            items.append(i)
            if isSensorEnabled {
                items.append(i+kDetailItemOffset)
            }
            i += 1
        }

        contentItems = items
    }

    // MARK: Notifications
    private weak var didReceiveWatchCommandObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didReceiveWatchCommandObserver = notificationCenter.addObserver(forName: .didReceiveWatchCommand, object: nil, queue: .main, using: didReceiveWatchCommand)
        } else {
            if let didReceiveWatchCommandObserver = didReceiveWatchCommandObserver {notificationCenter.removeObserver(didReceiveWatchCommandObserver)}
        }
    }

    private func didReceiveWatchCommand(notification: Notification) {
        if let message = notification.userInfo, let command = message["command"] as? String {
            DLog("watchCommand notification: \(command)")
            switch command {
            case "controlPad":
                if let tag = (message["tag"] as AnyObject).integerValue {
                    sendTouchEvent(tag: tag, isPressed: true)
                    sendTouchEvent(tag: tag, isPressed: false)
                }

            case "color":
                if  let colorUInt = message["color"] as? UInt, let color = colorFrom(hex: colorUInt) {
                    sendColor(color)
                }

            default:
                DLog("watchCommand with unknown command: \(command)")
            }
        }
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_  sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("controller_help_text"), title: localizationManager.localizedString("controller_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    // MARK: - Send Data
    fileprivate func sendColor(_ color: UIColor) {
        let brightness: CGFloat = 1
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness

        let selectedColorComponents = [UInt8(255.0 * Float(red)), UInt8(255.0 * Float(green)), UInt8(255.0 * Float(blue))]

        sendColorComponents(selectedColorComponents)
    }

    fileprivate func sendColorComponents(_ selectedColorComponents: [UInt8]) {
        var data = Data()
        let prefixData = ControllerColorWheelViewController.prefix.data(using: String.Encoding.utf8)!
        data.append(prefixData)
        for var component in selectedColorComponents {
            data.append(&component, count: MemoryLayout<UInt8>.size)
        }

        controllerData.sendCrcData(data)
    }

    func sendTouchEvent(tag: Int, isPressed: Bool) {
        let message = "!B\(tag)\(isPressed ? "1" : "0")"
        if let data = message.data(using: String.Encoding.utf8) {
            controllerData.sendCrcData(data)
        }
    }
}

// MARK: - ControllerColorWheelViewControllerDelegate
extension ControllerModeViewController: ControllerColorWheelViewControllerDelegate {
    func onSendColorComponents(_ colorComponents: [UInt8]) {
        sendColorComponents(colorComponents)
    }
}

// MARK: - ControllerPadViewControllerDelegate
extension ControllerModeViewController: ControllerPadViewControllerDelegate {
    func onSendControllerPadButtonStatus(tag: Int, isPressed: Bool) {
        sendTouchEvent(tag: tag, isPressed: isPressed)
    }
}

// MARK: - UITableViewDataSource
extension ControllerModeViewController : UITableViewDataSource {

    enum ControllerSection: Int {
        case sensorData = 0
        case module = 1
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            //let enabledCount = sensorsEnabled.filter{ $0 }.count
            //return ControllerModeViewController.kSensorTitleKeys.count + enabledCount
            return contentItems.count
        case .module:
            return ControllerModeViewController.kModuleTitleKeys.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var localizationKey: String!

        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            localizationKey = "controller_sensor_title"
        case .module:
            localizationKey = "controller_module_title"
        }

        return LocalizationManager.sharedInstance.localizedString(localizationKey)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let localizationManager = LocalizationManager.sharedInstance
        var cell: UITableViewCell!
        switch ControllerSection(rawValue: indexPath.section)! {

        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset

            if isDetailCell {
                let sensorIndex = item - kDetailItemOffset
                let reuseIdentifier = "ComponentsCell"
                let componentsCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerComponentsTableViewCell

                let componentNameKeys: [String]
                if sensorIndex == ControllerModuleManager.ControllerType.location.rawValue {
                    componentNameKeys = ["lat", "long", "alt"]
                } else {
                    componentNameKeys = ["x", "y", "z", "w"]
                }
                if let sensorData = controllerData.getSensorData(index: sensorIndex) {
                    var i=0
                    for subview in componentsCell.componentsStackView.subviews {
                        let hasComponent = i<sensorData.count
                        subview.isHidden = !hasComponent
                        if let label = subview as? UILabel, hasComponent {
                            let attributedText = NSMutableAttributedString(string: "\(componentNameKeys[i]): \(sensorData[i])")
                            let titleLength = componentNameKeys[i].lengthOfBytes(using: String.Encoding.utf8)
                            attributedText.addAttribute(NSAttributedStringKey.font, value: UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.medium), range: NSMakeRange(0, titleLength))
                            label.attributedText = attributedText
                        }

                        i += 1
                    }
                } else {
                    for subview in componentsCell.componentsStackView.subviews {
                        subview.isHidden = true
                    }
                }

                cell = componentsCell
            } else {
                let reuseIdentifier = "SensorCell"
                let sensorCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerSensorTableViewCell
                sensorCell.titleLabel!.text = localizationManager.localizedString( ControllerModeViewController.kSensorTitleKeys[item])

                sensorCell.enableSwitch.isOn = controllerData.isSensorEnabled(index: item)
                sensorCell.onSensorEnabled = { [unowned self] (enabled) in

                    if self.controllerData.isSensorEnabled(index: item) != enabled {       // if changed
                        let errorMessage = self.controllerData.setSensorEnabled(enabled, index:item)

                        if let errorMessage = errorMessage {
                            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: errorMessage, preferredStyle: .alert)

                            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }

                        self.updateContentItemsFromSensorsEnabled()

                        /* Not used because the animation for the section title looks weird. Used a reloadData instead
                        if let currentRow = self.contentItems.indexOf(item) {
                            let detailIndexPath = NSIndexPath(forRow: currentRow+1, inSection: indexPath.section)
                            if enabled {
                                tableView.insertRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Top)
                            }
                            else {
                                tableView.deleteRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Bottom)
                            }
                        }
                        */

                    }

                    self.baseTableView.reloadData()
                }
                cell = sensorCell
            }

        case .module:
            let reuseIdentifier = "ModuleCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            }
            cell.accessoryType = .disclosureIndicator
            cell.textLabel!.text = localizationManager.localizedString(ControllerModeViewController.kModuleTitleKeys[indexPath.row])
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch ControllerSection(rawValue: indexPath.section)! {
        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            return isDetailCell ? 120: 44
        default:
            return 44
        }
    }
}

// MARK: UITableViewDelegate
extension ControllerModeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch ControllerSection(rawValue: indexPath.section)! {
        case .module:
            if indexPath.row == 0 {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerPadViewController") as? ControllerPadViewController {
                    controllerPadViewController = viewController
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)

                    // Enable cache for control pad
                    controllerData.uartRxCacheReset()
                    controllerData.isUartRxCacheEnabled = true
                }
            } else {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerColorWheelViewController") as? ControllerColorWheelViewController {
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)
                }
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - ControllerModuleManagerDelegate
extension ControllerModeViewController: ControllerModuleManagerDelegate {
    func onControllerUartIsReady(error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let context = self else { return }

            context.updateUartUI(isReady: error == nil)
            guard error == nil else {
                DLog("Error initializing uart")
                context.dismiss(animated: true, completion: { [weak self] in
                    if let context = self {
                        showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")

                        if let blePeripheral = context.blePeripheral {
                            BleManager.sharedInstance.disconnect(from: blePeripheral)
                        }
                    }
                })
                return
            }

            // Uart Ready
            context.baseTableView.reloadData()
        }
    }

    func onUarRX() {
        // Uart data recevied

        // Only reloadData when controllerPadViewController is loaded
        guard controllerPadViewController != nil else { return }

        self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls
    }

    func reloadData() {
        // Refresh the controllerPadViewController uart text
        self.controllerPadViewController?.setUartText(self.controllerData.uartTextBuffer())

    }
}
