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
                let date =  Calendar.current.date(byAdding: .day, value: day - 1, to: trip.startDate)!
                let count = trip.stops.filter { $0.dayNumber == day }.count
                
                NavigationLink {
                    TripDetailPlaceholderView(trip: trip, selectedDay: day)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(day)")
                                .font(.headline)
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        if count > 0 {
                            Text("\(count) stops")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        } else {
                            Text("No stops")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle(trip.title)
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
