//
//  PreferencesViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 20/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {

    // Firmware Updates
    @IBOutlet weak var showBetaVersionsButton: NSButton!
    @IBOutlet weak var updateServerUrlLabel: NSTextField!
    @IBOutlet weak var databaseStatusLabel: NSTextField!
    @IBOutlet weak var databaseStatusWaitView: NSProgressIndicator!
    @IBOutlet weak var ignoredVersionTextField: NSTextField!

    // Uart
    @IBOutlet weak var receivedDataColorWell: NSColorWell!
    @IBOutlet weak var sentDataColorWell: NSColorWell!
    @IBOutlet weak var uartShowInvisibleCharsButton: NSButton!
    
    // Mqtt
    @IBOutlet weak var mqttServerTextField: NSTextField!
    @IBOutlet weak var mqttServerPortTextField: NSTextField!
    @IBOutlet weak var mqttUsernameTextField: NSTextField!
    @IBOutlet weak var mqttPasswordTextField: NSTextField!
    @IBOutlet weak var mqttPublishEnabledButton: NSButton!
    @IBOutlet weak var mqttPublishRXTextField: NSTextField!
    @IBOutlet weak var mqttPublishRXPopupButton: NSPopUpButton!
    @IBOutlet weak var mqttPublishTXTextField: NSTextField!
    @IBOutlet weak var mqttPublishTXPopupButton: NSPopUpButton!
    @IBOutlet weak var mqttSubscribeEnabledButton: NSButton!
    @IBOutlet weak var mqttSubscribeTopicTextField: NSTextField!
    @IBOutlet weak var mqttSubscribeTopicPopupButton: NSPopUpButton!
    @IBOutlet weak var mqttSubscribeActionPopupButton: NSPopUpButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        // Firmware Updates
        showBetaVersionsButton.state = Preferences.showBetaVersions ? NSOnState:NSOffState
        
        if let softwareUpdateIgnoredVersion = Preferences.softwareUpdateIgnoredVersion {
            ignoredVersionTextField.stringValue = softwareUpdateIgnoredVersion
        }
        
        databaseStatusLabel.stringValue = ""
        databaseStatusWaitView.stopAnimation(nil)
        if let absoluteUrlString = Preferences.updateServerUrl?.absoluteString {
            updateServerUrlLabel.stringValue = absoluteUrlString
        }

        // Uart
        uartShowInvisibleCharsButton.state = Preferences.uartShowInvisibleChars ? NSOnState:NSOffState
        
        // Mqtt Server
        let mqttSettings = MqttSettings.sharedInstance
        if let serverAddress = mqttSettings.serverAddress {
            mqttServerTextField.stringValue = serverAddress
        }
        
        mqttServerPortTextField.placeholderString = "\(MqttSettings.defaultServerPort)"
        mqttServerPortTextField.stringValue = "\(mqttSettings.serverPort)"
        
        if let username = mqttSettings.username {
            mqttUsernameTextField.stringValue = username
        }
        
        if let password = mqttSettings.password {
            mqttPasswordTextField.stringValue = password
        }
        
        // Mqtt Publish
        mqttPublishEnabledButton.state =  mqttSettings.isPublishEnabled ? NSOnState : NSOffState
        let rxSettingsIndex = 0
        if let publishRxTopic = mqttSettings.getPublishTopic(index: rxSettingsIndex) {
            mqttPublishRXTextField.stringValue = publishRxTopic
        }
        mqttPublishRXPopupButton.selectItem(at: mqttSettings.getPublishQos(index: rxSettingsIndex).rawValue)
        let txSettingsIndex = 1
        if let publishTxTopic = mqttSettings.getPublishTopic(index: txSettingsIndex) {
            mqttPublishTXTextField.stringValue = publishTxTopic
        }
        mqttPublishTXPopupButton.selectItem(at: mqttSettings.getPublishQos(index: txSettingsIndex).rawValue)
        
        // Mqtt Subscribe
        mqttSubscribeEnabledButton.state =  mqttSettings.isSubscribeEnabled ? NSOnState : NSOffState
        if let subscribeTopic = mqttSettings.subscribeTopic {
            mqttSubscribeTopicTextField.stringValue = subscribeTopic
        }
        mqttSubscribeActionPopupButton.selectItem(at: mqttSettings.subscribeBehaviour.rawValue)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Set first responder
        view.window?.makeFirstResponder(mqttServerTextField)
    }
    
    // MARK: - Firmware Updates
    @IBAction func onEndEditingUpdateServerUrl(_ sender: NSTextField) {
        // DLog("url: \(sender.stringValue)")
        
        let url = URL(string: sender.stringValue)
        databaseStatusLabel.stringValue = "Updating database..."
        databaseStatusWaitView.startAnimation(nil)
        
        Preferences.updateServerUrl = url
        
        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: Preferences.updateServerUrl) { [weak self] success in
            let text = success ?"Database updated successfully" : "Error updating database. Check the URL and Internet connectivity"
            self?.databaseStatusLabel.stringValue = text
            self?.databaseStatusWaitView.stopAnimation(nil)
        }
    }
    
    @IBAction func onEndEditingIgnoredVesion(_ sender: NSTextField) {
        // DLog("url: \(sender.stringValue)")
        
        Preferences.softwareUpdateIgnoredVersion = sender.stringValue
    }
    
    @IBAction func onChangedShowBetaVersions(_ sender: NSButton) {
        Preferences.showBetaVersions = sender.state == NSOnState
    }

    // MARK: - Uart
    /*
    @IBAction func onColorChanged(sender: NSColorWell) {
        if (sender == receivedDataColorWell) {
            Preferences.uartReceveivedDataColor = sender.color
        }
        else if (sender == sentDataColorWell) {
            Preferences.uartSentDataColor = sender.color
        }
    }*/
    
    @IBAction func onChangedUartShowInvisibleChars(_ sender: NSButton) {
        Preferences.uartShowInvisibleChars = sender.state == NSOnState
    }
    
    // MARK: - Mqtt
    @IBAction func onEndEditingMqttServerUrl(_ sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.serverAddress {
            MqttSettings.sharedInstance.serverAddress = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onEndEditingMqttServerPort(_ sender: NSTextField) {
        if let port = Int(sender.stringValue) {
            if port != MqttSettings.sharedInstance.serverPort {
                MqttSettings.sharedInstance.serverPort = port
                MqttManager.sharedInstance.disconnect()
            }
        }
    }
    
    @IBAction func onEndEditingMqttUsername(_ sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.username {
            MqttSettings.sharedInstance.username = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onEndEditingMqttPassword(_ sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.password {
            MqttSettings.sharedInstance.password = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onChangedMqttPublishEnabled(_ sender: NSButton) {
        MqttSettings.sharedInstance.isPublishEnabled = sender.state == NSOnState
    }
    
    @IBAction func onEndEditingMqttPublishRxTopic(_ sender: NSTextField) {
        MqttSettings.sharedInstance.setPublishTopic(index: 0, topic: sender.stringValue)
    }

    @IBAction func onChangedMqttPublishRxQos(_ sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.setPublishQos(index: 0, qos: qos)
        }
    }
    
    @IBAction func onEndEditingMqttPublishTxTopic(_ sender: NSTextField) {
        MqttSettings.sharedInstance.setPublishTopic(index: 1, topic: sender.stringValue)
    }
    
    @IBAction func onChangedMqttPublishTxQos(_ sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.setPublishQos(index: 1, qos: qos)
        }
    }

    @IBAction func onChangedMqttSubscribeEnabled(_ sender: NSButton) {
        MqttSettings.sharedInstance.isSubscribeEnabled = sender.state == NSOnState
    }

    @IBAction func onEndEditingMqttSubscribeTopic(_ sender: NSTextField) {
        MqttSettings.sharedInstance.subscribeTopic = sender.stringValue
    }
    
    @IBAction func onChangedMqttSubscribeQos(_ sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.subscribeQos = qos
        }
    }
    
    @IBAction func onChangedMqttSubscribeAction(_ sender: NSPopUpButton) {
        if let behaviour =  MqttSettings.SubscribeBehaviour(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.subscribeBehaviour = behaviour
        }
    }
 
}
