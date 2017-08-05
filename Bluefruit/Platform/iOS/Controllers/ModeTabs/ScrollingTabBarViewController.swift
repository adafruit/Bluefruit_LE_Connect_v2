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
            if let viewControllers = viewControllers, selectedIndex != oldValue && selectedIndex >= 0 {
                changeSelectedViewController(viewControllers[selectedIndex])
                selectedIndexDidChange(from: oldValue, to: selectedIndex)
            }
        }
    }

    var selectedViewController: UIViewController? {
        if let viewControllers = viewControllers, selectedIndex >= 0 && selectedIndex < viewControllers.count {
            return viewControllers[selectedIndex]
        } else {
            return nil
        }
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        selectedIndex = -1
    }

    // MARK: - Controllers managament
    func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        self.viewControllers = viewControllers
    }

    func selectedIndexDidChange(from: Int, to:Int) {
        // override to customize behaviour
    }
    
    func hideTabBar(_ hide: Bool) {
        DLog("Hide Tab Bar: \(hide)")
       // tabBarContentView.transform = hide ? CGAffineTransformMakeTranslation(0, tabBarContentView.bounds.size.height):CGAffineTransformIdentity
        tabBarCollectionView.isHidden = hide
    }

    fileprivate func removeSelectedViewController() {
        guard let currentViewController = selectedViewController else { return }

        // Remove previous
        currentViewController.willMove(toParentViewController: nil)
        currentViewController.beginAppearanceTransition(false, animated: false)
        currentViewController.view.removeFromSuperview()
        currentViewController.endAppearanceTransition()
        currentViewController.removeFromParentViewController()
    }

    internal func changeSelectedViewController(_ viewController: UIViewController?) {
        // DLog("changeSelectedViewController \(viewController)")
        guard let viewController = viewController else { return }

        // Add new
        if let containerView = contentView, let subview = viewController.view {
            subview.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(subview)
            self.addChildViewController(viewController)

            let dictionaryOfVariableBindings = ["subview": subview]
            containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
            containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))

            viewController.didMove(toParentViewController: self)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ScrollingTabBarViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers == nil ? 0: viewControllers!.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let reuseIdentifier = "ItemCell"
        let itemCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ScrollingTabBarCollectionViewCell

        if let tabBarItem = viewControllers?[indexPath.row].tabBarItem {
            itemCell.titleLabel.text = tabBarItem.title
            itemCell.iconImageView.image = tabBarItem.image?.withRenderingMode(.alwaysTemplate)
        }
        itemCell.isSelected = indexPath.row == selectedIndex

        return itemCell
    }
}

// MARK: - UICollectionViewDelegate
extension ScrollingTabBarViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        selectedIndex = indexPath.row
        collectionView.reloadData()
        //delegate?.onClickMenuItem(indexPath.row)
        //DLog("catalog didSelectItemAtIndexPath: \(indexPath.item)")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ScrollingTabBarViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let kItemDefaultWidth: CGFloat = 60
        let kDefaultMargin: CGFloat = 20

        var itemWidth = kItemDefaultWidth
        let maxWidth = collectionView.bounds.size.width - kDefaultMargin*2
        let numItems = collectionView.numberOfItems(inSection: 0)
        let itemsWidth = kItemDefaultWidth * CGFloat(numItems)
        if itemsWidth < maxWidth {
            itemWidth = maxWidth / CGFloat(numItems)
        }

        return CGSize(width: itemWidth, height: 49)
    }
}
