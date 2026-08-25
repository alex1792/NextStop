//
//  DayView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/12.
//

import SwiftUI
import SwiftData

struct DayView: View {
    //  get number of days in the trip
    let trip: Trip
    
    var body: some View {
        //  have days of navigaiotn link to TripDetailPlaceholderView
        List {
            ForEach(1...max(1, trip.numDays), id: \.self, ) { day in
                NavigationLink {
                    TripDetailPlaceholderView(trip: trip, selectedDay: day)
                } label: {
                    HStack {
                        Text("Day \(day)")
                            .font(.body)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Days")
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("Days").font(.title).bold()
//            }
//        }
    }
}

#Preview ("DayView") {
    let sampleTrip = Trip(
        title: "5 Days to Tokyo",
        startDate: Date(),
        endDate: Date(),
        numDays: 5
    )

    return NavigationStack {
        DayView(trip: sampleTrip)
            .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
    }
}
