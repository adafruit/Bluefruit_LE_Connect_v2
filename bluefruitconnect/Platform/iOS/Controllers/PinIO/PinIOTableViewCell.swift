//
//  PinIOTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol PinIoTableViewCellDelegate {
    func onPinToggleCell(pinIndex: Int)
    func onPinModeChanged(mode: PinIOModuleViewController.PinData.Mode, pinIndex: Int)
    func onPinDigitalValueChanged(value: PinIOModuleViewController.PinData.DigitalValue, pinIndex: Int)
    func onPinAnalogValueChanged(value: Float, pinIndex: Int)
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
    var delegate: PinIoTableViewCellDelegate?
    private var modesInSegmentedControl : [PinIOModuleViewController.PinData.Mode] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    // MARK: - Setup
    func setPin(pin : PinIOModuleViewController.PinData) {
        setupModeSegmentedControl(pin)
        digitalSegmentedControl.selectedSegmentIndex = 0
        valueSlider.value = Float(pin.analogValue)
        
        let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
        nameLabel.text = "Pin \(pin.digitalPinId)\(analogName)"
        modeLabel.text = stringForPinMode(pin.mode)
        
        var valueText: String?
        switch pin.mode {
        case .Input:
            valueText = stringForPinDigitalValue(pin.digitalValue)
        case .Output:
            valueText = stringForPinDigitalValue(pin.digitalValue)
        case .Analog:
            valueText = String(pin.analogValue)
        case .PWM:
            valueText = String(pin.analogValue)
            
        default:
            valueText = ""
        }
        valueLabel.text = valueText
        
        valueSlider.hidden = pin.mode != .PWM
        digitalSegmentedControl.hidden = pin.mode != .Output
    }
    
    private func setupModeSegmentedControl(pin : PinIOModuleViewController.PinData) {
        modesInSegmentedControl.removeAll()
        if pin.isDigital == true {
            modesInSegmentedControl.append(.Input)
            modesInSegmentedControl.append(.Output)
        }
        if pin.isAnalog {
            modesInSegmentedControl.append(.Analog)
        }
        if pin.isPWM {
            modesInSegmentedControl.append(.PWM)
        }

        modeSegmentedControl.removeAllSegments()
        for mode in modesInSegmentedControl {
            let modeName = stringForPinMode(mode)
            modeSegmentedControl.insertSegmentWithTitle(modeName, atIndex: modeSegmentedControl.numberOfSegments, animated: false)
            if pin.mode == mode {
                modeSegmentedControl.selectedSegmentIndex = modeSegmentedControl.numberOfSegments-1    // Select the mode we just added
            }
        }
    }
    
    func stringForPinMode(mode: PinIOModuleViewController.PinData.Mode)-> String {
        var modeString: String
        
        switch mode {
        case .Input:
            modeString = "Input"
        case .Output:
            modeString = "Output"
        case .Analog:
            modeString = "Analog"
        case .PWM:
            modeString = "PWM"
        case .Servo:
            modeString = "Servo"
        default:
            modeString = "NOT FOUND"
        }
        
        return modeString
    }
    
    func stringForPinDigitalValue(digitalValue: PinIOModuleViewController.PinData.DigitalValue)-> String {
        var valueString: String
        
        switch digitalValue {
        case .Low:
            valueString = "Low"
        case .High:
            valueString = "High"
        }
        return valueString
    }
    
    // MARK: - Actions
    @IBAction func onClickSelectButton(sender: UIButton) {
        delegate?.onPinToggleCell(tag)
    }
    
    @IBAction func onModeChanged(sender: UISegmentedControl) {
        delegate?.onPinModeChanged(modesInSegmentedControl[sender.selectedSegmentIndex], pinIndex: tag)
    }
    
    @IBAction func onDigitalChanged(sender: UISegmentedControl) {
        if let selectedDigital = PinIOModuleViewController.PinData.DigitalValue(rawValue: sender.selectedSegmentIndex) {
            delegate?.onPinDigitalValueChanged(selectedDigital, pinIndex: tag)
        }
        else {
            DLog("Error onDigitalChanged with invalid value")
        }
    }
    
    @IBAction func onValueSliderChanged(sender: UISlider) {
        delegate?.onPinAnalogValueChanged(sender.value, pinIndex: tag)
    }
}
