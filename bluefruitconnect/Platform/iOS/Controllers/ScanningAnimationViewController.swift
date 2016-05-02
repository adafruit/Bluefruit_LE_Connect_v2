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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if isAnimating {
            startAnimating()
        }
        
        // Observe notifications for coming back from background
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name:UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    func applicationWillEnterForeground(notification: NSNotification) {
        // Restarts animation when coming back from background
        
        if isAnimating {
            startAnimating()
        }
    }
    
    func startAnimating() {
        isAnimating = true
        
        guard isViewLoaded() else {
            return
        }
        
        // Scanning animation
        let duration: Double = 15
        let initialScaleFactor: CGFloat = 0.17
        let finalScaleFactor: CGFloat = 2.0

        // First wave
        self.scanningWave0ImageView.transform = CGAffineTransformMakeScale(initialScaleFactor, initialScaleFactor);
        self.scanningWave0ImageView.alpha = 1
        UIView.animateWithDuration(duration, delay: 0, options: [.Repeat, .CurveEaseInOut], animations: {[unowned self] () -> Void in
            self.scanningWave0ImageView.transform = CGAffineTransformMakeScale(finalScaleFactor, finalScaleFactor);
            self.scanningWave0ImageView.alpha = 0;
            }, completion: nil)
        
        // Second wave
        self.scanningWave1ImageView.transform = CGAffineTransformMakeScale(initialScaleFactor, initialScaleFactor);
        self.scanningWave1ImageView.alpha = 1
        UIView.animateWithDuration(duration, delay: duration/2, options: [.Repeat, .CurveEaseInOut], animations: { [unowned self] () -> Void in
            self.scanningWave1ImageView.transform = CGAffineTransformMakeScale(finalScaleFactor, finalScaleFactor);
            self.scanningWave1ImageView.alpha = 0;
            }, completion: nil)
    }
    
    func stopAnimating() {
        isAnimating = false
        
        if isViewLoaded() {
            scanningWave0ImageView.layer.removeAllAnimations()
            scanningWave1ImageView.layer.removeAllAnimations()
        }
    }
    
}
