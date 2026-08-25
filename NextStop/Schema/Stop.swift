//
//  Stop.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit

@Model
final class Stop {
    var name: String
    var latitude: Double
    var longitude: Double
    var dayNumber: Int
    var orderIndex: Int
    var phoneNumber: String?
    var url: URL?
    var categoryRawValue: String?
    var note: String = ""
    var addressRaw: String?
    
    @Relationship(inverse: \Trip.stops)
    var trip: Trip?
    
    //  let MapKit can use the map attribute
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var category: MKPointOfInterestCategory? {
        get {categoryRawValue.map {MKPointOfInterestCategory(rawValue: $0)}}
        set {categoryRawValue = newValue?.rawValue}
    }
    
    init(name: String, latitude: Double, longitude: Double, dayNumber: Int=1, orderIndex: Int=0, trip: Trip? = nil, phoneNumber: String? = nil, url: URL? = nil, category: MKPointOfInterestCategory? = nil, address: String?) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.dayNumber = dayNumber
        self.orderIndex = orderIndex
        self.trip = trip
        self.phoneNumber = phoneNumber
        self.url = url
        self.categoryRawValue = category?.rawValue
        self.addressRaw = address
    }
}
