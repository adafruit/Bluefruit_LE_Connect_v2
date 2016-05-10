//
//  PeripheralTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralTableViewCell: UITableViewCell {

    @IBOutlet weak var baseStackView: UIStackView!
    @IBOutlet weak var rssiImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var disconnectButtonWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var detailBaseStackView: UIStackView!
    @IBOutlet weak var servicesStackView: UIStackView!
    @IBOutlet weak var txPowerLevelValueLabel: UILabel!
    @IBOutlet weak var manufacturerValueLabel: UILabel!
    
    var onConnect : (() -> ())?
    var onDisconnect : (() -> ())?

    override func awakeFromNib() {
        super.awakeFromNib()
        manufacturerValueLabel.text = nil
        txPowerLevelValueLabel.text = nil
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func onClickDisconnect(sender: AnyObject) {
        onDisconnect?()
    }
    
    @IBAction func onClickConnect(sender: AnyObject) {
        onConnect?()
    }
    
    func showDisconnectButton(show: Bool) {
        disconnectButtonWidthConstraint.constant = show ? 24: 0
    }
}
