//
//  DfuFilesPickerDialogViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 11/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol DfuFilesPickerDialogViewControllerDelegate: class {
    func onFilesPickerCancel()
    func onFilesPickerStartUpdate(hexUrl: URL?, iniUrl: URL?)
}

class DfuFilesPickerDialogViewController: UIViewController {

    // UI
    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var hexFileUrlLabel: UILabel!
    @IBOutlet weak var iniFileUrlLabel: UILabel!
    @IBOutlet weak var backgroundView: UIView!

    @IBOutlet weak var hexPickerView: UIView!
    @IBOutlet weak var iniPickerView: UIView!

    // Data
    weak var delegate: DfuFilesPickerDialogViewControllerDelegate?

    fileprivate var isPickingHexFile = false
    fileprivate var hexFileUrl: URL?
    fileprivate var iniFileUrl: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        dialogView.layer.cornerRadius = 4
        dialogView.layer.masksToBounds = true

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fade-in background
        backgroundView.alpha = 0
        UIView.animate(withDuration: 0.5, animations: { [unowned self] () -> Void in
            self.backgroundView.alpha = 1
            })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func updateFileNames() {
        hexFileUrlLabel.text = hexFileUrl != nil ? hexFileUrl!.lastPathComponent: "<No file selected>"
        iniFileUrlLabel.text = iniFileUrl != nil ? iniFileUrl!.lastPathComponent: "<No file selected>"
    }

    // MARK: - Actions
    @IBAction func onClickPickFile(_ sender: UIButton) {
        isPickingHexFile = sender.tag == 0

        let importMenu = UIDocumentMenuViewController(documentTypes: ["public.data", "public.content"], in: .import)
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

// MARK: - UIDocumentMenuDelegate
extension DfuFilesPickerDialogViewController: UIDocumentMenuDelegate {

    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate
extension DfuFilesPickerDialogViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        DLog("picked: \(url.absoluteString)")

        if isPickingHexFile {
            hexFileUrl = url
        } else {
            iniFileUrl = url
        }

        updateFileNames()
    }
}
