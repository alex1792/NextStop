//
//  Trip.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
//

import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID = UUID()
    var title: String
    var tripDescription: String
    var startDate: Date
    var endDate: Date
    var numDays: Int
    
    @Relationship(deleteRule: .cascade)
    var stops: [Stop] = []
    
    init(title: String, tripDescription: String="", startDate: Date=Date(), endDate: Date=Date(), numDays: Int=1) {
        self.title = title
        self.tripDescription = tripDescription
        self.startDate = startDate
        self.endDate = endDate
        self.numDays = numDays
    }
}
