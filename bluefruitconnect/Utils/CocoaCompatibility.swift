//
//  CocoaCompatibility.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#if os(OSX)
    public typealias Color = NSColor
    public typealias Font = NSFont
#else
    public typealias Color = UIColor
    public typealias Font = UIFont
#endif

