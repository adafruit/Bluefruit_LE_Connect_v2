//
//  UartStyle.swift
//  Bluefruit
//
//  Created by Antonio on 08/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

class UartStyle {

    static func defaultColors() -> [Color] {
        // Based on Chart joyful and colorful colors:  https://github.com/danielgindi/Charts
        return [
            Color(red: 193/255.0, green: 37/255.0, blue: 82/255.0, alpha: 1.0),
            Color(red: 58/255.0, green: 95/255.0, blue: 201/255.0, alpha: 1.0),     // extra blue
            Color(red: 255/255.0, green: 102/255.0, blue: 0/255.0, alpha: 1.0),
            Color(red: 245/255.0, green: 199/255.0, blue: 0/255.0, alpha: 1.0),
            Color(red: 106/255.0, green: 150/255.0, blue: 31/255.0, alpha: 1.0),
            Color(red: 179/255.0, green: 100/255.0, blue: 53/255.0, alpha: 1.0),

            Color(red: 217/255.0, green: 80/255.0, blue: 138/255.0, alpha: 1.0),
            Color(red: 254/255.0, green: 149/255.0, blue: 7/255.0, alpha: 1.0),
            Color(red: 254/255.0, green: 247/255.0, blue: 120/255.0, alpha: 1.0),
            Color(red: 106/255.0, green: 167/255.0, blue: 134/255.0, alpha: 1.0),
            Color(red: 53/255.0, green: 194/255.0, blue: 209/255.0, alpha: 1.0)
        ]
    }
    
    static func defaultLineDashes() -> [[CGFloat]?] {
        
        return [
            nil,            // -----------------------
            [10, 4],        // -----  -----  -----  -----
            [4, 6],         // --   --   --   --   --
            [8, 8],         // ----    ----    -----
            [2, 4],         // -  -  -  -  -  -  -  -
            [6, 4, 2, 1],   // ---  -  ---  -
        ]
    }
}
