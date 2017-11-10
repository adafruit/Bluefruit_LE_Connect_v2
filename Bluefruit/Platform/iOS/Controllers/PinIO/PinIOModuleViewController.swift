//
//  PinIOModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PinIOModeViewController: PeripheralModeViewController {

    fileprivate var pinIO: PinIOModuleManager!

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    fileprivate var tableRowOpen: Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("pinio_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("pinio_tab_title")

        // Init
        assert(blePeripheral != nil)
        pinIO = PinIOModuleManager(blePeripheral: blePeripheral!, delegate: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DLog("PinIO viewWillAppear")
        if isMovingToParentViewController {       // To keep working while the help is displayed

            pinIO.start { error in
                DispatchQueue.main.async { [weak self] in
                    guard let context = self else {
                        return
                    }

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

                    // Uart Ready
                    if context.pinIO.pins.count == 0 && !context.pinIO.isQueryingCapabilities() {
                        context.startQueryCapabilitiesProcess()
                    }
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParentViewController {       // To keep working while the help is displayed

            // if a dialog is being shown, dismiss it. For example: when querying capabilities but a didmodifyservices callback is received and pinio is removed from the tabbar
            if let presentedViewController = presentedViewController {
                presentedViewController.dismiss(animated: true, completion: nil)
            }

            DLog("PinIO viewWillDisappear")
            pinIO.stop()

        }
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
            DLog("error: queryCapabilities called while querying capabilities")
            return
        }

        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("pinio_capabilityquery_querying_title"), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: { [weak self] (_) -> Void in
            self?.pinIO.endPinQuery(abort: true)
            }))

        self.present(alertController, animated: true) {[weak self] () -> Void in
            // Query Capabilities
            self?.pinIO.queryCapabilities()
        }
    }

    func defaultCapabilitiesAssumedDialog() {

        DLog("QueryCapabilities not found")
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: localizationManager.localizedString("pinio_capabilityquery_expired_title"), message: localizationManager.localizedString("pinio_capabilityquery_expired_message"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { (_) -> Void in
        })
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: - Actions
    @IBAction func onClickQuery(_ sender: AnyObject) {
        setupFirmata()
    }

    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("pinio_help_text"), title: localizationManager.localizedString("pinio_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension PinIOModeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pinIO.pins.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString("pinio_pins_header")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PinCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }

}

// MARK: UITableViewDelegate
extension PinIOModeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let pin = pinIO.pins[indexPath.row]
        let pinCell = cell as! PinIOTableViewCell
        pinCell.setPin(pin)

        pinCell.tag = indexPath.row
        pinCell.delegate = self
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let tableRowOpen = tableRowOpen, indexPath.row == tableRowOpen {
            let pinOpen = pinIO.pins[tableRowOpen]
            return pinOpen.mode == .input || pinOpen.mode == .analog ? 100 : 160
        } else {
            return 44
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: PinIoTableViewCellDelegate
extension PinIOModeViewController: PinIoTableViewCellDelegate {
    func onPinToggleCell(pinIndex: Int) {
        // Change open row
        tableRowOpen = pinIndex == tableRowOpen ? nil: pinIndex

        // Animate changes
        baseTableView.beginUpdates()
        baseTableView.endUpdates()
    }
    func onPinModeChanged(_ mode: PinIOModuleManager.PinData.Mode, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setControlMode(pin: pin, mode: mode)

        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
    }
    func onPinDigitalValueChanged(_ value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin: pin, value: value)

        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
    }
    func onPinAnalogValueChanged(_ value: Float, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin: pin, value: Int(value)) {
            baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
        }
    }
}

extension PinIOModeViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(isDefaultConfigurationAssumed: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.baseTableView.reloadData()

            self?.presentedViewController?.dismiss(animated: true, completion: { [weak self] () -> Void in
                if isDefaultConfigurationAssumed {
                    self?.defaultCapabilitiesAssumedDialog()
                }
            })
        }
    }

    func onPinIODidReceivePinState() {
        DispatchQueue.main.async { [weak self] in
            self?.baseTableView.reloadData()
        }
    }

}
