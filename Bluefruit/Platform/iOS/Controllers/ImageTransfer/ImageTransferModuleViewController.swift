//
//  ImageTransferViewController.swift
//  iOS
//
//  Created by Antonio García on 06/06/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit

class ImageTransferModuleViewController: PeripheralModeViewController {
    // Config
    private static let kShowInterleaveControls = true
    // UI
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var cameraImageViewAspectRationConstraint: NSLayoutConstraint!
    @IBOutlet weak var resolutionLabel: UILabel!
    @IBOutlet weak var resolutionButton: UIButton!
    @IBOutlet weak var imageLabel: UILabel!
    @IBOutlet weak var imageOriginButton: UIButton!
    @IBOutlet weak var uartWaitingLabel: UILabel!
    @IBOutlet weak var tranferModeLabel: UILabel!
    @IBOutlet weak var transferModeButton: UIButton!
    @IBOutlet weak var colorSpaceLabel: UILabel!
    @IBOutlet weak var colorSpaceButton: UIButton!

    // Data
    private var imagePicker: ImagePicker!
    private var isEInkModeEnabled = Preferences.imageTransferIsEInkModeEnabled
    private var resolution: CGSize = Preferences.imageTransferResolution ?? CGSize(width:64, height: 64)
    private var image: UIImage?
    private var imageTransferData: ImageTransferModuleManager!
    private var progressViewController: ProgressViewController?
    private var imageRotationDegress: CGFloat = 0
    private var interleavedWithoutResponseCount = Preferences.imageTransferInterleavedWithoutResponseCount
    private var isColorSpace24Bit = Preferences.imageTransferIsColorSpace24Bit
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("imagetransfer_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("imagetransfer_tab_title")
     
        // Style
        cameraImageView.image = nil     // Remove any test image set in Interface Builder
        cameraImageView.layer.borderWidth = 1
        cameraImageView.layer.borderColor = UIColor.lightGray.cgColor

        // UI
        cameraImageView.layer.magnificationFilter = .nearest    // .linear:

        #if targetEnvironment(macCatalyst)
        isEInkModeEnabled = false       // Force eInk to false
        #endif
        
        // Init
        assert(blePeripheral != nil)
        imageTransferData = ImageTransferModuleManager(blePeripheral: blePeripheral!, delegate: self)
 
        updateImage(resolution: resolution, isEInkModeEnabled: isEInkModeEnabled, rotation: imageRotationDegress)    // Setup with the initial value
        updateTransferModeUI()
        
        updateColorSpaceUI()
        
        // Localization
        resolutionLabel.text = localizationManager.localizedString("imagetransfer_resolution_title")
        imageLabel.text = localizationManager.localizedString("imagetransfer_image_title")
        tranferModeLabel.text = localizationManager.localizedString("imagetransfer_transfermode_title")
        uartWaitingLabel.text = localizationManager.localizedString("imagetransfer_waitingforuart")
        imageOriginButton.setTitle(LocalizationManager.shared.localizedString("imagetransfer_imageorigin_choose"), for: .normal)
        
        colorSpaceLabel.text = localizationManager.localizedString("imagetransfer_colorspace_title")
        
        
        imageTransferData.start()
    }
    
    deinit {
        imageTransferData.stop()
        progressViewController?.dismiss(animated: false, completion: nil)       // Force remove the progress
        DLog("ImageTransferModuleViewController deinit")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Add bottom margin for phones without safeinsets
        if self.view.window?.safeAreaInsets.bottom == 0 {
            self.additionalSafeAreaInsets.bottom = 20
        }
    }
    
    // MARK: - UI
    private func updateImageTransferUI(isReady: Bool) {
        uartWaitingLabel.isHidden = isReady
    }
    
    private func updateResolutionUI() {
        let format = isEInkModeEnabled ? "\(LocalizationManager.shared.localizedString("imagetransfer_resolution_einkprefix")) %.0f x %.0f" : "%.0f x %.0f"
        let text = String.init(format: format, resolution.width, resolution.height)
        resolutionButton.setTitle(text, for: .normal)
    }
    
    private func updateTransferModeUI() {
        let localizationManager = LocalizationManager.shared
        
        let text: String
        if interleavedWithoutResponseCount == 0 {
            text = localizationManager.localizedString("imagetransfer_transfermode_value_withresponse")
        }
        else if interleavedWithoutResponseCount == Int.max {
            text = localizationManager.localizedString("imagetransfer_transfermode_value_withoutresponse")
        }
        else {
            text = String(format: localizationManager.localizedString("imagetransfer_transfermode_value_interleaved_format"), interleavedWithoutResponseCount)
        }
        
        transferModeButton.setTitle(text, for: .normal)
    }
    
    private func updateColorSpaceUI() {
        let text = LocalizationManager.shared.localizedString(isColorSpace24Bit ? "imagetransfer_colorspace_24bit":"imagetransfer_colorspace_16bit")
        colorSpaceButton.setTitle(text, for: .normal)
    }
    
    // MARK: - Image
    private func updateImage(resolution: CGSize, isEInkModeEnabled: Bool, rotation: CGFloat) {
        guard let image = self.image else { return }
        
        // Save params
        self.resolution = resolution
        self.isEInkModeEnabled = isEInkModeEnabled
        self.imageRotationDegress = rotation
        
        // Save selected resolution to preferences
        Preferences.imageTransferResolution = resolution
        Preferences.imageTransferIsEInkModeEnabled = isEInkModeEnabled
        
        // Change UI to adjust aspect ration of the displayed image
        NSLayoutConstraint.setMultiplier(multiplier: resolution.width / resolution.height, constraint: &cameraImageViewAspectRationConstraint)
        //DLog("aspectRatio: \(resolution.width)/\(resolution.height)")
        
        // Calculate E-Ink conversion if needed
        #if targetEnvironment(macCatalyst)
        let modeImage = image
        #else
        let modeImage = isEInkModeEnabled ? ImageUtils.applyEInkModeToImage(image) : image
        #endif
        
        // Calculate aspectFit
        let transformedImage = ImageUtils.scaleAndRotateImage(image: modeImage, resolution: resolution, rotationDegrees: imageRotationDegress, backgroundColor: .black)
        
        // Update image
        cameraImageView.image = transformedImage
        updateResolutionUI()
    }
    
    private func setImage(_ image: UIImage?, sourceType: UIImagePickerController.SourceType?) {
        imageRotationDegress = 0        // Reset rotation
        self.image = image
        updateImage(resolution: self.resolution, isEInkModeEnabled: isEInkModeEnabled, rotation: self.imageRotationDegress)
    }
    
  
    // MARK: - Actions
    @IBAction func onClickHelp(_  sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.shared
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("imagetransfer_help_text"), title: localizationManager.localizedString("imagetransfer_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
    
    @IBAction func onClickSelectImage(_ sender: UIButton) {
        
        let croppingAreaViewController = self.storyboard?.instantiateViewController(withIdentifier: ImagePickerCroppingAreaViewController.kStoryboardId) as! ImagePickerCroppingAreaViewController
        
        croppingAreaViewController.setCroppingAreaSize(resolution)
        
        imagePicker = ImagePicker(presentationController: self, croppingAreaViewController: croppingAreaViewController) { [unowned self] (image, sourceType) in
            self.setImage(image, sourceType: sourceType)
        }
        imagePicker.present(from: sender)
    }
    
    @IBAction func onClickChangeResolution(_ sender: UIButton) {
        guard let viewController = self.storyboard?.instantiateViewController(withIdentifier: "ImageTransferFormatSelectorViewController") as? ImageTransferFormatSelectorViewController else { return }
        viewController.isEInkModeEnabled = isEInkModeEnabled
        #if targetEnvironment(macCatalyst)
        viewController.isEInkAvailable = false
        #endif
        viewController.onResolutionSelected = { [unowned self] (resolution, isEInkModeEnabled) in
            self.updateImage(resolution: resolution, isEInkModeEnabled: isEInkModeEnabled, rotation: self.imageRotationDegress)
        }
        self.present(viewController, animated: true, completion: nil)
    }

    @IBAction func onClickChangeTransferMode(_ sender: UIButton) {
        
        if ImageTransferModuleViewController.kShowInterleaveControls {
            let localizationManager = LocalizationManager.shared
            let alertController = UIAlertController(title: localizationManager.localizedString("imagetransfer_transfermode_title"), message: nil, preferredStyle: .actionSheet)
            
            let withoutResponseAction = UIAlertAction(title: localizationManager.localizedString("imagetransfer_transfermode_value_withoutresponse"), style: .default) { [unowned self] _ in
                self.interleavedWithoutResponseCount = Int.max
                Preferences.imageTransferInterleavedWithoutResponseCount = self.interleavedWithoutResponseCount
                self.updateTransferModeUI()
            }
            alertController.addAction(withoutResponseAction)
            
            let withResponseAction = UIAlertAction(title: localizationManager.localizedString("imagetransfer_transfermode_value_withresponse"), style: .default) { [unowned self] _ in
                self.interleavedWithoutResponseCount = 0
                Preferences.imageTransferInterleavedWithoutResponseCount = self.interleavedWithoutResponseCount
                self.updateTransferModeUI()
            }
            alertController.addAction(withResponseAction)
            
            let interleavedResponseAction = UIAlertAction(title: localizationManager.localizedString("imagetransfer_transfermode_value_interleaved"), style: .default) { [unowned self] _ in
                
                let alertController = UIAlertController(title: localizationManager.localizedString("imagetransfer_transfermode_interleavedcount_title"), message: localizationManager.localizedString("imagetransfer_transfermode_interleavedcount_message"), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: nil))
                
                alertController.addTextField(configurationHandler: { textField in
                    textField.placeholder = localizationManager.localizedString("imagetransfer_transfermode_interleavedcount_hint")
                    textField.keyboardType = .numberPad
                })
                
                alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { action in
                   
                    let interleavedTextField = alertController.textFields![0] as UITextField
                    
                    if let text = interleavedTextField.text, let interleaveCount = Int(text) {
                        self.interleavedWithoutResponseCount = interleaveCount
                        Preferences.imageTransferInterleavedWithoutResponseCount = self.interleavedWithoutResponseCount
                        self.updateTransferModeUI()
                    }
                }))
                
                self.present(alertController, animated: true)
            }
            alertController.addAction(interleavedResponseAction)
            
            alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: nil))
                  
        
            alertController.popoverPresentationController?.sourceView = sender
            alertController.popoverPresentationController?.sourceRect = sender.bounds
            self.present(alertController, animated: true, completion: nil)
        }
        else {
            interleavedWithoutResponseCount = interleavedWithoutResponseCount == 0 ? Int.max : 0
            Preferences.imageTransferInterleavedWithoutResponseCount = interleavedWithoutResponseCount
            updateTransferModeUI()
        }
    }
    
    @IBAction func onClickColorSpace(_ sender: Any) {
        isColorSpace24Bit = !isColorSpace24Bit
        Preferences.imageTransferIsColorSpace24Bit = isColorSpace24Bit
        updateColorSpaceUI()
    }
    
    @IBAction func onClickRotateLeft(_ sender: Any) {
        let rotation = (imageRotationDegress - 90).truncatingRemainder(dividingBy: 360)
        updateImage(resolution: self.resolution, isEInkModeEnabled: isEInkModeEnabled, rotation: rotation)
    }
    
    @IBAction func onClickRotateRight(_ sender: Any) {
        let rotation = (imageRotationDegress + 90).truncatingRemainder(dividingBy: 360)
        updateImage(resolution: self.resolution, isEInkModeEnabled: isEInkModeEnabled, rotation: rotation)
    }
    
    @IBAction func onClickSendImage(_ sender: Any) {
        guard let image = cameraImageView.image else { return }
        
        progressViewController = self.storyboard?.instantiateViewController(withIdentifier: "ImageTransferProgressViewController") as? ProgressViewController
        progressViewController!.delegate = self
        progressViewController!.setProgressText(LocalizationManager.shared.localizedString("imagetransfer_transferring"))
        self.present(progressViewController!, animated: true, completion: { [unowned self] in
            // Start image transfer process
            self.imageTransferData.sendImage(image, packetWithResponseEveryPacketCount: self.interleavedWithoutResponseCount, isColorSpace24Bit: self.isColorSpace24Bit)
        })
    }
}

// MARK: - UITextFieldDelegate
extension ImageTransferModuleViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Dont accept user input
        return false
    }
}

// MARK: - ImageTransferModuleManagerDelegate
extension ImageTransferModuleViewController: ImageTransferModuleManagerDelegate {
    func onImageTransferUartIsReady(error: Error?) {
        DispatchQueue.main.async {
            self.updateImageTransferUI(isReady: error == nil)
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
            
            // Set default image
            if self.image == nil {
                self.setImage(UIImage(named: "imagetransfer_default"), sourceType: nil)
            }
        }
    }

    func onImageTransferProgress(progress: Float) {
        //DLog("progress: \(progress*100)")
        progressViewController?.setPercentage(Double(progress*100))
    }
    
    func onImageTransferFinished(error: Error?) {
        DLog("onImageTransferFinished: \(error?.localizedDescription ?? "success")")
        progressViewController?.dismiss(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            if error != nil {
                let localizationManager = LocalizationManager.shared
                showErrorAlert(from: self, title: localizationManager.localizedString("dialog_error"), message: error?.localizedDescription)
            }
        })
    }
}

// MARK: - ProgressViewControllerDelegate
extension ImageTransferModuleViewController: ProgressViewControllerDelegate {
    
    func onUpdateDialogCancel() {
        self.imageTransferData.cancelCurrentSendCommand()
        progressViewController?.dismiss(animated: true, completion: nil)
        progressViewController = nil
    }
}
