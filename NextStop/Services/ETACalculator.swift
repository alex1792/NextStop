//
//  ETACalculator.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit

func getETA(from source: Stop, to dest: Stop, transport_type transportType: MKDirectionsTransportType) async -> TimeInterval {
    let MKDInstance = getMKDirectionsRequest(from: source, to: dest, transport_type: transportType, time_interval: 0)
    do {
        let eta = try await MKDInstance.calculateETA().expectedTravelTime
        return eta
    } catch {
       print("fetch ETA error")
    }
    return 0
}
