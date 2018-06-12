//
//  DfuFilesPickerTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 13/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DfuFilesPickerTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var chooseButton: UIButton!
    
    // Params
    var onPickFiles: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
       
        let localizationManager = LocalizationManager.shared
        chooseButton.setTitle(localizationManager.localizedString("dfu_choose_firmware_action"), for: .normal)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onPickFilesButton(_ sender: AnyObject) {
        onPickFiles?()
    }
}
