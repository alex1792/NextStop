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
        VStack {
            HStack {
                TextField("Search place", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {await performSearch()}
                    }
                
                if isSearching {
                    ProgressView()
                        .padding(.leading, 4)
                } else {
                    Button("Search") {
                        Task {await performSearch()}
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .background(.thinMaterial)
            
            Divider()
            
            Group {
                if let item = selectedItem{
                    let coordinate = item.location.coordinate
                    Map(position: $cameraPosition, interactionModes: .all) {
                        Annotation(item.name ?? "Selected", coordinate: coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    List(results, id: \.self) { item in
                        Button {
                            selectedItem = item
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: item.location.coordinate,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: 0.05, longitudeDelta: 0.05)
                                )
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    //  location name
                                    Text(item.name ?? "Unknown")
                                        .font(.headline)
                                    
                                    //  location address
                                    Text(item.address?.fullAddress ?? "Unknown")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                }
                                .padding()
                                
                                Spacer()
                                
                                Button("Add") {
                                    onConfirm(item)
                                    dismiss()
                                }
                            }
                            
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        await MainActor.run {
            isSearching = true
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
            }
        }
        
        do {
            //  1. request
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            
            //  2. create MKLocalSearch and execute
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let items = response.mapItems
            
            await MainActor.run {
                //  3. update state and UI
                self.results = items

                if let first = items.first {
                    self.selectedItem = first
                    
                    //  update cameraPosition
                    let coor = first.location.coordinate
                    self.cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coor,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
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
