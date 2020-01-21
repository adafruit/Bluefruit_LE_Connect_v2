//
//  ImageTransferFormatSelectorViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 10/01/2020.
//  Copyright © 2020 Adafruit. All rights reserved.
//

import UIKit

class ImageTransferFormatSelectorViewController: UIViewController {
    // Config
    private static let kStandardResolutions: [CGSize] = [
        CGSize(width: 4, height: 4),
        CGSize(width: 8, height: 8),
        CGSize(width: 16, height: 16),
        CGSize(width: 32, height: 32),
        CGSize(width: 64, height: 64),
        CGSize(width: 128, height: 128),
        CGSize(width: 128, height: 160),
        CGSize(width: 160, height: 80),
        CGSize(width: 168, height: 144),
        CGSize(width: 212, height: 104),
        CGSize(width: 240, height: 240),
        CGSize(width: 250, height: 122),
        CGSize(width: 256, height: 256),
        CGSize(width: 296, height: 128),
        CGSize(width: 300, height: 400),
        CGSize(width: 320, height: 240),
        CGSize(width: 480, height: 320),
        CGSize(width: 512, height: 512),
        ]
    
    private static let kEInkResolutions: [CGSize] = [
        CGSize(width: 152, height: 152),
        CGSize(width: 168, height: 44),
        CGSize(width: 212, height: 104),
        CGSize(width: 250, height: 122),
        CGSize(width: 296, height: 128),
        CGSize(width: 300, height: 400),
        ]
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var modeContainerView: UIView!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var toolbarTitleLabel: UILabel!
    
    // Params
    var onResolutionSelected: ((CGSize, Bool) -> Void)?
    var isEInkModeEnabled = false
    var isEInkAvailable = true {
        didSet {
            isEInkModeEnabled = false
            if isViewLoaded {
                modeSegmentedControl.selectedSegmentIndex = 0
                modeContainerView.isHidden = !isEInkAvailable
            }
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI
        modeSegmentedControl.selectedSegmentIndex = isEInkModeEnabled ? 1:0
        modeContainerView.isHidden = !isEInkAvailable
        
        // Localization
        let localizationManager = LocalizationManager.shared
        toolbarTitleLabel.text = localizationManager.localizedString("imagetransfer_resolution_choose")
        
        modeSegmentedControl.setTitle(localizationManager.localizedString("imagetransfer_resolution_mode_standard"), forSegmentAt: 0)
        modeSegmentedControl.setTitle(localizationManager.localizedString("imagetransfer_resolution_mode_eink"), forSegmentAt: 1)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = .clear
        }

    }
    
    // MARK: - Actions
    @IBAction func onModeSelected(_ sender: Any) {
        isEInkModeEnabled = modeSegmentedControl.selectedSegmentIndex == 1
        baseTableView.reloadData()
    }
    
    @IBAction func onClickDone(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension ImageTransferFormatSelectorViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let resolutions = isEInkModeEnabled ? ImageTransferFormatSelectorViewController.kEInkResolutions : ImageTransferFormatSelectorViewController.kStandardResolutions
        return resolutions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "ResolutionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ImageTransferFormatSelectorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
       
        guard let cell = cell as? ImageTransferFormatSelectorResolutionCell else { return }
        
        let resolutions = isEInkModeEnabled ? ImageTransferFormatSelectorViewController.kEInkResolutions : ImageTransferFormatSelectorViewController.kStandardResolutions
        let resolution = resolutions[indexPath.row]
        let text = String.init(format: "%.0f x %.0f", resolution.width, resolution.height)
           
        cell.titleLabel.text = text
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.section == 0)

        let resolutions = isEInkModeEnabled ? ImageTransferFormatSelectorViewController.kEInkResolutions : ImageTransferFormatSelectorViewController.kStandardResolutions
        let resolution = resolutions[indexPath.row]
        
        self.onResolutionSelected?(resolution, isEInkModeEnabled)
        dismiss(animated: true, completion: nil)

    }
}
