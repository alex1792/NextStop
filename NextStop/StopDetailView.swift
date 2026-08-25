//
//  StopDetailView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//

import SwiftUI
import SwiftData
import MapKit

struct StopDetailView: View {
    @Bindable var stop: Stop
    var transportType: MKDirectionsTransportType = .automobile

    @FocusState private var isNoteFocused: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map View — rounded corners to integrate with card-based layout
                PolylineMapView(stops: [stop], polylines: [], totalMapRect: MKMapRect())
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Location name and category tag
                VStack(alignment: .leading, spacing: 5) {
                    Text(stop.name)
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                        Text(stop.categoryRawValue?.replacingOccurrences(of: "MKPOICategory", with: "") ?? "—")
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Info card — grouped with consistent icon size and inset dividers
                VStack(spacing: 0) {
                    // Address (always shown)
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.tint)
                            .font(.system(size: 15))
                            .frame(width: 20)
                        Text(stop.addressRaw ?? "—")
                            .font(.system(size: 15))
                            .foregroundStyle(stop.addressRaw != nil ? .primary : .secondary)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            let sourceItem = getCurrentLocationMKMapItem()
                            let destItem = makeMKMapItem(from: stop)
                            launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.system(size: 13))
                                Text("Start")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if let phone = stop.phoneNumber {
                        Divider().padding(.leading, 48)

                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.tint)
                                .font(.system(size: 15))
                                .frame(width: 20)
                            Text(phone)
                                .font(.system(size: 15))
                                .lineLimit(1)

                            Spacer()

                            Button {
                                dialPhoneNumber(phone, openURL: openURL)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "phone.arrow.up.right.fill")
                                        .font(.system(size: 13))
                                    Text("Call")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if let url = stop.url {
                        Divider().padding(.leading, 48)

                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundStyle(.tint)
                                .font(.system(size: 15))
                                .frame(width: 20)

                            Link(url.host(percentEncoded: false) ?? url.absoluteString, destination: url)
                                .font(.system(size: 15))
                                .foregroundStyle(.tint)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Notes section with label
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("Add a note...", text: $stop.note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .focused($isNoteFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNoteFocused = false }
            }
        }
    }
}

#Preview {
    let stop1 = Stop(name: "Location 1", latitude: 25.0330, longitude: 121.5654, address: "1448 1/2 W 28th St, Los Angeles, CA 90007")
    StopDetailView(stop: stop1, transportType: .automobile)
        .modelContainer(for: Stop.self, inMemory: true)
}
