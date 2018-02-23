//
//  MKUISwitch.swift
//  POC-CoreStore
//
//  Created by Manish Kumar on 7/4/17.
//  Copyright © 2017 v2solutions. All rights reserved.
//

import Foundation
import UIKit
@IBDesignable

class MKUISwitch: UISwitch {
    
    private var value:String = "Male"
    
    var selectedValue:String {
        get {
            return self.selectedValue
        }
        set (newValue){
            self.selectedValue = newValue
        }
    }
    
    @IBInspectable var OffTint: UIColor? {
        didSet {
            self.tintColor = OffTint
            self.layer.cornerRadius = 16
            self.backgroundColor = OffTint
        }
    }
}
