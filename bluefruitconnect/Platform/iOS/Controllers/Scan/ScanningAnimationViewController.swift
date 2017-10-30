//
//  ScanningAnimationViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ScanningAnimationViewController: ModuleViewController {

    @IBOutlet weak var scanningWave0ImageView: UIImageView!
    @IBOutlet weak var scanningWave1ImageView: UIImageView!
    
    private var isAnimating = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
  override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isAnimating {
            startAnimating()
        }
        
        // Observe notifications for coming back from background
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(applicationWillEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
  override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    @objc func applicationWillEnterForeground(notification: NSNotification) {
        // Restarts animation when coming back from background
        
        if isAnimating {
            startAnimating()
        }
    }
    
    func startAnimating() {
        isAnimating = true
        
        guard isViewLoaded else {
            return
        }
        
        // Scanning animation
        let duration: Double = 15
        let initialScaleFactor: CGFloat = 0.17
        let finalScaleFactor: CGFloat = 2.0

        // First wave
        self.scanningWave0ImageView.transform = CGAffineTransform(scaleX: initialScaleFactor, y: initialScaleFactor) //CGAffineTransformMakeScale(initialScaleFactor, initialScaleFactor);
        self.scanningWave0ImageView.alpha = 1
        
        let animationOptions: UIViewAnimationOptions = [.repeat, .curveEaseInOut]
        
        UIView.animate(withDuration: duration, delay: 0, options: animationOptions, animations: { [unowned self] in
            self.scanningWave0ImageView.transform = CGAffineTransform(scaleX: finalScaleFactor, y: finalScaleFactor)
            self.scanningWave0ImageView.alpha = 0
        }, completion: nil)
        
        // Second wave
        self.scanningWave1ImageView.transform = CGAffineTransform(scaleX: initialScaleFactor, y: initialScaleFactor)
        self.scanningWave1ImageView.alpha = 1
        UIView.animate(withDuration: duration, delay: 0, options: animationOptions, animations: { [unowned self] in
            self.scanningWave1ImageView.transform = CGAffineTransform(scaleX: finalScaleFactor, y: finalScaleFactor)
            self.scanningWave1ImageView.alpha = 0
            }, completion: nil)
    }
    
    func stopAnimating() {
        isAnimating = false
        
        if isViewLoaded {
            scanningWave0ImageView.layer.removeAllAnimations()
            scanningWave1ImageView.layer.removeAllAnimations()
        }
    }
    
}
