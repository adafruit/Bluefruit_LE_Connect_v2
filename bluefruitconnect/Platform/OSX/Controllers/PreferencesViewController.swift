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

    // Uart
    @IBOutlet weak var receivedDataColorWell: NSColorWell!
    @IBOutlet weak var sentDataColorWell: NSColorWell!
    
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
        showBetaVersionsButton.state = Preferences.showBetaVersions ?NSOnState:NSOffState
        
        databaseStatusLabel.stringValue = ""
        databaseStatusWaitView.stopAnimation(nil)
        if let absoluteUrlString = Preferences.updateServerUrl?.absoluteString {
            updateServerUrlLabel.stringValue = absoluteUrlString
        }

        // Uart
        let uartReceveivedDataColor = Preferences.uartReceveivedDataColor
        receivedDataColorWell.color = uartReceveivedDataColor
        
        let uartSentDataColor = Preferences.uartSentDataColor
        sentDataColorWell.color = uartSentDataColor

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
        if let publishRxTopic = mqttSettings.getPublishTopic(rxSettingsIndex) {
            mqttPublishRXTextField.stringValue = publishRxTopic
        }
        mqttPublishRXPopupButton.selectItemAtIndex(mqttSettings.getPublishQos(rxSettingsIndex).rawValue)
        let txSettingsIndex = 1
        if let publishTxTopic = mqttSettings.getPublishTopic(txSettingsIndex) {
            mqttPublishTXTextField.stringValue = publishTxTopic
        }
        mqttPublishTXPopupButton.selectItemAtIndex(mqttSettings.getPublishQos(txSettingsIndex).rawValue)
        
        // Mqtt Subscribe
        mqttSubscribeEnabledButton.state =  mqttSettings.isSubscribeEnabled ? NSOnState : NSOffState
        if let subscribeTopic = mqttSettings.subscribeTopic {
            mqttSubscribeTopicTextField.stringValue = subscribeTopic
        }
        mqttSubscribeActionPopupButton.selectItemAtIndex(mqttSettings.subscribeBehaviour.rawValue)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Set first responder
        view.window?.makeFirstResponder(mqttServerTextField)
    }
    
    // MARK: - Firmware Updates
    @IBAction func onEndEditingUpdateServerUrl(sender: NSTextField) {
        // DLog("url: \(sender.stringValue)")
        
        let url = NSURL(string: sender.stringValue)
        databaseStatusLabel.stringValue = "Updating database..."
        databaseStatusWaitView.startAnimation(nil)
        
        Preferences.updateServerUrl = url
        
        FirmwareUpdater.refreshSoftwareUpdatesDatabaseFromUrl(Preferences.updateServerUrl, completionHandler: { [weak self] (success) -> Void in
            let text = success ?"Database updated successfully" : "Error updating database. Check the URL and Internet connectivity"
            self?.databaseStatusLabel.stringValue = text
            self?.databaseStatusWaitView.stopAnimation(nil)
        })
    }
    
    @IBAction func onChangedShowBetaVersions(sender: NSButton) {
        Preferences.showBetaVersions = sender.state == NSOnState
    }

    // MARK: - Uart
    @IBAction func onColorChanged(sender: NSColorWell) {
        if (sender == receivedDataColorWell) {
            Preferences.uartReceveivedDataColor = sender.color
        }
        else if (sender == sentDataColorWell) {
            Preferences.uartSentDataColor = sender.color
        }
    }
    
    // MARK: - Mqtt
    @IBAction func onEndEditingMqttServerUrl(sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.serverAddress {
            MqttSettings.sharedInstance.serverAddress = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onEndEditingMqttServerPort(sender: NSTextField) {
        if let port = Int(sender.stringValue) {
            if port != MqttSettings.sharedInstance.serverPort {
                MqttSettings.sharedInstance.serverPort = port
                MqttManager.sharedInstance.disconnect()
            }
        }
    }
    
    @IBAction func onEndEditingMqttUsername(sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.username {
            MqttSettings.sharedInstance.username = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onEndEditingMqttPassword(sender: NSTextField) {
        if sender.stringValue != MqttSettings.sharedInstance.password {
            MqttSettings.sharedInstance.password = sender.stringValue
            MqttManager.sharedInstance.disconnect()
        }
    }
    
    @IBAction func onChangedMqttPublishEnabled(sender: NSButton) {
        MqttSettings.sharedInstance.isPublishEnabled = sender.state == NSOnState
    }
    
    @IBAction func onEndEditingMqttPublishRxTopic(sender: NSTextField) {
        MqttSettings.sharedInstance.setPublishTopic(0, topic: sender.stringValue)
    }

    @IBAction func onChangedMqttPublishRxQos(sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.setPublishQos(0, qos: qos)
        }
    }
    
    @IBAction func onEndEditingMqttPublishTxTopic(sender: NSTextField) {
        MqttSettings.sharedInstance.setPublishTopic(1, topic: sender.stringValue)
    }
    
    @IBAction func onChangedMqttPublishTxQos(sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.setPublishQos(1, qos: qos)
        }
    }

    @IBAction func onChangedMqttSubscribeEnabled(sender: NSButton) {
        MqttSettings.sharedInstance.isSubscribeEnabled = sender.state == NSOnState
    }

    @IBAction func onEndEditingMqttSubscribeTopic(sender: NSTextField) {
        MqttSettings.sharedInstance.subscribeTopic = sender.stringValue
    }
    
    @IBAction func onChangedMqttSubscribeQos(sender: NSPopUpButton) {
        if let qos =  MqttManager.MqttQos(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.subscribeQos = qos
        }
    }
    
    @IBAction func onChangedMqttSubscribeAction(sender: NSPopUpButton) {
        if let behaviour =  MqttSettings.SubscribeBehaviour(rawValue: sender.indexOfSelectedItem) {
            MqttSettings.sharedInstance.subscribeBehaviour = behaviour
        }
    }
}
