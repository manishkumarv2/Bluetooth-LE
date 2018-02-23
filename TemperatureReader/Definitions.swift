//
//  Definitions.swift
//  TemperatureReader
//
//  Created by Manish Kumar on 12/8/17.
//  Copyright © 2017 v2solutions. All rights reserved.
//

import CoreBluetooth

let TEMPERATURE_SERVICE_UUID = "E20A39F4-73F5-4BC4-A12F-17D1AD666661"
let TEMPERATURE_CHARACTERISTIC_UUID = "08590F7E-DB05-467E-8757-72F6F66666D4"
let NOTIFY_MTU = 20

let TemperatureServiceUUID = CBUUID(string: TEMPERATURE_SERVICE_UUID)
let TemperatureCharacteristicUUID = CBUUID(string: TEMPERATURE_CHARACTERISTIC_UUID)

let sensorTagName = "TestAdvertisementDevice"
