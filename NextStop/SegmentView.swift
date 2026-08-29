//
//  SegmentView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/21.
//

import SwiftUI
import SwiftData
import MapKit

struct SegmentView: View {
    let stops: [Stop]
    let transportType: MKDirectionsTransportType = .automobile

    var body: some View {
        if !stops.isEmpty {
            let locationCardIndices = 1..<stops.count

            LocationCardView(stop: stops[0], transportType: transportType)

            ForEach(locationCardIndices, id: \.self) { i in
                NavigationView(source: stops[i - 1], dest: stops[i])

                LocationCardView(stop: stops[i], transportType: transportType)
            }
        }
    }
}

struct LocationCardView: View {
    let stop: Stop
    let transportType: MKDirectionsTransportType

    var body: some View {
        HStack(spacing: 20) {
            //  left: pin icon + name
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.system(size: 20))
                    Text(stop.name)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                    Text(stop.categoryDisplayName)
                }
                .lineLimit(1)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            //  right: navigation button
            Button {
                //  shortcut to launch Apple Maps
                let sourceItem = getCurrentLocationMKMapItem()
                let destItem =  makeMKMapItem(from: stop)
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct NavigationView : View {
    var source: Stop
    var dest: Stop
    
    
    enum TransportMode: CaseIterable, Hashable {
        case driving, walking, cycling, transit
        
        var mkType: MKDirectionsTransportType {
            switch self {
            case .driving: return MKDirectionsTransportType.automobile
            case .walking: return MKDirectionsTransportType.walking
            case .cycling: return MKDirectionsTransportType.cycling
            case .transit: return MKDirectionsTransportType.transit
            }
        }
        
        var label: String {
            switch self {
            case .driving: return "Driving"
            case .walking: return "Walking"
            case .cycling: return "Cycling"
            case .transit: return "Transit"
            }
        }
    }
    
    @State private var eta: TimeInterval = 0
    @State private var distance: CLLocationDistance?
    @State var transportMode: TransportMode = .driving
    @State var isLoading: Bool = false
    
    var body : some View {
        HStack(spacing: 12) {
            Divider()
            
            // Transport selector
            Menu {
                ForEach(TransportMode.allCases, id: \.self) { mode in
                    Button(mode.label) { transportMode = mode }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(transportMode.label)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text("·").foregroundStyle(.tertiary)

            // ETA
            if isLoading {
                ProgressView().scaleEffect(0.7)
            } else {
                Text(Duration.seconds(eta).formatted(.time(pattern: .hourMinute)))
            }

            Text("·").foregroundStyle(.tertiary)

            // Distance
            if isLoading {
                ProgressView().scaleEffect(0.7)
            } else {
                Text(formatDistance(distance))
            }

            Spacer()

            // Nav button
            Button {
                let sourceItem = makeMKMapItem(from: source)
                let destItem = makeMKMapItem(from: dest)
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportMode.mkType)
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tint)
                    Text("Route")
                }
            }
        }
        .font(.system(size: 15, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .task(id: transportMode) {
            await loadETA()
        }
    }
    
    private func loadETA() async {
        isLoading = true
        let value = await getETA(
            from: source,
            to: dest,
            transport_type: transportMode.mkType
        )
        
        let dist = await getDistance(
            from: source,
            to: dest,
            transport_type: transportMode.mkType,
            time_interval: 0.0
        )
        
        // getETA 可能需要保證回傳值
        await MainActor.run {
            self.eta = value
            distance = dist
            isLoading = false
        }
        
        
    }
}

#Preview {
    let stop1 = Stop(name: "Location 1", latitude: 25.0330, longitude: 121.5654, address: "1448 1/2 W 28th St, Los Angeles, CA 90007")
    let stop2 = Stop(name: "Location 2", latitude: 12.213, longitude: 123.134, address: "1351 W 37th St, Los Angeles, CA 90007")
    let stops = [stop1, stop2]
    SegmentView(stops: stops)
        .modelContainer(for: [Stop.self, Trip.self], inMemory: true)
//    LocationCardView(stop: stop1)
//        .modelContainer(for: [Stop.self, Trip.self], inMemory: true)
}

