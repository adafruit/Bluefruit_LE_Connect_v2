//
//  DfuFilesPickerTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 13/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DfuFilesPickerTableViewCell: UITableViewCell {

    var onPickFiles: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onPickFilesButton(_ sender: AnyObject) {
        onPickFiles?()
    }
}
