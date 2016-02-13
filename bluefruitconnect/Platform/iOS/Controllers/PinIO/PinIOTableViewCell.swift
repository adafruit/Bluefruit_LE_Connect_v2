//
//  PinIOTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PinIOTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var modeSegmentedControl: UILabel!
    @IBOutlet weak var digitalSegmentedControl: UISegmentedControl!
    @IBOutlet weak var valueSlider: UISlider!
    
    // Data
    var onToggleCell : (()->())?
    var onModeChanged : ((PinIOModuleViewController.PinData.Mode)->())?
    var onOutputChanged : ((PinIOModuleViewController.PinData.Output)->())?
    var onValueChanged : ((Double)->())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onClickSelectButton(sender: UIButton) {
        onToggleCell?()
    }
    
    @IBAction func onModeChanged(sender: UISegmentedControl) {
        //onModeChanged?(sender.tag == 0 ? )
    }
    
    @IBAction func onDigitalChanged(sender: UISegmentedControl) {
    }
    
    @IBAction func onValueSliderChanged(sender: UISlider) {
    }
}
