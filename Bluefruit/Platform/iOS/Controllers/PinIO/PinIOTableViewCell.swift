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

        let localizationManager = LocalizationManager.shared
        let fullName = pin.isAnalog ? String(format: localizationManager.localizedString("pinio_pinname_analog_format"), pin.digitalPinId, pin.analogPinId) : String(format: localizationManager.localizedString("pinio_pinname_digital_format"), pin.digitalPinId)
        nameLabel.text = fullName
        modeLabel.text = modeDescription(pin.mode)

        var valueText: String?
        switch pin.mode {
        case .input:
            valueText = digitalValueDescription(pin.digitalValue)
        case .output:
            valueText = digitalValueDescription(pin.digitalValue)
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
    
    private func modeDescription(_ mode: PinIOModuleManager.PinData.Mode) -> String {
        let localizationManager = LocalizationManager.shared
        
        var resultStringId: String
        switch mode {
        case .input: resultStringId = "pinio_pintype_input"
        case .output: resultStringId = "pinio_pintype_output"
        case .analog:  resultStringId = "pinio_pintype_analog"
        case .pwm: resultStringId = "pinio_pintype_pwm"
        case .servo: resultStringId = "pinio_pintype_servo"
        default: resultStringId =  "pinio_pintype_unknown"
        }

        return localizationManager.localizedString(resultStringId)
    }

    private func digitalValueDescription(_ digitalValue: PinIOModuleManager.PinData.DigitalValue) -> String {
        let localizationManager = LocalizationManager.shared
        
        var resultStringId: String
        switch digitalValue {
        case .low: resultStringId = "pinio_pintype_low"
        case .high: resultStringId = "pinio_pintype_high"
        }
        
        return localizationManager.localizedString(resultStringId)
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
            let modeName = modeDescription(mode)
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
