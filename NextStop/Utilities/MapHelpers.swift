//
//  MapHelpers.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit
import CoreLocation

func makeMKMapItem(from stop: Stop) -> MKMapItem {
    let item = MKMapItem(
        location: CLLocation(latitude: stop.latitude, longitude: stop.longitude), address: nil)
    item.name = stop.name
    item.phoneNumber = stop.phoneNumber
    item.url = stop.url
    item.pointOfInterestCategory = stop.category
    return item
}

func getCurrentLocationMKMapItem() -> MKMapItem {
    return MKMapItem.forCurrentLocation()
}
