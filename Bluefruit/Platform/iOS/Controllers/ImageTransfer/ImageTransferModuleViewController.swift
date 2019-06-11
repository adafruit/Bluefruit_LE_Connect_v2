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
    private static let kAcceptedResolutions = [4, 8, 16, 32, 64, 128, 256, 512, 1024]
    
    // UI
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet var resolutionPickerView: UIPickerView!
    @IBOutlet var resolutionPickerToolbar: UIToolbar!
    @IBOutlet weak var resolutionTextField: UITextField!
    @IBOutlet weak var imageOriginButton: UIButton!
    @IBOutlet weak var uartWaitingLabel: UILabel!
    @IBOutlet weak var resolutionButton: UIButton!
    
    // Data
    private var imagePicker: ImagePicker!
    private var resolution: Int = Preferences.imageTransferResolution ?? 8
    private var image: UIImage?
    fileprivate var imageTransferData: ImageTransferModuleManager!
    fileprivate var progressViewController: ProgressViewController?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("imagetransfer_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("imagetransfer_tab_title")
     
        // Style
        cameraImageView.layer.borderWidth = 1
        cameraImageView.layer.borderColor = UIColor.lightGray.cgColor

        // UI
        resolutionTextField.inputView = resolutionPickerView
        
        if let preselectedResolutionRow = ImageTransferModuleViewController.kAcceptedResolutions.firstIndex(of: resolution) {
            resolutionPickerView.selectRow(preselectedResolutionRow, inComponent: 0, animated: false)
        }
        resolutionTextField.inputAccessoryView = resolutionPickerToolbar
        //resolutionTextField.tintColor = .clear      // don't show cursor
        
        cameraImageView.layer.magnificationFilter = .nearest    // .linear:
        
        // Init
        assert(blePeripheral != nil)
        imageTransferData = ImageTransferModuleManager(blePeripheral: blePeripheral!, delegate: self)
        
        updateImageForResolution(resolution)      // Setup with the initial value
        
        // Localization
        uartWaitingLabel.text = localizationManager.localizedString("thermalcamera_waitingforuart")
        
        imageTransferData.start()
    }

    /*
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }*/
    
    deinit {
        imageTransferData.stop()
        DLog("ImageTransferModuleViewController deinit")
    }
    
    // MARK: - UI
    fileprivate func updateImageTransferUI(isReady: Bool) {
        uartWaitingLabel.isHidden = isReady
    }
    
    private func updateResolutionUI() {
        resolutionButton.setTitle("\(resolution) x \(resolution)", for: .normal)
    }
    
    // MARK: - Image
    fileprivate func updateImageForResolution(_ resolution: Int) {
        self.resolution = resolution
        Preferences.imageTransferResolution = resolution

        let scaledImage = imageWithImage(image: self.image, scaledToSize: CGSize(width: resolution, height: resolution), autoScale: false)
        cameraImageView.image = scaledImage
        updateResolutionUI()
    }
    
    fileprivate func setImage(_ image: UIImage?, sourceType: UIImagePickerController.SourceType?) {
        self.image = image
        updateImageForResolution(self.resolution)
        
        // Origin text
        let imageOriginId: String
        if let sourceType = sourceType {
            switch sourceType {
            case .camera:
                imageOriginId = "imagetransfer_imageorigin_camera"
            case .savedPhotosAlbum:
                imageOriginId = "imagetransfer_imageorigin_cameraroll"
            case .photoLibrary:
                imageOriginId = "imagetransfer_imageorigin_photolibrary"
            @unknown default:
                imageOriginId = "imagetransfer_imageorigin_other"
            }
        }
        else {
            imageOriginId = "imagetransfer_imageorigin_default"
        }
    
        let imageOrigin = LocalizationManager.shared.localizedString(imageOriginId)
        imageOriginButton.setTitle(imageOrigin, for: .normal)
    }

    private func imageWithImage(image: UIImage?, scaledToSize newSize: CGSize, autoScale: Bool) -> UIImage? {
        guard let image = image else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, autoScale ? 0: 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    // MARK: - Actions
    @IBAction func onClickSelectImage(_ sender: UIButton) {
        imagePicker = ImagePicker(presentationController: self) { [unowned self] (image, sourceType) in
            self.setImage(image, sourceType: sourceType)
        }
        imagePicker.present(from: sender)
    }
    
    @IBAction func onClickChangeResolution(_ sender: UIButton) {
        resolutionTextField.becomeFirstResponder()
    }
    
    @IBAction func onClickResolutionDone(_ sender: Any) {
        resolutionTextField.resignFirstResponder()
    }
    
    @IBAction func onClickSendImage(_ sender: Any) {
        guard let image = cameraImageView.image else { return }
        
        progressViewController = self.storyboard?.instantiateViewController(withIdentifier: "ImageTransferProgressViewController") as? ProgressViewController
        progressViewController!.delegate = self
        progressViewController!.setProgressText("Transferring...")
        self.present(progressViewController!, animated: true, completion: { [unowned self] in
            // Start image transfer process
            self.imageTransferData.sendImage(image)
//            self.progressViewController!.setPercentage(50)
        })
    }
}

// MARK: - UIPickerViewDelegate
extension ImageTransferModuleViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ImageTransferModuleViewController.kAcceptedResolutions.count
    }
}

// MARK: - UIPickerViewDelegate
extension ImageTransferModuleViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let resolution = ImageTransferModuleViewController.kAcceptedResolutions[row]
        return "\(resolution) x \(resolution)"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let resolution = ImageTransferModuleViewController.kAcceptedResolutions[row]
        self.updateImageForResolution(resolution)
    }
}

// MARK: - UITextFieldDelegate
extension ImageTransferModuleViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Dont accept user input
        return false
    }
}

// MARK: - ThermalCameraModuleManagerDelegate
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
