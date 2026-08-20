//
//  DirectionRequestService.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit
import CoreLocation

func getMKDirectionsRequest(source_coor sourceCoor: CLLocationCoordinate2D, destinatin_coor destCoor: CLLocationCoordinate2D, source_name sourceName: String, destination_name destName: String, transport_type transportType: MKDirectionsTransportType, time_interval timeInterval: TimeInterval) -> MKDirections {
    let sourceItem = makeMKMapItem(location_coordinate: sourceCoor, location_address: nil, location_name: sourceName)
    
    let destItem = makeMKMapItem(location_coordinate: destCoor, location_address: nil, location_name: destName)
    
    
    let request = MKDirections.Request()
    request.source = sourceItem
    request.destination = destItem
    request.transportType = transportType
    request.departureDate = Date().addingTimeInterval(timeInterval)
    
    return MKDirections(request: request)
}
