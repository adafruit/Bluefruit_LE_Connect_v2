//
//  ScrollingTabBarViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 27/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ScrollingTabBarViewController: UIViewController {
    
    // UI
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var tabBarCollectionView: UICollectionView!
    
    // Data
    var viewControllers: [UIViewController]? {
        willSet {
            removeSelectedViewController()
            selectedIndex = -1
        }
        
        didSet {
            tabBarCollectionView.reloadData()
            selectedIndex = viewControllers == nil || viewControllers!.count == 0 ? -1:0
        }
    }
    
    var selectedIndex = -1 {
        willSet(newIndex) {
            if selectedIndex != newIndex {
                removeSelectedViewController()
            }
        }
        
        didSet {
            if let viewControllers = viewControllers where selectedIndex != oldValue && selectedIndex >= 0 {
                changeSelectedViewController(viewControllers[selectedIndex])
            }
        }
    }

    var selectedViewController: UIViewController? {
        if let viewControllers = viewControllers where selectedIndex >= 0 && selectedIndex < viewControllers.count {
            return viewControllers[selectedIndex]
        }
        else {
            return nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setViewControllers(viewControllers: [UIViewController]?, animated: Bool) {
        self.viewControllers = viewControllers
    }
    

    func hideTabBar(hide: Bool) {
       // tabBarContentView.transform = hide ? CGAffineTransformMakeTranslation(0, tabBarContentView.bounds.size.height):CGAffineTransformIdentity
        tabBarCollectionView.hidden = hide
    }
    
    private func removeSelectedViewController() {
        // Remove previous
        if let currentViewController = selectedViewController {
            currentViewController.willMoveToParentViewController(nil)
            currentViewController.view.removeFromSuperview()
            currentViewController.removeFromParentViewController()
        }
    }
    
    private func changeSelectedViewController(viewController : UIViewController?) {
        // DLog("changeSelectedViewController \(viewController)")
       
        // Add new
        if let viewController = viewController {
            let containerView = contentView
            let subview = viewController.view
            self.addChildViewController(viewController)
            subview.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(subview)
            
            let dictionaryOfVariableBindings = ["subview" :subview]
            containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
            containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
            
            viewController.didMoveToParentViewController(self)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ScrollingTabBarViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers == nil ? 0: viewControllers!.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let reuseIdentifier = "ItemCell"
        let itemCell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PeripheralDetailsCollectionViewCell
        
        if let tabBarItem = viewControllers?[indexPath.row].tabBarItem {
            itemCell.titleLabel.text = tabBarItem.title
            itemCell.iconImageView.image = tabBarItem.image?.imageWithRenderingMode(.AlwaysTemplate)
        }
        itemCell.selected = indexPath.row == selectedIndex
        
        return itemCell
    }
    
}

// MARK: - UICollectionViewDelegate
extension ScrollingTabBarViewController: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        selectedIndex = indexPath.row
        collectionView.reloadData()
        //delegate?.onClickMenuItem(indexPath.row)
        //DLog("catalog didSelectItemAtIndexPath: \(indexPath.item)")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ScrollingTabBarViewController : UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        let kItemDefaultWidth: CGFloat = 60
        let kDefaultMargin: CGFloat = 20
        
        var itemWidth = kItemDefaultWidth
        let maxWidth = collectionView.bounds.size.width - kDefaultMargin*2
        let numItems = collectionView.numberOfItemsInSection(0)
        let itemsWidth = kItemDefaultWidth * CGFloat(numItems)
        if itemsWidth < maxWidth {
            itemWidth = maxWidth / CGFloat(numItems)
        }
        
        return CGSizeMake(itemWidth, 49)
    }
    
}

