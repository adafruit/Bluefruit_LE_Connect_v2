//
//  PeripheralTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

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
    var onConnect: (() -> ())?
    var onDisconnect: (() -> ())?

    // MARK: - View Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        manufacturerValueLabel.text = nil
        txPowerLevelValueLabel.text = nil
        
        let rightMarginInset = contentView.bounds.size.width - baseStackView.frame.maxX     // reposition button because it is outside the hierchy
        //DLog("right margin: \(rightMarginInset)")
        connectButton.titleEdgeInsets.right += rightMarginInset
        disconnectButton.titleEdgeInsets.right += rightMarginInset
    }
    
    @IBAction func onClickDisconnect(_ sender: AnyObject) {
        onDisconnect?()
    }
    
    @IBAction func onClickConnect(_ sender: AnyObject) {
        onConnect?()
    }
    
    func showDisconnectButton(show: Bool) {
        disconnectButtonWidthConstraint.constant = show ? 24: 0
    }
}
