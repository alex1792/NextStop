//
//  MapHelpers.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit
import CoreLocation

func makeMKMapItem(location_coordinate coordinate: CLLocationCoordinate2D, location_address address: MKAddress?, location_name name: String?) -> MKMapItem {
    let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: address)
    item.name = name
    return item
}
