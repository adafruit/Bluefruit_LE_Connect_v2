//
//  ReleasesParser.swift
//  Bluefruit
//
//  Created by Antonio on 28/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
#if COMMANDLINE
#else
    import SwiftyXML
#endif

class BasicVersionInfo {
    var fileType: UInt8 // DFUFirmwareType
    var version: String
    var hexFileUrl: URL?
    var iniFileUrl: URL?
    var zipFileUrl: URL?
    var boardName: String
    var isBeta: Bool

    // TODO: add zip files
    init(fileType: UInt8/*DFUFirmwareType*/, version: String, hexFileUrl: URL?, iniFileUrl: URL?, boardName: String, isBeta: Bool) {
        self.fileType = fileType
        self.version = version
        self.hexFileUrl = hexFileUrl
        self.iniFileUrl = iniFileUrl
        self.boardName = boardName
        self.isBeta = isBeta
    }
    
}

class FirmwareInfo: BasicVersionInfo {
    var minBootloaderVersion: String?

    init(fileType: UInt8 /*DFUFirmwareType*/, version: String, hexFileUrl: URL?, iniFileUrl: URL?, boardName: String, isBeta: Bool, minBootloaderVersion: String?) {
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
    static func parse(data: Data, showBetaVersions: Bool) -> [String: BoardInfo] {
        var boardsReleases = [String: BoardInfo]()

        guard let xml = XML(data: data) else {
            DLog("Error: Releases xml not valid")
            return [:]
        }

        let boards = xml["boards"]["board"]
        for board in boards {
            if let boardName = board.attributes["name"] {

                var boardInfo = BoardInfo()

                // Read firmware releases
                let firmwareNode = board["firmware"]
                parseFirmwareNodes(firmwareNode["firmwarerelease"], boardName: boardName, isBeta: false, into: &boardInfo.firmwareReleases)

                // Read beta firmware releases
                if showBetaVersions {
                    parseFirmwareNodes(firmwareNode["firmwarebeta"], boardName: boardName, isBeta: true, into: &boardInfo.firmwareReleases)
                }

                // Sort based on version (descending)
                boardInfo.firmwareReleases.sort(by: { (f1, f2) -> Bool in
                    return f1.version.compare(f2.version, options: [.numeric]) == .orderedDescending
                })

                // Read bootloader releases
                let bootloaderNode = board["bootloader"]
                parseBootloaderNodes(bootloaderNode["bootloaderrelease"], boardName: boardName, isBeta: false, into: &boardInfo.bootloaderReleases)

                // Read beta firmware releases
                if showBetaVersions {
                    parseBootloaderNodes(bootloaderNode["bootloaderbeta"], boardName: boardName, isBeta: true, into: &boardInfo.bootloaderReleases)
                }

                // Sort based on version (descending)
                boardInfo.bootloaderReleases.sort(by: { (f1, f2) -> Bool in
                    return f1.version.compare(f2.version, options: [.numeric]) == .orderedDescending
                })

                // Add result
                boardsReleases[boardName] = boardInfo
            } else {
                DLog("Warning: board with no name")
            }
        }

        return boardsReleases
    }

    private static func parseFirmwareNodes(_ nodes: XMLSubscriptResult, boardName: String, isBeta: Bool, into firmwareReleases: inout [FirmwareInfo]) {
        for node in nodes {
            if let firmwareInfo = parseFirmwareNode(node, boardName: boardName, isBeta: isBeta) {
                firmwareReleases.append(firmwareInfo)
            }
        }
    }

    private static func parseBootloaderNodes(_ nodes: XMLSubscriptResult, boardName: String, isBeta: Bool, into bootloaderReleases: inout [BootloaderInfo]) {
        for node in nodes {
            if let bootloaderInfo = parseBootloaderNode(node, boardName: boardName, isBeta: isBeta) {
                bootloaderReleases.append(bootloaderInfo)
            }
        }
    }

    private static func parseFirmwareNode(_ node: XMLSubscriptResultIterator.Element, boardName: String, isBeta: Bool) -> FirmwareInfo? {
        let attributes = node.attributes
        let hexFile = attributes["hexfile"]
        let hexFileUrl =  hexFile != nil ? URL(string: hexFile!):nil
        let iniFile = attributes["initfile"]
        let iniFileUrl = iniFile != nil ? URL(string: iniFile!):nil
        let minBootloaderVersion = attributes["minbootloader"]

        guard let version = attributes["version"] else {
            DLog("Warning: Firmware node with invalid version")
            return nil
        }

        let releaseInfo = FirmwareInfo(fileType: UInt8(4) /*DFUFirmwareType.application*/, version: version, hexFileUrl: hexFileUrl, iniFileUrl: iniFileUrl, boardName: boardName, isBeta: isBeta, minBootloaderVersion: minBootloaderVersion)
        return releaseInfo
    }

    private static func parseBootloaderNode(_ node: XMLSubscriptResultIterator.Element, boardName: String, isBeta: Bool) -> BootloaderInfo? {
        let attributes = node.attributes
        let hexFile = attributes["hexfile"]
        let hexFileUrl =  hexFile != nil ? URL(string: hexFile!):nil
        let iniFile = attributes["initfile"]
        let iniFileUrl = iniFile != nil ? URL(string: iniFile!):nil

        guard let version = attributes["version"] else {
            DLog("Warning: Bootloader node with invalid version")
            return nil
        }

        let bootloaderInfo = BootloaderInfo(fileType: UInt8(2) /*DFUFirmwareType.bootloader*/, version: version, hexFileUrl: hexFileUrl, iniFileUrl: iniFileUrl, boardName: boardName, isBeta: isBeta)
        return bootloaderInfo
    }
}
