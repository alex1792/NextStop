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
    var transportType: MKDirectionsTransportType = .automobile
    
    init(stop: Stop, transportType: MKDirectionsTransportType) {
        self.stop = stop
        self.transportType = transportType
    }
    
    var body: some View {
        VStack {
            Text(stop.name)
            
            Text("\(stop.latitude)")
            
            Text("\(stop.longitude)")
            
            Button {
                let sourceItem = getCurrentLocationMKMapItem()
                let destItem =  makeMKMapItem(from: stop)
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentColor))
            }
        }
        
    }
}
