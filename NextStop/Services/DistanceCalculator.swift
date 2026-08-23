//
//  DistanceCalculator.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/22.
//

import MapKit

func getDistance(from source: Stop, to dest: Stop, transport_type transportType: MKDirectionsTransportType, time_interval timeInterval: TimeInterval) async -> CLLocationDistance? {
    let request = getMKDirectionsRequest(from: source, to: dest, transport_type: transportType, time_interval: timeInterval)
    do {
        let response = try await request.calculate()
        return response.routes.first?.distance
    } catch {
        print("Fetching Distance Error: \(error)")
        return nil
    }
}

func formatDistance(_ meters: CLLocationDistance?) -> String {
    guard let meters else {return "--"}
    let measurement = Measurement(value: meters, unit: UnitLength.meters)
    return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
}
