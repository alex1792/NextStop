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
final class StopPhoto {
    @Attribute(.externalStorage) var imageData: Data
    var stop: Stop?

    init(imageData: Data) { self.imageData = imageData }
}

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
    var durationMinutes: Int = 60

    @Relationship(deleteRule: .cascade, inverse: \StopPhoto.stop)
    var photos: [StopPhoto] = []

    @Relationship(inverse: \Trip.stops)
    var trip: Trip?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var category: MKPointOfInterestCategory? {
        get { categoryRawValue.map { MKPointOfInterestCategory(rawValue: $0) } }
        set { categoryRawValue = newValue?.rawValue }
    }

    var categoryDisplayName: String {
        guard let raw = categoryRawValue else { return "—" }
        let stripped = raw.replacingOccurrences(of: "MKPOICategory", with: "")
        guard !stripped.isEmpty else { return "—" }
        var result = ""
        for (i, char) in stripped.enumerated() {
            if char.isUppercase && i > 0 { result += " " }
            result.append(char)
        }
        return result
    }

    var durationFormatted: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }

    init(name: String, latitude: Double, longitude: Double, dayNumber: Int = 1, orderIndex: Int = 0, trip: Trip? = nil, phoneNumber: String? = nil, url: URL? = nil, category: MKPointOfInterestCategory? = nil, address: String?) {
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
