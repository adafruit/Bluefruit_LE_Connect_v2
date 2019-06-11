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
    
    private let pickerController: UIImagePickerController
    private weak var presentationController: UIViewController?
    private var completion : ((_ image: UIImage, _ sourceType: UIImagePickerController.SourceType) -> ())?
    
    public init(presentationController: UIViewController, completion: @escaping ((UIImage, UIImagePickerController.SourceType) -> ())) {
        self.pickerController = UIImagePickerController()
        
        super.init()
        
        self.presentationController = presentationController
        self.completion = completion

        self.pickerController.delegate = self
        self.pickerController.allowsEditing = true
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
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
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
        controller.dismiss(animated: true, completion: nil)
        
        
        if let image = image {
            completion?(image, controller.sourceType)
        }
    }
}

extension ImagePicker: UIImagePickerControllerDelegate {
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.pickerController(picker, didSelect: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.editedImage] as? UIImage else {
            return self.pickerController(picker, didSelect: nil)
        }
        self.pickerController(picker, didSelect: image)
    }
}

extension ImagePicker: UINavigationControllerDelegate {
    
}
