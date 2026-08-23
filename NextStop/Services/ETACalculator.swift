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

func getETAs(from stops: [Stop], transport_type transportType: MKDirectionsTransportType) async -> TimeInterval {
    var eta: TimeInterval = 0
    for i in 1..<stops.count {
        let MKDInstance = getMKDirectionsRequest(from: stops[i - 1], to: stops[i], transport_type: transportType, time_interval: eta)
        
        do {
            let seg_eta = try await MKDInstance.calculateETA().expectedTravelTime
            eta += seg_eta
            print("Segment ETA: \(seg_eta)")
        } catch {
            print("MKDirections Request failed: \(error)")
        }
    }
    return eta
}
