//
//  ImagePickerManager.swift
//  iOS
//
//  Created by Antonio García on 06/06/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit

// Based on: https://theswiftdev.com/2019/01/30/picking-images-with-uiimagepickercontroller-in-swift-5/
class ImagePicker: NSObject {
    
    // Data
    private let pickerController: UIImagePickerController
    private weak var presentationController: UIViewController?
    private var completion : ((_ image: UIImage, _ sourceType: UIImagePickerController.SourceType) -> ())?
    private var croppingAreaViewController: ImagePickerCroppingAreaViewController?
    
    // MARK: - Lifecycle
    public init(presentationController: UIViewController, croppingAreaViewController: ImagePickerCroppingAreaViewController?, completion: @escaping ((UIImage, UIImagePickerController.SourceType) -> ())) {
        self.pickerController = UIImagePickerController()
        
        super.init()
        
        self.presentationController = presentationController
        self.completion = completion
        self.croppingAreaViewController = croppingAreaViewController
        
        self.pickerController.delegate = self
        self.pickerController.allowsEditing = false     // handle editing manually
        self.pickerController.mediaTypes = ["public.image"]
    }
    
    private func action(for type: UIImagePickerController.SourceType, title: String) -> UIAlertAction? {
        guard UIImagePickerController.isSourceTypeAvailable(type) else { return nil }
        
        return UIAlertAction(title: title, style: .default) { [unowned self] _ in
            self.pickerController.sourceType = type
            self.presentationController?.present(self.pickerController, animated: true)
        }
    }
    
    public func present(from sourceView: UIView) {
        
        let localizationManager = LocalizationManager.shared
        let alertController = UIAlertController(title: localizationManager.localizedString("imagetransfer_imageorigin_choose"), message: nil, preferredStyle: .actionSheet)
        
        if let action = self.action(for: .camera, title: localizationManager.localizedString("imagetransfer_imagepicker_camera")) {
            alertController.addAction(action)
        }
        if let action = self.action(for: .savedPhotosAlbum, title: localizationManager.localizedString("imagetransfer_imagepicker_cameraroll")) {
            alertController.addAction(action)
        }
        if let action = self.action(for: .photoLibrary, title: localizationManager.localizedString("imagetransfer_imagepicker_photolibrary")) {
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: nil))
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            alertController.popoverPresentationController?.sourceView = sourceView
            alertController.popoverPresentationController?.sourceRect = sourceView.bounds
            alertController.popoverPresentationController?.permittedArrowDirections = [.down, .up]
        }
        
        self.presentationController?.present(alertController, animated: true)
    }
    
    private func pickerController(_ controller: UIImagePickerController, didSelect image: UIImage?) {
        // Custom cropping on camera
        
        if let image = image, let croppingAreaViewController = self.croppingAreaViewController {
            croppingAreaViewController.delegate = self
            croppingAreaViewController.setImage(image)
            controller.present(croppingAreaViewController, animated: false, completion: nil)
        }
        else {
            controller.dismiss(animated: true, completion: nil)
            
            if let image = image {
                completion?(image, controller.sourceType)
            }
        }
    }
    
    func fixOrientation(img: UIImage) -> UIImage {
        // https://stackoverflow.com/questions/5427656/ios-uiimagepickercontroller-result-image-orientation-after-upload
        if (img.imageOrientation == .up) {
            return img
        }
        
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        img.draw(in: rect)
        
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ImagePicker: UIImagePickerControllerDelegate {
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.pickerController(picker, didSelect: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let infoKey: UIImagePickerController.InfoKey = picker.allowsEditing ? .editedImage : .originalImage
        guard let image = info[infoKey] as? UIImage else {
            return self.pickerController(picker, didSelect: nil)
        }
        
        // Fix orientation returned from camera
        let fixedImage = fixOrientation(img: image)
        
        self.pickerController(picker, didSelect: fixedImage)
    }
}

// MARK: - UINavigationControllerDelegate
extension ImagePicker: UINavigationControllerDelegate {
}

// MARK: - ImagePickerCroppingAreaViewControllerDelegate
extension ImagePicker: ImagePickerCroppingAreaViewControllerDelegate {
    func imagePickerCroppingFinished(image: UIImage?) {
        guard let croppingAreaViewController = self.croppingAreaViewController else { return }
        
        
        // Dismiss
        self.presentationController?.dismiss(animated: true, completion: {
            croppingAreaViewController.dismiss(animated: false, completion: nil)
        })
        
        // Call completion
        if let image = image {
            completion?(image, pickerController.sourceType)
        }
    }
}
