//
//  PhoneLauncher.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/25.
//

import SwiftUI

func dialPhoneNumber(_ phone: String, openURL: OpenURLAction) {
    let digits = phone.filter { $0.isNumber || $0 == "+" }
    if let dialURL = URL(string: "tel:\(digits)") {
        openURL(dialURL)
    }
}
