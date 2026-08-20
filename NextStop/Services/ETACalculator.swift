//
//  ETACalculator.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit

func getETA(source_coor sourceCoor: CLLocationCoordinate2D, dest_coor destCoor: CLLocationCoordinate2D, source_name sourceName: String, dest_name destName: String, transport_type transportType: MKDirectionsTransportType) async -> TimeInterval {
    let MKDInstance = getMKDirectionsRequest(source_coor: sourceCoor, destinatin_coor: destCoor, source_name: sourceName, destination_name: destName, transport_type: transportType, time_interval: 0)
    do {
        let eta = try await MKDInstance.calculateETA().expectedTravelTime
        return eta
    } catch {
       print("fetch ETA error")
    }
    return 0
}

func getETAs(coordinate coordinates: [CLLocationCoordinate2D], stops_names stopsNames: [String], transport_type transportType: MKDirectionsTransportType) async -> TimeInterval {
    var eta: TimeInterval = 0
    for i in 1..<coordinates.count {
        let MKDInstance = getMKDirectionsRequest(source_coor: coordinates[i - 1], destinatin_coor: coordinates[i], source_name: stopsNames[i - 1], destination_name: stopsNames[i], transport_type: transportType, time_interval: eta)
        
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
