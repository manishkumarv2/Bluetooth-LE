//
//  HumidityViewController.swift
//  TemperatureReader
//
//  Created by Manish Kumar on 12/7/17.
//  Copyright © 2017 v2solutions. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth


class HumidityViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    fileprivate var centralManager: CBCentralManager?
    fileprivate var discoveredPeripheral: CBPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start up the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("Stopping scan")
        centralManager?.stopScan()
    }
    
    
}

extension HumidityViewController: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state  == .poweredOn else {
            return
        }
        scan()
    }
    func scan() {
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
        print("Scanning started")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        guard let peripheralName = peripheral.name else {
            return
        }
        print("Discovered \(peripheralName) at \(RSSI)")
        
        if discoveredPeripheral != peripheral {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            discoveredPeripheral = peripheral
            
            // And connect
            print("Connecting to peripheral \(peripheral)")
            
            centralManager?.connect(peripheral, options: nil)
        }
    }
}

