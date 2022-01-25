//
//  DfuFilesPickerDialogViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 11/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol DfuFilesPickerDialogViewControllerDelegate: AnyObject {
    func onFilesPickerCancel()
    func onFilesPickerStartUpdate(hexUrl: URL?, iniUrl: URL?)
}

class DfuFilesPickerDialogViewController: UIViewController {

    // UI
    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var hexFileTitleLabel: UILabel!
    @IBOutlet weak var hexFileUrlLabel: UILabel!
    @IBOutlet weak var hexChooseButton: StyledButton!
    @IBOutlet weak var iniFileTitleLabel: UILabel!
    @IBOutlet weak var iniFileUrlLabel: UILabel!
    @IBOutlet weak var initChooseButton: StyledButton!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var updateButton: StyledButton!
    
    @IBOutlet weak var hexPickerView: UIView!
    @IBOutlet weak var iniPickerView: UIView!

    // Data
    weak var delegate: DfuFilesPickerDialogViewControllerDelegate?

    private var isPickingHexFile = false
    private var hexFileUrl: URL?
    private var iniFileUrl: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        dialogView.layer.cornerRadius = 4
        dialogView.layer.masksToBounds = true
        
        // Localization
        let localizationManager = LocalizationManager.shared
        titleLabel.text = localizationManager.localizedString("dfu_pickfiles_customfirmware_title")
        hexFileTitleLabel.text = localizationManager.localizedString("dfu_pickfiles_hex_title")
        iniFileTitleLabel.text = localizationManager.localizedString("dfu_pickfiles_init_title")
        hexChooseButton.setTitle(localizationManager.localizedString("dfu_pickfiles_hex_action"), for: .normal)
        initChooseButton.setTitle(localizationManager.localizedString("dfu_pickfiles_init_action"), for: .normal)
        updateButton.setTitle(localizationManager.localizedString("dfu_pickfiles_update_action"), for: .normal)
        cancelButton.setTitle(localizationManager.localizedString("dialog_cancel"), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fade-in background
        backgroundView.alpha = 0
        UIView.animate(withDuration: 0.5, animations: {
            self.backgroundView.alpha = 1
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func updateFileNames() {
        let nofileString = LocalizationManager.shared.localizedString("dfu_pickfiles_file_empty")
        hexFileUrlLabel.text = hexFileUrl != nil ? hexFileUrl!.lastPathComponent: nofileString
        iniFileUrlLabel.text = iniFileUrl != nil ? iniFileUrl!.lastPathComponent: nofileString
    }

    // MARK: - Actions
    @IBAction func onClickPickFile(_ sender: UIButton) {
        isPickingHexFile = sender.tag == 0

        let importMenu = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        importMenu.delegate = self
        importMenu.popoverPresentationController?.sourceView = sender
        present(importMenu, animated: true, completion: nil)
    }

    @IBAction func onClickStartUpdate(_ sender: AnyObject) {
        dismiss(animated: true) { [unowned self] () -> Void in
            self.delegate?.onFilesPickerStartUpdate(hexUrl: self.hexFileUrl, iniUrl: self.iniFileUrl)
        }
    }

    @IBAction func onClickCancel(_ sender: AnyObject) {
        dismiss(animated: true) { [unowned self] () -> Void in
            self.delegate?.onFilesPickerCancel()
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension DfuFilesPickerDialogViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        DLog("picked: \(url.absoluteString)")

        if isPickingHexFile {
            hexFileUrl = url
        } else {
            iniFileUrl = url
        }

        updateFileNames()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        DLog("documentPickerWasCancelled")
    }
}
