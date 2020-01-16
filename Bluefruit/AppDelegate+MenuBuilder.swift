//
//  AppDelegate+MenuBuilder.swift
//  Bluefruit
//
//  Created by Antonio García on 09/01/2020.
//  Copyright © 2020 Adafruit. All rights reserved.
//

import Foundation

#if targetEnvironment(macCatalyst)
extension AppDelegate {
  override func buildMenu(with builder: UIMenuBuilder) {
 
    // Change only the main menu
    guard builder.system == .main else { return }
 
    // Remove unused menus
    builder.remove(menu: .file)
    builder.remove(menu: .format)
  }
}
#endif
