//
//  MapLauncher.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit

func launchNativeAppleMaps(from sourceItem: MKMapItem, to destItem: MKMapItem, transport_type transportType: MKDirectionsTransportType) {
    //  since Apple does not expose the entire transit polyline
    //  we have two solutions:
    //  1). shortcut to apple maps
    //  2). use google maps to get the polyline (Charges $$$$)

    // Set the launch options to enforce public transit
    let mode: String
    switch transportType {
    case .automobile: mode = MKLaunchOptionsDirectionsModeDriving
    case .walking: mode = MKLaunchOptionsDirectionsModeWalking
    case .cycling: mode = MKLaunchOptionsDirectionsModeCycling
    case .transit: mode = MKLaunchOptionsDirectionsModeTransit
    case .any: mode = MKLaunchOptionsDirectionsModeDefault
    default: mode = MKLaunchOptionsDirectionsModeDefault
    }
    let launchOptions = [MKLaunchOptionsDirectionsModeKey: mode]

    // Opens the native Apple Maps app with the calculated transit route
    MKMapItem.openMaps(with: [sourceItem, destItem], launchOptions: launchOptions)
}
