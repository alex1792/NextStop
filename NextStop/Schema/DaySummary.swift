//
//  DaySummary.swift
//  NextStop
//
//  Created by Alex Kung on 2026/9/8.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit

@Model
final class DaySummary {
    var dayNumber: Int
    var summary: String
    
    @Relationship(inverse: \Trip.daySummary)
    var trip: Trip
    
    init(dayNumber: Int, summary: String, trip: Trip) {
        self.dayNumber = dayNumber
        self.summary = summary
        self.trip = trip
    }
}
