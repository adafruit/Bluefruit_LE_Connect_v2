//
//  ReleasesParser.swift
//  Bluefruit
//
//  Created by Antonio on 28/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import SwiftyXMLParser

class BasicVersionInfo {
    var fileType: Int
    var version: String
    var hexFileUrl: URL?
    var iniFileUrl: URL?
    var boardName: String
    var isBeta: Bool
    
    init(fileType: Int, version: String, hexFileUrl: URL?, iniFileUrl: URL?, boardName: String, isBeta: Bool) {
        self.fileType = fileType
        self.version = version
        self.hexFileUrl = hexFileUrl
        self.iniFileUrl = iniFileUrl
        self.boardName = boardName
        self.isBeta = isBeta
    }
}

class FirmwareInfo: BasicVersionInfo {
    var minBootloaderVersion: String
    
    init(fileType: Int, version: String, hexFileUrl: URL?, iniFileUrl: URL?, boardName: String,  isBeta: Bool, minBootloaderVersion: String) {
        self.minBootloaderVersion = minBootloaderVersion
        super.init(fileType: fileType, version: version, hexFileUrl: hexFileUrl, iniFileUrl: iniFileUrl, boardName: boardName, isBeta: isBeta)
    }
}

class BootloaderInfo: BasicVersionInfo {
}

struct BoardInfo {
    var firmwareReleases = [FirmwareInfo]()
    var bootloaderReleases = [BootloaderInfo]()
}

class ReleasesParser {
    static func parse(data: Data, showBetaVersions: Bool) -> [BoardInfo] {
        var boardsReleases = [BoardInfo]()
        
        let xml = XML.parse(data)
        let boards = xml["boards"]["board"]
        for board in boards {
            let boardName = board["_name"].text
            let firmware = board["firmware"]
            
            parseFirmware(board: firmware["firmwarerelease"])
        }
        
        return boardsReleases
    }
    
    
    private static func parseFirmware(board: XML.Accessor) {
        
    }
}
