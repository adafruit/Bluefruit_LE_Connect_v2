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
    @IBOutlet weak var temperatureScaleView: UIView!
    @IBOutlet weak var temperatureScaleContainerView: UIView!
    @IBOutlet weak var filterSegmentedControl: UISegmentedControl!
    
    // Data
    fileprivate var thermalCameraData: ThermalCameraModuleManager!


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("thermalcamera_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("thermalcamera_tab_title")
        
        // Style
        cameraImageView.layer.borderWidth = 1
        cameraImageView.layer.borderColor = UIColor.lightGray.cgColor
        
        temperatureScaleView.layer.cornerRadius = 4
        temperatureScaleView.layer.masksToBounds = true
        
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        DLog("ThermalCameraModuleViewController deinit")
    }

    // MARK: - UI
    fileprivate func updateThermalUI(isReady: Bool) {
        // Setup UI
        uartWaitingLabel.isHidden = isReady
    }
    
    // MARK: - Actions
    @IBAction func onFilterModeChanged(_ sender: UISegmentedControl) {
        let isFilterEnabled = sender.selectedSegmentIndex == 1
        cameraImageView.layer.magnificationFilter = isFilterEnabled ? kCAFilterLinear:kCAFilterNearest
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
        DispatchQueue.main.async { [weak self] in
            guard let context = self else { return }
            
            context.updateThermalUI(isReady: error == nil)
            guard error == nil else {
                DLog("Error initializing uart")
                context.dismiss(animated: true, completion: { [weak self] in
                    if let context = self {
                        showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")
                        
                        if let blePeripheral = context.blePeripheral {
                            BleManager.sharedInstance.disconnect(from: blePeripheral)
                        }
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
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                self?.temperatureScaleContainerView.alpha = 1
            })
        }
        
        lowerTempLabel.text = String(format: "%.2f", thermalCameraData.lowerTemperature)
        upperTempLabel.text = String(format: "%.2f", thermalCameraData.upperTemperature)
    }
}
