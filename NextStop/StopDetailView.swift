//
//  StopDetailView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//

import SwiftUI
import SwiftData
import MapKit

struct StopDetailView: View {
    let stop: Stop
    
    var body: some View {
        VStack {
            Text(stop.name)
            
            Text("\(stop.latitude)")
            
            Text("\(stop.longitude)")
        }
        
    }
}
