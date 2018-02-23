//
//  ViewController.swift
//  TemperatureReader
//
//  Created by Manish Kumar on 12/6/17.
//  Copyright © 2017 v2solutions. All rights reserved.
//

import UIKit
import CoreBluetooth

struct Device {
    // Temperature UUIDs
    static let TemperatureServiceUUID = "E20A39F4-73F5-4BC4-A12F-17D1AD666661"
    static let TemperatureDataUUID = "08590F7E-DB05-467E-8757-72F6F66666D4"
    static let TemperatureConfig = "F000AA02-0451-4000-B000-000000000000"
    
    static let SensorDataIndexTempAmbient = 1
    
    let TRANSFER_CHARACTERISTIC_UUID = "08590F7E-DB05-467E-8757-72F6F66666D4"
    
}

let serviceUUID = CBUUID(string: "7a87af3c-0402-447e-9723-7191fe50091d")
let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6F66666D4" ) //"Test-312-123")

class ViewController: UIViewController {
    
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    
    var centralManager: CBCentralManager!
    var sensorTag: CBPeripheral?
    var temperatureCharacteristic: CBCharacteristic?
    var humidityCharacteristic: CBCharacteristic?
    
    var sensorTagName = "Test123"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("Stopping scan")
        centralManager?.stopScan()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func displayTemperature(data: Data) {
        guard let stringFromData = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
            print("Invalid data")
            return
        }
        print("Received - \(stringFromData)")
        if stringFromData.isEqual(to: "EOM") {
            return
        }
        temperatureLabel.text = "\(stringFromData)"
        
    }
    
    
    
}
extension ViewController: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    func scan(){
//        centralManager?.scanForPeripherals(withServices: nil, options: nil)
        
        centralManager.scanForPeripherals(withServices: [serviceUUID],
                                          options: nil)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("power on")
            scan()
            print("Scanning started")
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
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print(peripheralName)
            if peripheralName == "echo" {
                // 1 - we can stop scanning now.
                //                keepScanning = false
                
                // 2 - save a reference to the sensor tag
                sensorTag = peripheral
                
                // 3 - set the delegate property to point to the view controller
                sensorTag!.delegate = self
                
                // 4 - Request a connection to the peripheral
                centralManager?.connect(sensorTag!, options: nil)
            }
        }
    }
    
    //    MARK - CBPeripheral Delegate
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")
        
        cleanup()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            cleanup()
            return
        }
        
        if let services = peripheral.services {
            for service in services {
//                if service.uuid == CBUUID(string: Device.TemperatureServiceUUID) {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(error?.localizedDescription)")
            cleanup()
            return
        }
        
        if let characteristics = service.characteristics {
            // 1
            var enableValue:UInt8 = 1
            let enableBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)
            
            // 2
            for characteristic in characteristics {
                
                print("Characteristic : \(characteristic)")
                
                // Temperature Data Characteristic
//                if characteristic.uuid == CBUUID(string: Device.TemperatureDataUUID) {
                if characteristic.uuid == characteristicUUID {
                    // 3a
                    // Enable the IR Temperature Sensor notifications
                    temperatureCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        // 1
        // Extract the data from the Characteristic's value property
        // and display the value based on the Characteristic type
        if let dataBytes = characteristic.value {
            if characteristic.uuid == CBUUID(string: Device.TemperatureDataUUID) {
                // 2
                //                displayTemperature(data: dataBytes)
                guard let stringFromData = NSString(data: dataBytes, encoding: String.Encoding.utf8.rawValue) else {
                    print("Invalid data")
                    return
                }
                print("Received - \(stringFromData)")
                if stringFromData.isEqual(to: "EOM") {
                    peripheral.setNotifyValue(false, for: characteristic)
                    
                    // and disconnect from the peripehral
                    centralManager?.cancelPeripheralConnection(peripheral)
                    return
                }
                temperatureLabel.text = "\(stringFromData)"
                
            }
        }
    }
    
    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("Error changing notification state: \(String(describing: error?.localizedDescription))")
        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid.isEqual(characteristicUUID) else {
            return
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            print("Notification began on \(characteristic.uuid)")
        } else { // Notification has stopped
            print("Notification stopped on (\(characteristic))  Disconnecting")
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral Disconnected")
        sensorTag = nil
        // We're disconnected, so start scanning again
        scan()
    }
    
    fileprivate func cleanup() {
        // Don't do anything if we're not connected
        // self.discoveredPeripheral.isConnected is deprecated
        guard sensorTag?.state == .connected else {
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        guard let services = sensorTag?.services else {
            cancelPeripheralConnection()
            return
        }
        
        for service in services {
            guard let characteristics = service.characteristics else {
                continue
            }
            
            for characteristic in characteristics {
                if characteristic.uuid.isEqual(TemperatureCharacteristicUUID) && characteristic.isNotifying {
                    sensorTag?.setNotifyValue(false, for: characteristic)
                    // And we're done.
                    return
                }
            }
        }
    }
    
    fileprivate func cancelPeripheralConnection() {
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager?.cancelPeripheralConnection(sensorTag!)
    }
    
}

