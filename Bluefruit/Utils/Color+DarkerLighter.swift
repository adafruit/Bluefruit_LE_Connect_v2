//
//  Color+DarkerLighter.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 27/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// based on: http://stackoverflow.com/questions/11598043/get-slightly-lighter-and-darker-color-from-uicolor
extension Color {

    func lighter(_ amount: CGFloat = 0.25) -> Color {
        return hueColorWithBrightnessAmount(1 + amount)
    }

    func darker(_ amount: CGFloat = 0.25) -> Color {
        return hueColorWithBrightnessAmount(1 - amount)
    }

    private func hueColorWithBrightnessAmount(_ amount: CGFloat) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        #if os(iOS)

            if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
                return Color( hue: hue,
                    saturation: saturation,
                    brightness: brightness * amount,
                    alpha: alpha )
            } else {
                return self
            }

        #else

            getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return Color( hue: hue,
                saturation: saturation,
                brightness: brightness * amount,
                alpha: alpha )

        #endif

    }
}
