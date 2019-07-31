//
//  ThermalCameraModuleViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 27/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ThermalCameraModuleViewController: PeripheralModeViewController {

    // UI
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var uartWaitingLabel: UILabel!
    @IBOutlet weak var thermalScaleView: ThermalGradientView!
    @IBOutlet weak var lowerTempLabel: UILabel!
    @IBOutlet weak var upperTempLabel: UILabel!
    @IBOutlet weak var temperatureScaleContainerView: UIView!
    @IBOutlet weak var filterSegmentedControl: UISegmentedControl!
    @IBOutlet weak var colorModeLabel: UILabel!
    @IBOutlet weak var magnificationLabel: UILabel!
    @IBOutlet weak var temperatureRangeLabel: UILabel!
    @IBOutlet weak var colorModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var magnificationSegmentedControl: UISegmentedControl!
    
    // Data
    fileprivate var thermalCameraData: ThermalCameraModuleManager!

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? LocalizationManager.shared.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("thermalcamera_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("thermalcamera_tab_title")
        
        // Style
        cameraImageView.layer.borderWidth = 1
        cameraImageView.layer.borderColor = UIColor.lightGray.cgColor

        thermalScaleView.layer.cornerRadius = 4
        thermalScaleView.layer.masksToBounds = true

        // Localization
        uartWaitingLabel.text = localizationManager.localizedString("thermalcamera_waitingforuart")
        colorModeLabel.text = localizationManager.localizedString("thermalcamera_colormode_title")
        magnificationLabel.text = localizationManager.localizedString("thermalcamera_magnification_title")
        temperatureRangeLabel.text = localizationManager.localizedString("thermalcamera_temprange_title")
        colorModeSegmentedControl.setTitle(localizationManager.localizedString("thermalcamera_colormode_color"), forSegmentAt: 0)
        colorModeSegmentedControl.setTitle(localizationManager.localizedString("thermalcamera_colormode_monochrome"), forSegmentAt: 1)
        magnificationSegmentedControl.setTitle(localizationManager.localizedString("thermalcamera_magnification_pixelated"), forSegmentAt: 0)
        magnificationSegmentedControl.setTitle(localizationManager.localizedString("thermalcamera_magnification_filtered"), forSegmentAt: 1)
        
        // Init
        assert(blePeripheral != nil)
        thermalCameraData = ThermalCameraModuleManager(blePeripheral: blePeripheral!, delegate: self)
        thermalScaleView.thermalCameraData = thermalCameraData

        temperatureScaleContainerView.alpha = 0
        onFilterModeChanged(filterSegmentedControl)
        updateThermalUI(isReady: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        thermalCameraData.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        thermalCameraData.stop()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Add bottom margin for phones without safeinsets
        if self.view.window?.safeAreaInsets.bottom == 0 {
            self.additionalSafeAreaInsets.bottom = 20
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        DLog("ThermalCameraModuleViewController deinit")
    }

    // MARK: - UI
    fileprivate func updateThermalUI(isReady: Bool) {
        uartWaitingLabel.isHidden = isReady
    }
    
    // MARK: - Actions
    @IBAction func onFilterModeChanged(_ sender: UISegmentedControl) {
        let isFilterEnabled = sender.selectedSegmentIndex == 1
        cameraImageView.layer.magnificationFilter = isFilterEnabled ? .linear:.nearest
    }
    
    @IBAction func onColorModeChanged(_ sender: UISegmentedControl) {
        let isColorEnabled = sender.selectedSegmentIndex == 0
        thermalCameraData.isColorEnabled = isColorEnabled
        thermalScaleView.setNeedsDisplay()
    }
}

// MARK: - ThermalCameraModuleManagerDelegate
extension ThermalCameraModuleViewController: ThermalCameraModuleManagerDelegate {
    func onThermalUartIsReady(error: Error?) {
        DispatchQueue.main.async {
            self.updateThermalUI(isReady: error == nil)
            guard error == nil else {
                DLog("Error initializing uart")
                self.dismiss(animated: true, completion: { [weak self] in
                    guard let context = self else { return }
                    let localizationManager = LocalizationManager.shared
                    showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: localizationManager.localizedString("uart_error_peripheralinit"))
                    
                    if let blePeripheral = context.blePeripheral {
                        BleManager.shared.disconnect(from: blePeripheral)
                    }
                })
                return
            }
            
            // Uart Ready
        }
    }
    
    func onImageUpdated(_ image: UIImage) {
        cameraImageView.image = image
        
        if temperatureScaleContainerView.alpha == 0 && thermalCameraData.isTemperatureReadReceived {
            thermalScaleView.setNeedsDisplay()
            UIView.animate(withDuration: 0.3, animations: {
                self.temperatureScaleContainerView.alpha = 1
            })
        }
        
        lowerTempLabel.text = String(format: "%.2f", thermalCameraData.lowerTemperature)
        upperTempLabel.text = String(format: "%.2f", thermalCameraData.upperTemperature)
    }
}
