//
//  CocoaCompatibility.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#if os(OSX)
    import AppKit

    public typealias Color = NSColor
    public typealias Font = NSFont
#else
    import UIKit

    public typealias Color = UIColor
    public typealias Font = UIFont
#endif
