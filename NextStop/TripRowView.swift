//
//  TripRowView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//

import SwiftUI
import SwiftData
import MapKit

struct TripRowView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trip.title).font(.headline)
            
            HStack {
                Image(systemName: "calendar").font(.caption)
                Text(trip.startDate.formatted(date: .numeric, time: .omitted)).font(.subheadline)
                Text("~").font(.subheadline)
                Text(trip.endDate.formatted(date: .numeric, time: .omitted)).font(.subheadline)
            
                Spacer()
                
                Text("\(trip.stops.count) stops")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

