//
//  SegmentView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/21.
//

import SwiftUI
import SwiftData
import MapKit

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

//  the 4 selectable modes for a single leg, in menu display order
private let legTransportChoices: [MKDirectionsTransportType] = [.automobile, .walking, .cycling, .transit]

private func legTransportLabel(for type: MKDirectionsTransportType) -> String {
    switch type {
    case .automobile: return "Driving"
    case .walking:     return "Walking"
    case .cycling:     return "Cycling"
    case .transit:     return "Transit"
    default:           return "Driving"
    }
}

struct NavigationView: View {
    var source: Stop
    var dest: Stop
    //  this leg's default when `dest` has no override of its own
    var defaultTransportType: MKDirectionsTransportType

    @State private var eta: TimeInterval = 0
    @State private var distance: CLLocationDistance?
    @State var isLoading: Bool = false

    //  dest carries the override for "how we got here"; nil means it just
    //  follows the day's default set in ETAHeaderView
    private var isCustom: Bool { dest.preferredTransportType != nil }
    private var effectiveType: MKDirectionsTransportType { dest.preferredTransportType ?? defaultTransportType }

    var body : some View {
        HStack(spacing: 12) {
            Divider()

            // Transport selector — overrides this leg only, everything else keeps following the default
            Menu {
                ForEach(legTransportChoices, id: \.rawValue) { mode in
                    Button {
                        dest.preferredTransportType = mode
                    } label: {
                        Label(legTransportLabel(for: mode), systemImage: symbolName(for: mode))
                    }
                }
                if isCustom {
                    Divider()
                    Button("Reset to Default", role: .destructive) {
                        dest.preferredTransportType = nil
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(legTransportLabel(for: effectiveType))
                    if isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(isCustom ? Color.accentColor : .secondary)
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
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: effectiveType)
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
        .task(id: effectiveType) {
            await loadETA()
        }
    }

    private func loadETA() async {
        isLoading = true
        let value = await getETA(
            from: source,
            to: dest,
            transport_type: effectiveType
        )

        let dist = await getDistance(
            from: source,
            to: dest,
            transport_type: effectiveType,
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
    return VStack {
        LocationCardView(stop: stop1, transportType: .automobile)
        NavigationView(source: stop1, dest: stop2, defaultTransportType: .automobile)
        LocationCardView(stop: stop2, transportType: .automobile)
    }
    .modelContainer(for: [Stop.self, Trip.self], inMemory: true)
}

