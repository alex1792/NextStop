//
//  TransportTypeAndSymbol.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/19.
//

import MapKit

func symbolName(for type: MKDirectionsTransportType) -> String {
    switch type {
    case .automobile:   return "car.fill"
    case .walking:      return "figure.walk"
    case .cycling:      return "bicycle"
    case .transit:      return "bus.fill"
    case .any:          return "infinity"
    default:            return "car.fill"
    }
}
