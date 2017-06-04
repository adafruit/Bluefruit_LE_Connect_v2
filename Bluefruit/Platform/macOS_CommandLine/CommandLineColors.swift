//
//  SwiftAnsiColors.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/06/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Based on: http://stackoverflow.com/questions/27807925/color-ouput-with-swift-command-line-tool and https://gist.github.com/dainkaplan/4651352
enum CommandLineColors: String {
    /*
    case black = "\u{001B}[0;30m"
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case yellow = "\u{001B}[0;33m"
    case blue = "\u{001B}[0;34m"
    case magenta = "\u{001B}[0;35m"
    case cyan = "\u{001B}[0;36m"
    case white = "\u{001B}[0;37m"
 */
    case reset =        "\u{001B}[0m"

    case normal =       "\u{001B}[0;37m"
    case bold =         "\u{001B}[1;37m"
    case dim =          "\u{001B}[2;37m"

    case italic =       "\u{001B}[3;37m"
    case underline =    "\u{001B}[4;37m"
}

func + (left: CommandLineColors, right: String) -> String {
    return left.rawValue + right
}
