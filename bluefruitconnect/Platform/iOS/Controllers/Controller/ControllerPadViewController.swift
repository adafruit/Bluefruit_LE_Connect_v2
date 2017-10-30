//
//  ControllerPadViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol ControllerPadViewControllerDelegate: class {
    func onSendControllerPadButtonStatus(tag: Int, isPressed: Bool)
}

class ControllerPadViewController: UIViewController {

    //  Constants
    static let prefix = "!B"

    // UI
    @IBOutlet weak var directionsView: UIView!
    @IBOutlet weak var numbersView: UIView!
    
    // Data
    weak var delegate: ControllerPadViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup buttons targets
        for subview in directionsView.subviews {
            if let button = subview as? UIButton {
              setupButton(button: button)
            }
        }
        
        for subview in numbersView.subviews {
            if let button = subview as? UIButton {
              setupButton(button: button)
            }
        }
    }
    
    func setupButton(button: UIButton) {
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.layer.borderWidth = 1
      button.layer.borderColor = UIColor.white.cgColor
        button.layer.masksToBounds = true
        
      button.setTitleColor(UIColor.lightGray, for: .highlighted)
        
      let hightlightedImage = UIImage(color: UIColor.darkGray)
      button.setBackgroundImage(hightlightedImage, for: .highlighted)
        
      button.addTarget(self, action: #selector(onTouchDown), for: .touchDown)
      button.addTarget(self, action: #selector(onTouchUp), for: .touchUpInside)
      button.addTarget(self, action: #selector(onTouchUp), for: .touchDragExit)
      button.addTarget(self, action: #selector(onTouchUp), for: .touchCancel)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
  override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Fix: remove the UINavigationController pop gesture to avoid problems with the arrows left button
        let delayTime = DispatchTime.now() + (0.1 * Double(NSEC_PER_SEC))
        DispatchQueue.main.asyncAfter(deadline: delayTime) { [unowned self] in
            
            self.navigationController?.interactivePopGestureRecognizer?.delaysTouchesBegan = false
            self.navigationController?.interactivePopGestureRecognizer?.delaysTouchesEnded = false
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
 

  override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        
    }
    
    private func sendTouchEvent(tag: Int, isPressed: Bool) {
        if let delegate = delegate {
          delegate.onSendControllerPadButtonStatus(tag: tag, isPressed: isPressed)
        }
    }
    
    // MARK: - Actions
  @objc func onTouchDown(sender: UIButton) {
      sendTouchEvent(tag: sender.tag, isPressed: true)
    }
    
  @objc func onTouchUp(sender: UIButton) {
      sendTouchEvent(tag: sender.tag, isPressed: false)
    }
    
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
      let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
      helpViewController.setHelp(message: localizationManager.localizedString(key: "controlpad_help_text"), title: localizationManager.localizedString(key: "controlpad_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
      helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
      present(helpNavigationController, animated: true, completion: nil)
    }
}
