//
//  ImagePickerCroppingAreaViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 18/07/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit

protocol ImagePickerCroppingAreaViewControllerDelegate: class {
    func imagePickerCroppingFinished(image: UIImage?)
}

class ImagePickerCroppingAreaViewController: UIViewController {
    // Contants
    public static let kStoryboardId = "ImagePickerCroppingAreaViewController"
    
    // UI
    @IBOutlet weak var croppingAreaView: UIView!
    @IBOutlet weak var croppingAreaViewAspectRatioConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageScrollView: UIScrollView! {
        didSet{
            imageScrollView.delegate = self
        }
    }
    
    // Params
    weak var delegate: ImagePickerCroppingAreaViewControllerDelegate?
    
    // MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        
        croppingAreaView.layer.borderColor = UIColor.white.cgColor
        croppingAreaView.layer.borderWidth = 2
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        imageScrollView.contentInset = UIEdgeInsets(top: imageScrollView.bounds.height/2, left: 0, bottom: imageScrollView.bounds.height/2, right: 0)

    }
    
    // MARK: - UI
    public func setCroppingAreaSize(_ size: CGSize) {
        self.loadViewIfNeeded()
        
        NSLayoutConstraint.setMultiplier(multiplier: size.width / size.height, constraint: &croppingAreaViewAspectRatioConstraint)
    }
    
    public func setImage(_ image: UIImage) {
        imageView.image = image
        
        let defaultScale =  self.view.bounds.width / image.size.width
        imageScrollView.minimumZoomScale = min(1, defaultScale)
        imageScrollView.maximumZoomScale = 10.0

        imageScrollView.zoomScale = defaultScale
    }
    
    @IBAction func croppingDone(_ sender: Any) {
        // Crop image to the croppingAreaView
        var result: UIImage?
        
        if let cameraCGImage = imageView.image?.cgImage {
            let croppingRect = croppingAreaView.convert(croppingAreaView.bounds, to: imageView)
            if let imageRef = cameraCGImage.cropping(to: croppingRect) {
                result = UIImage.init(cgImage: imageRef)
            }
        }
        
        delegate?.imagePickerCroppingFinished(image: result)
    }
    
    @IBAction func croppingCancelled(_ sender: Any) {
        delegate?.imagePickerCroppingFinished(image: nil)
    }
}

// MARK: - UIScrollViewDelegate
extension ImagePickerCroppingAreaViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: - Calculate Image Frame
extension UIImageView{
    // from: https://medium.com/modernnerd-code/how-to-make-a-custom-image-cropper-with-swift-3-c0ec8c9c7884
    func imageFrame() -> CGRect {
        let imageViewSize = self.frame.size
        guard let imageSize = self.image?.size else { return CGRect.zero }

        let imageRatio = imageSize.width / imageSize.height
        let imageViewRatio = imageViewSize.width / imageViewSize.height
        if imageRatio < imageViewRatio {
            let scaleFactor = imageViewSize.height / imageSize.height
            let width = imageSize.width * scaleFactor
            let topLeftX = (imageViewSize.width - width) * 0.5
            return CGRect(x: topLeftX, y: 0, width: width, height: imageViewSize.height)
        }
        else{
            let scalFactor = imageViewSize.width / imageSize.width
            let height = imageSize.height * scalFactor
            let topLeftY = (imageViewSize.height - height) * 0.5
            return CGRect(x: 0, y: topLeftY, width: imageViewSize.width, height: height)
        }
    }
}
