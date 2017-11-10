//
//  PeripheralTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class PeripheralTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var baseStackView: UIStackView!
    @IBOutlet weak var rssiImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var connectButton: StyledConnectButton!
    @IBOutlet weak var disconnectButton: StyledConnectButton!
    @IBOutlet weak var disconnectButtonWidthConstraint: NSLayoutConstraint!

    @IBOutlet weak var detailBaseStackView: UIStackView!
    @IBOutlet weak var servicesStackView: UIStackView!
    @IBOutlet weak var servicesOverflowStackView: UIStackView!
    @IBOutlet weak var servicesSolicitedStackView: UIStackView!
    @IBOutlet weak var txPowerLevelValueLabel: UILabel!
    @IBOutlet weak var localNameValueLabel: UILabel!
    @IBOutlet weak var manufacturerValueLabel: UILabel!
    @IBOutlet weak var connectableValueLabel: UILabel!

    // Params
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?

    // Data
    fileprivate var cachedExtendedViewPeripheralId: UUID?

    // MARK: - View Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        manufacturerValueLabel.text = nil
        txPowerLevelValueLabel.text = nil

        let rightMarginInset = contentView.bounds.size.width - baseStackView.frame.maxX     // reposition button because it is outside the hierchy
        //DLog("right margin: \(rightMarginInset)")
        connectButton.titleEdgeInsets.right += rightMarginInset
        disconnectButton.titleEdgeInsets.right += rightMarginInset
        
        let localizationManager = LocalizationManager.sharedInstance
        connectButton.setTitle(localizationManager.localizedString("scanresult_connect"), for: .normal)
        disconnectButton.setTitle(localizationManager.localizedString("scanresult_disconnect"), for: .normal)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Remove cached data
        cachedExtendedViewPeripheralId = nil
    }

    // MARK: - Actions
    @IBAction func onClickDisconnect(_ sender: AnyObject) {
        onDisconnect?()
    }

    @IBAction func onClickConnect(_ sender: AnyObject) {
        onConnect?()
    }

    // MARK: - UI
    func showDisconnectButton(show: Bool) {
        disconnectButtonWidthConstraint.constant = show ? 24: 0
    }

    func setupPeripheralExtendedView(peripheral: BlePeripheral) {
        guard cachedExtendedViewPeripheralId != peripheral.identifier else { return }       // If data is already filled, skip

        cachedExtendedViewPeripheralId = peripheral.identifier
        var currentIndex = 0

        // Local Name
        var isLocalNameAvailable = false
        if let localName = peripheral.advertisement.localName {
            localNameValueLabel.text = localName
            isLocalNameAvailable = true
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !isLocalNameAvailable
        currentIndex = currentIndex+1

        // Manufacturer Name
        var isManufacturerAvailable = false
        if let manufacturerString = peripheral.advertisement.manufacturerString {
            manufacturerValueLabel.text = manufacturerString
            isManufacturerAvailable = true
        } else {
            manufacturerValueLabel.text = nil
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !isManufacturerAvailable
        currentIndex = currentIndex+1

        // Services
        var areServicesAvailable = false
        if let services = peripheral.advertisement.services, !services.isEmpty, let stackView = servicesStackView {
            //DLog("services: \(services.count)")
            addServiceNames(stackView: stackView, services: services)
            areServicesAvailable = services.count > 0
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !areServicesAvailable
        currentIndex = currentIndex+1

        // Services Overflow
        var areServicesOverflowAvailable = false
        if let servicesOverflow =  peripheral.advertisement.servicesOverflow, !servicesOverflow.isEmpty, let stackView = servicesOverflowStackView {
            addServiceNames(stackView: stackView, services: servicesOverflow)
            areServicesOverflowAvailable = servicesOverflow.count > 0
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !areServicesOverflowAvailable
        currentIndex = currentIndex+1

        // Solicited Services
        var areSolicitedServicesAvailable = false
        if let servicesSolicited = peripheral.advertisement.servicesSolicited, !servicesSolicited.isEmpty, let stackView = servicesOverflowStackView {
            addServiceNames(stackView: stackView, services: servicesSolicited)
            areSolicitedServicesAvailable = servicesSolicited.count > 0
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !areSolicitedServicesAvailable
        currentIndex = currentIndex+1

        // Tx Power
        var isTxPowerAvailable: Bool
        if let txPower = peripheral.advertisement.txPower {
            txPowerLevelValueLabel.text = String(txPower)
            isTxPowerAvailable = true
        } else {
            isTxPowerAvailable = false
        }
        detailBaseStackView.arrangedSubviews[currentIndex].isHidden = !isTxPowerAvailable
        currentIndex = currentIndex+1

        // Connectable
        let isConnectable = peripheral.advertisement.isConnectable
        connectableValueLabel.text = isConnectable != nil ? "\(isConnectable! ? "true":"false")":"unknown"
        currentIndex = currentIndex+1

    }

    private func addServiceNames(stackView: UIStackView, services: [CBUUID]) {
        let styledLabel = stackView.arrangedSubviews.first! as! UILabel
        styledLabel.isHidden = true     // The first view is only to define style in InterfaceBuilder. Hide it

        // Clear current subviews
        for arrangedSubview in stackView.arrangedSubviews {
            if arrangedSubview != stackView.arrangedSubviews.first {
                arrangedSubview.removeFromSuperview()
                stackView.removeArrangedSubview(arrangedSubview)
            }
        }

        // Add services as subviews
        for serviceCBUUID in services {
            let label = UILabel()
            var identifier = serviceCBUUID.uuidString
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            label.text = identifier
            label.font = styledLabel.font
            label.minimumScaleFactor = styledLabel.minimumScaleFactor
            label.adjustsFontSizeToFitWidth = styledLabel.adjustsFontSizeToFitWidth
            stackView.addArrangedSubview(label)
        }
    }
}
