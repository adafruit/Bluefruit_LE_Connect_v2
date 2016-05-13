//
//  PinTableCellView.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 18/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

protocol PinTableCellViewDelegate: class {
    func onPinToggleCell(pinIndex: Int)
    func onPinModeChanged(mode: PinIOModuleManager.PinData.Mode, pinIndex: Int)
    func onPinDigitalValueChanged(value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int)
    func onPinAnalogValueChanged(value: Double, pinIndex: Int)
}


class PinTableCellView: NSTableCellView {

    // UI
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var modeLabel: NSTextField!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var modeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var digitalSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var valueSlider: NSSlider!
    
    // Data
    weak var delegate: PinTableCellViewDelegate?
    private var modesInSegmentedControl : [PinIOModuleManager.PinData.Mode] = []
    private var pinIndex: Int = 0
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    // MARK: - Setup
    func setPin(pin : PinIOModuleManager.PinData, pinIndex: Int) {
        self.pinIndex = pinIndex
        setupModeSegmentedControl(pin)
        digitalSegmentedControl.selectedSegment = pin.digitalValue.rawValue
        
        if (pin.digitalPinId == 5) {
            DLog("digital \(pin.digitalPinId) set: \(pin.digitalValue)")
        }
        
        valueSlider.doubleValue = Double(pin.analogValue)
        
        let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
        let fullName = "Pin \(pin.digitalPinId)\(analogName)"
        nameLabel.stringValue = fullName
        modeLabel.stringValue = PinIOModuleManager.stringForPinMode(pin.mode)
        
        var valueText: String!
        switch pin.mode {
        case .Input:
            valueText = PinIOModuleManager.stringForPinDigitalValue(pin.digitalValue)
        case .Output:
            valueText = PinIOModuleManager.stringForPinDigitalValue(pin.digitalValue)
        case .Analog:
            valueText = String(pin.analogValue)
        case .PWM:
            valueText = String(pin.analogValue)
            
        default:
            valueText = ""
        }
        valueLabel.stringValue = valueText
        
        valueSlider.hidden = pin.mode != .PWM
        digitalSegmentedControl.hidden = pin.mode != .Output
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
        
        modeSegmentedControl.segmentCount = modesInSegmentedControl.count
        var i = 0
        for mode in modesInSegmentedControl {
            let modeName = PinIOModuleManager.stringForPinMode(mode)
            modeSegmentedControl.setLabel(modeName, forSegment: i)
            modeSegmentedControl.setWidth(100, forSegment: i)
            if pin.mode == mode {
                modeSegmentedControl.selectedSegment = i    // Select the mode we just added
            }
            
            i += 1
        }
    }

    // MARK: - Actions
    
    @IBAction func onClickToggleCell(sender: AnyObject) {
        delegate?.onPinToggleCell(pinIndex)
    }
    
    @IBAction func onModeChanged(sender: AnyObject) {
        delegate?.onPinModeChanged(modesInSegmentedControl[modeSegmentedControl.selectedSegment], pinIndex: pinIndex)
    }
    
    @IBAction func onDigitalChanged(sender: AnyObject) {
        if let selectedDigital = PinIOModuleManager.PinData.DigitalValue(rawValue: digitalSegmentedControl.selectedSegment) {
            delegate?.onPinDigitalValueChanged(selectedDigital, pinIndex: pinIndex)
        }
        else {
            DLog("Error onDigitalChanged with invalid value")
        }
    }
    
    @IBAction func onValueSliderChanged(sender: AnyObject) {
        delegate?.onPinAnalogValueChanged(valueSlider.doubleValue, pinIndex: pinIndex)
    }

}
