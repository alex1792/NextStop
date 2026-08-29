//
//  AddStopSearchView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//

import SwiftUI
import SwiftData
import MapKit

struct AddStopSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var selectedItem: MKMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var onConfirm: (MKMapItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for a place...", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await performSearch() } }
                if isSearching {
                    ProgressView().scaleEffect(0.85)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        selectedItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if results.isEmpty {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if query.isEmpty {
                    // Hint state
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.quaternary)
                        Text("Search for a place to add to your trip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // No results
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "mappin.slash",
                        description: Text("Try searching with a different keyword")
                    )
                }
            } else {
                // Map preview
                if let item = selectedItem {
                    Map(position: $cameraPosition, interactionModes: .all) {
                        Marker(item.name ?? "Selected", coordinate: item.location.coordinate)
                    }
                    .frame(height: 180)
                }

                // Results list — tap to select, no inline "Add" button
                List(results, id: \.self) { item in
                    Button {
                        selectedItem = item
                        cameraPosition = .region(MKCoordinateRegion(
                            center: item.location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name ?? "Unknown")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                if let addr = item.address?.fullAddress {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if selectedItem === item {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    .listRowBackground(
                        selectedItem === item
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
                }
                .listStyle(.plain)

                // Confirm button — only appears when a place is selected
                if let item = selectedItem {
                    Button {
                        onConfirm(item)
                        dismiss()
                    } label: {
                        Text("Add \(item.name ?? "Place")")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await MainActor.run { isSearching = true }
        defer { Task { @MainActor in isSearching = false } }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            let response = try await MKLocalSearch(request: request).start()
            let items = response.mapItems

            await MainActor.run {
                self.results = items
                if let first = items.first {
                    self.selectedItem = first
                    self.cameraPosition = .region(MKCoordinateRegion(
                        center: first.location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                } else {
                    self.selectedItem = nil
                }
            }
        } catch {
            await MainActor.run {
                self.results = []
                self.selectedItem = nil
            }
        }
    }
}
