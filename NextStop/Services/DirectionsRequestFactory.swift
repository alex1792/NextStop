//
//  DirectionRequestService.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit
import CoreLocation

func getMKDirectionsRequest(from source: Stop, to dest: Stop, transport_type transportType: MKDirectionsTransportType, time_interval timeInterval: TimeInterval) -> MKDirections {
    let sourceItem = makeMKMapItem(from: source)
    
    let destItem = makeMKMapItem(from: dest)
    
    
    let request = MKDirections.Request()
    request.source = sourceItem
    request.destination = destItem
    request.transportType = transportType
    request.departureDate = Date().addingTimeInterval(timeInterval)
    
    return MKDirections(request: request)
}
