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
    func onPinModeChanged(mode: PinIOModuleManager.PinData.Mode, pinIndex: Int)
    func onPinDigitalValueChanged(value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int)
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
    weak var delegate: PinIoTableViewCellDelegate?
    private var modesInSegmentedControl : [PinIOModuleManager.PinData.Mode] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

  override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    // MARK: - Setup
    func setPin(pin : PinIOModuleManager.PinData) {
      setupModeSegmentedControl(pin: pin)
        digitalSegmentedControl.selectedSegmentIndex = pin.digitalValue.rawValue
        valueSlider.value = Float(pin.analogValue)
        
        let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
        let fullName = "Pin \(pin.digitalPinId)\(analogName)"
        nameLabel.text = fullName
      modeLabel.text = PinIOModuleManager.stringForPinMode(mode: pin.mode)
        
        var valueText: String?
        switch pin.mode {
        case .Input:
          valueText = PinIOModuleManager.stringForPinDigitalValue(digitalValue: pin.digitalValue)
        case .Output:
          valueText = PinIOModuleManager.stringForPinDigitalValue(digitalValue: pin.digitalValue)
        case .Analog:
            valueText = String(pin.analogValue)
        case .PWM:
            valueText = String(pin.analogValue)
            
        default:
            valueText = ""
        }
        valueLabel.text = valueText
        
      valueSlider.isHidden = pin.mode != .PWM
      digitalSegmentedControl.isHidden = pin.mode != .Output
    }
    
    private func setupModeSegmentedControl(pin : PinIOModuleManager.PinData) {
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
          let modeName = PinIOModuleManager.stringForPinMode(mode: mode)
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
      delegate?.onPinModeChanged(mode: modesInSegmentedControl[sender.selectedSegmentIndex], pinIndex: tag)
    }
    
    @IBAction func onDigitalChanged(_ sender: UISegmentedControl) {
        if let selectedDigital = PinIOModuleManager.PinData.DigitalValue(rawValue: sender.selectedSegmentIndex) {
          delegate?.onPinDigitalValueChanged(value: selectedDigital, pinIndex: tag)
        }
        else {
          DLog(message: "Error onDigitalChanged with invalid value")
        }
    }
    
    @IBAction func onValueSliderChanged(_ sender: UISlider) {
      delegate?.onPinAnalogValueChanged(value: sender.value, pinIndex: tag)
    }
}
