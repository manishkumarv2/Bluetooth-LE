//
//  PeripheralViewController.swift
//  TemperatureReader
//
//  Created by Manish Kumar on 12/8/17.
//  Copyright © 2017 v2solutions. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

class PeripheralViewController: UIViewController {
    @IBOutlet weak var advertisingSwitch: UISwitch!
    
    @IBOutlet weak var advertisingLabel: UILabel!
    @IBOutlet weak var tempratureSlider: UISlider!
    
    @IBOutlet weak var tempratureLabel: UILabel!
    
    fileprivate var peripheralManager: CBPeripheralManager?
    fileprivate var transferCharacteristic: CBMutableCharacteristic?
    fileprivate var dataToSend: Data?
    fileprivate var sendDataIndex: Int?
    
    // First up, check if we're meant to be sending an EOM
    fileprivate var sendingEOM = false;
    
    var currentValue = 0 {
        didSet{
            self.tempratureLabel.text = "\(String(currentValue))°"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        currentValue = Int(tempratureSlider.value)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        peripheralManager?.stopAdvertising()
    }
    
    @IBAction func advertisingChange(_ sender: MKUISwitch) {
        if sender.isOn {
            advertisingLabel.text = "Advertising On"
            let advertisementData = [CBAdvertisementDataLocalNameKey: "TestAdvertisementDevice"]
            peripheralManager!.startAdvertising(advertisementData)
        } else {
            advertisingLabel.text = "Advertising Off"
            peripheralManager?.stopAdvertising()
        }
    }
    
    @IBAction func tempratureChange(_ sender: UISlider) {
        currentValue = Int(sender.value)
    }
    
    /** Sends the next amount of data to the connected central
     */
    fileprivate func sendData() {
        if sendingEOM {
            // send it
            let didSend = peripheralManager?.updateValue(
                "EOM".data(using: String.Encoding.utf8)!,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // Did it send?
            if (didSend == true) {
                
                // It did, so mark it as sent
                sendingEOM = false
                
                print("Sent: EOM")
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        guard sendDataIndex < dataToSend?.count else {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToSend!.count - sendDataIndex!;
            
            // Can't be longer than 20 bytes
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = dataToSend!.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
                return Data(
                    bytes: body + sendDataIndex!,
                    count: amountToSend
                )
            }
            
            // Send it
            didSend = peripheralManager!.updateValue(
                chunk as Data,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return
            }
            
            let stringFromData = NSString(
                data: chunk as Data,
                encoding: String.Encoding.utf8.rawValue
            )
            
            print("Sent: \(String(describing: stringFromData))")
            
            // It did send, so update our index
            sendDataIndex! += amountToSend;
            
            // Was it the last one?
            if (sendDataIndex! >= dataToSend!.count) {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true
                
                // Send it
                let eomSent = peripheralManager!.updateValue(
                    "EOM".data(using: String.Encoding.utf8)!,
                    for: transferCharacteristic!,
                    onSubscribedCentrals: nil
                )
                
                if (eomSent) {
                    // It sent, we're all done
                    sendingEOM = false
                    print("Sent: EOM")
                }
                
                return
            }
        }
    }
    
}

extension PeripheralViewController: CBPeripheralManagerDelegate{
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("power on")
            buildService()
        case .poweredOff:
            print("Bluetooth on this device is currently powered off.")
        case .unsupported:
            print("This device does not support Bluetooth Low Energy.")
        case .unauthorized:
            print("This app is not authorized to use Bluetooth Low Energy.")
        case .resetting:
            print("The BLE Manager is resetting; a state update is pending.")
        case .unknown:
            print("The state of the BLE Manager is unknown.")
        }
    }
    
    private func buildService(){
        // Start with the CBMutableCharacteristic
        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: CBCharacteristicProperties.notify,
            value: nil,
            permissions: CBAttributePermissions.readable
        )
        // Then the service
        let transferService = CBMutableService(
            type: transferServiceUUID,
            primary: true
        )
        // Add the characteristic to the service
        transferService.characteristics = [transferCharacteristic!]
        
        // And add it to the peripheral manager
        peripheralManager!.add(transferService)
    }
    
    /** Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
        
        // Get the data
//        dataToSend = tempratureLabel.text?.data(using: String.Encoding.utf8)
        dataToSend = String(currentValue).data(using: String.Encoding.utf8)
        
        // Reset the index
        sendDataIndex = 0;
        
        // Start sending
        sendData()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print(error ?? "UNKNOWN ERROR")
    }
    
    /** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    /** Recognise when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
}
