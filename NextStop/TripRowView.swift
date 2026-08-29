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
                Text(trip.startDate.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                Text("–").font(.subheadline)
                Text(trip.endDate.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
            
                Spacer()

                if trip.stops.count > 0 {
                    Text("\(trip.stops.count) stops")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("No stops yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

