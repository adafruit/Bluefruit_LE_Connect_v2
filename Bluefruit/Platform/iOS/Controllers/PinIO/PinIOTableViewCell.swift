//
//  PinIOTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol PinIoTableViewCellDelegate: class {
    func onPinToggleCell(pinIndex: Int)
    func onPinModeChanged(_ mode: PinIOModuleManager.PinData.Mode, pinIndex: Int)
    func onPinDigitalValueChanged(_ value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int)
    func onPinAnalogValueChanged(_ value: Float, pinIndex: Int)
}

class PinIOTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var digitalSegmentedControl: UISegmentedControl!
    @IBOutlet weak var valueSlider: UISlider!

    // Data
    weak var delegate: PinIoTableViewCellDelegate?
    private var modesInSegmentedControl: [PinIOModuleManager.PinData.Mode] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    // MARK: - Setup
    func setPin(_ pin: PinIOModuleManager.PinData) {
        setupModeSegmentedControl(pin: pin)
        digitalSegmentedControl.selectedSegmentIndex = pin.digitalValue.rawValue
        valueSlider.value = Float(pin.analogValue)

        let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
        let fullName = "Pin \(pin.digitalPinId)\(analogName)"
        nameLabel.text = fullName
        modeLabel.text = pin.mode.description

        var valueText: String?
        switch pin.mode {
        case .input:
            valueText = pin.digitalValue.description
        case .output:
            valueText = pin.digitalValue.description
        case .analog:
            valueText = String(pin.analogValue)
        case .pwm:
            valueText = String(pin.analogValue)

        default:
            valueText = ""
        }
        valueLabel.text = valueText

        valueSlider.isHidden = pin.mode != .pwm
        digitalSegmentedControl.isHidden = pin.mode != .output
    }

    private func setupModeSegmentedControl(pin: PinIOModuleManager.PinData) {
        modesInSegmentedControl.removeAll()
        if pin.isDigital == true {
            modesInSegmentedControl.append(.input)
            modesInSegmentedControl.append(.output)
        }
        if pin.isAnalog {
            modesInSegmentedControl.append(.analog)
        }
        if pin.isPWM {
            modesInSegmentedControl.append(.pwm)
        }

        modeSegmentedControl.removeAllSegments()
        for mode in modesInSegmentedControl {
            let modeName = mode.description
            modeSegmentedControl.insertSegment(withTitle: modeName, at: modeSegmentedControl.numberOfSegments, animated: false)
            if pin.mode == mode {
                modeSegmentedControl.selectedSegmentIndex = modeSegmentedControl.numberOfSegments-1    // Select the mode we just added
            }
        }
    }

    // MARK: - Actions
    @IBAction func onClickSelectButton(_ sender: UIButton) {
        delegate?.onPinToggleCell(pinIndex: tag)
    }

    @IBAction func onModeChanged(_ sender: UISegmentedControl) {
        delegate?.onPinModeChanged(modesInSegmentedControl[sender.selectedSegmentIndex], pinIndex: tag)
    }

    @IBAction func onDigitalChanged(_ sender: UISegmentedControl) {
        if let selectedDigital = PinIOModuleManager.PinData.DigitalValue(rawValue: sender.selectedSegmentIndex) {
            delegate?.onPinDigitalValueChanged(selectedDigital, pinIndex: tag)
        } else {
            DLog("Error onDigitalChanged with invalid value")
        }
    }

    @IBAction func onValueSliderChanged(_ sender: UISlider) {
        delegate?.onPinAnalogValueChanged(sender.value, pinIndex: tag)
    }
}
