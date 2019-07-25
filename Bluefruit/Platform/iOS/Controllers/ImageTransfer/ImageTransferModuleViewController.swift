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
    private static let kAcceptedResolutions: [CGSize] = [
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
        //CGSize(width: 1024, height: 1024),
        ]
    
    // UI
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var cameraImageViewAspectRationConstraint: NSLayoutConstraint!
    @IBOutlet var resolutionPickerView: UIPickerView!
    @IBOutlet var resolutionPickerToolbar: UIToolbar!
    @IBOutlet weak var resolutionTextField: UITextField!
    @IBOutlet weak var imageOriginButton: UIButton!
    @IBOutlet weak var uartWaitingLabel: UILabel!
    @IBOutlet weak var resolutionButton: UIButton!
    
    // Data
    private var imagePicker: ImagePicker!
    private var resolution: CGSize = Preferences.imageTransferResolution ?? CGSize(width:64, height: 64)
    private var image: UIImage?
    fileprivate var imageTransferData: ImageTransferModuleManager!
    fileprivate var progressViewController: ProgressViewController?
    private var imageRotationDegress: CGFloat = 0

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
        
        updateImage(resolution: resolution, rotation: imageRotationDegress)    // Setup with the initial value

        // Localization
        uartWaitingLabel.text = localizationManager.localizedString("thermalcamera_waitingforuart")
        imageOriginButton.setTitle(LocalizationManager.shared.localizedString("imagetransfer_imageorigin_choose"), for: .normal)

        imageTransferData.start()
    }
    
    deinit {
        imageTransferData.stop()
        progressViewController?.dismiss(animated: false, completion: nil)       // Force remove the progress
        DLog("ImageTransferModuleViewController deinit")
    }
    
    // MARK: - UI
    fileprivate func updateImageTransferUI(isReady: Bool) {
        uartWaitingLabel.isHidden = isReady
    }
    
    private func updateResolutionUI() {
        let text = String.init(format: "%.0f x %.0f", resolution.width, resolution.height)
        resolutionButton.setTitle(text, for: .normal)
    }
    
    // MARK: - Image
    fileprivate func updateImage(resolution: CGSize, rotation: CGFloat) {
        guard let image = self.image else { return }
        
        self.resolution = resolution
        self.imageRotationDegress = rotation
        
        // Save selected resolution
        Preferences.imageTransferResolution = resolution

        // Change UI to adjust aspect ration of the displayed image
        NSLayoutConstraint.setMultiplier(multiplier: resolution.width / resolution.height, constraint: &cameraImageViewAspectRationConstraint)
        //DLog("aspectRatio: \(resolution.width)/\(resolution.height)")
        
        // Calculate aspectFit
        let transformedImage = scaleAndRotateImage(image: image, resolution: resolution, rotationDegrees: imageRotationDegress, backgroundColor: .black)
        
        cameraImageView.image = transformedImage
        updateResolutionUI()
    }
    
    fileprivate func setImage(_ image: UIImage?, sourceType: UIImagePickerController.SourceType?) {
        imageRotationDegress = 0        // Reset rotation
        self.image = image
        updateImage(resolution: self.resolution, rotation: self.imageRotationDegress)
    }
    
    private func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
        return degrees * .pi / 180
    }
    
    private func scaleAndRotateImage(image: UIImage, resolution: CGSize, rotationDegrees: CGFloat, backgroundColor: UIColor) -> UIImage? {
        
        // Calculate resolution for fitted image
        let widthRatio = resolution.width / image.size.width
        let heightRatio = resolution.height / image.size.height
        
        var fitResolution = resolution
        if heightRatio < widthRatio  {
            fitResolution.width = resolution.height / image.size.height * image.size.width
        }
        else if widthRatio < heightRatio  {
            fitResolution.height = resolution.width / image.size.width * image.size.height
        }
        
        guard let fitImage = imageRotatedByDegrees(image: image, scaledToSize: fitResolution, rotationDegrees: rotationDegrees) else { return nil }
        
        // Draw fitImage centered in canvas
        let x = floor((resolution.width - fitImage.size.width) / 2)
        let y = floor((resolution.height - fitImage.size.height) / 2)
        let fitDrawRect = CGRect(x: x, y: y, width: fitImage.size.width, height: fitImage.size.height)
        
        UIGraphicsBeginImageContext(resolution)
        if let context = UIGraphicsGetCurrentContext() {
            backgroundColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height))
            
            // Draw fit image at center
            fitImage.draw(in: fitDrawRect)
        }
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func imageRotatedByDegrees(image: UIImage, scaledToSize newSize: CGSize, rotationDegrees: CGFloat) -> UIImage? {
        // based on: https://stackoverflow.com/questions/40882487/how-to-rotate-image-in-swift
        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView(frame: CGRect(x:0, y:0, width: newSize.width, height: newSize.height))
        let t = CGAffineTransform(rotationAngle: self.degreesToRadians(rotationDegrees))
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext(), let cgImage = image.cgImage {
            // Move the origin to the middle of the image so we will rotate and scale around the center.
            context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)

            // Rotate the image context
            context.rotate(by:degreesToRadians(rotationDegrees))
            
            // Now, draw the rotated/scaled image into the context
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: -newSize.width / 2, y: -newSize.height / 2, width: newSize.width, height: newSize.height), byTiling: false)
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    // MARK: - Actions
    @IBAction func onClickSelectImage(_ sender: UIButton) {
        
        let croppingAreaViewController = self.storyboard?.instantiateViewController(withIdentifier: ImagePickerCroppingAreaViewController.kStoryboardId) as! ImagePickerCroppingAreaViewController
        
        croppingAreaViewController.setCroppingAreaSize(resolution)
        
        imagePicker = ImagePicker(presentationController: self, croppingAreaViewController: croppingAreaViewController) { [unowned self] (image, sourceType) in
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
    
    @IBAction func onClickRotateLeft(_ sender: Any) {
        let rotation = (imageRotationDegress - 90).truncatingRemainder(dividingBy: 360)
        updateImage(resolution: self.resolution, rotation: rotation)
    }
    
    @IBAction func onClickRotateRight(_ sender: Any) {
        let rotation = (imageRotationDegress + 90).truncatingRemainder(dividingBy: 360)
        updateImage(resolution: self.resolution, rotation: rotation)
    }
    
    @IBAction func onClickSendImage(_ sender: Any) {
        guard let image = cameraImageView.image else { return }
        
        progressViewController = self.storyboard?.instantiateViewController(withIdentifier: "ImageTransferProgressViewController") as? ProgressViewController
        progressViewController!.delegate = self
        progressViewController!.setProgressText(LocalizationManager.shared.localizedString("imagetransfer_transferring"))
        self.present(progressViewController!, animated: true, completion: { [unowned self] in
            // Start image transfer process
            self.imageTransferData.sendImage(image)
        })
    }
}

// MARK: - UIPickerViewDataSource
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
        let text = String.init(format: "%.0f x %.0f", resolution.width, resolution.height)
        return text
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let resolution = ImageTransferModuleViewController.kAcceptedResolutions[row]
        updateImage(resolution: resolution, rotation: self.imageRotationDegress)
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
