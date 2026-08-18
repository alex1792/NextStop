//
//  TripDetailPlaceholderView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//
import SwiftUI
import SwiftData
import MapKit
import Observation

@Observable
@MainActor
class RouteViewModel {
    var polylines: [MKPolyline] = []
    var totalMapRect: MKMapRect = .null
    var isLoading = false
    var ETA: TimeInterval = 0
    
    // Tracking and Canceling the tasks in queue
    private var routingTask: Task<Void, Never>?
    
    func calculateRoutes(from coordinates: [CLLocationCoordinate2D], stopsNames: [String], transportType: MKDirectionsTransportType = .automobile) {
        guard coordinates.count >= 2 else {
            self.polylines = []
            self.totalMapRect = .null
            return
        }
        
        // 1.Once the user is editing, cancel the sleeping/waiting tasks
        routingTask?.cancel()
        
        // 2. Create a new debouncing task
        routingTask = Task {
            self.isLoading = true
            
            do {
                // 3. let the task sleep for 0.5 secs (500,000,000 nano secs)
                // if in 0.5s, user drag the UI,task will be canceled and go to the catch section
                try await Task.sleep(nanoseconds: 500_000_000)
                
                let clock = ContinuousClock()
                let start = clock.now
                
                // 4. pass the 0.5s sleep, means user stop editing. Starting sending request for directions
                struct SegmentResult {
                    let polyline: MKPolyline?
                    let eta: TimeInterval
                }
                
                let results: [SegmentResult] = await withTaskGroup(of: SegmentResult?.self) { group in
                    for i in 1..<coordinates.count {
                        let MKDInstance = self.getMKDirectionsRequest(source_coor: coordinates[i - 1], destinatin_coor: coordinates[i], source_name: stopsNames[i - 1], destination_name: stopsNames[i], transport_type: transportType)
                        
                        group.addTask {
                            if transportType == .transit {
                                return nil
                            }
                            
                            // check TaskGroup internally, if its canceled, then terminate
                            if Task.isCancelled { return nil }
                            
                            let clock1 = ContinuousClock()
                            let start1 = clock1.now
                            
                            do {
                                let response = try await MKDInstance.calculate()
                                let elapsed1 = start1.duration(to: clock1.now)
                                let eta = try await MKDInstance.calculateETA().expectedTravelTime
                                print("Segment \(i) took: \(elapsed1)")
                                
                                return SegmentResult(polyline: response.routes.first?.polyline, eta: eta)
                            } catch {
                                print("MKDirections Request failed: \(error)")
                                return nil
                            }
                        }
                    }
                    
                    var results = [SegmentResult]()
                    for await polyline in group {
                        if let polyline { results.append(polyline) }
                    }
                    return results
                }
                
                // 5. Maker sure before updating UI, the task is not canceled at the last minute
                guard !Task.isCancelled else { return }
                
                //  check if transport type is .transit, then launch apple maps
                if transportType == .transit,
                   let sourceCoor = coordinates.first,
                   let destCoor = coordinates.last
                {
                    let sourceItem = self.makeMKMapItem(location_coordinate: sourceCoor, location_address: nil, location_name: stopsNames.first)
                    
                    let destItem = self.makeMKMapItem(location_coordinate: destCoor, location_address: nil, location_name: stopsNames.last)
            
                    //  calculate ETA
                    self.ETA = await self.getETAs(coordinate: coordinates, stops_names: stopsNames, transport_type: transportType)
                    
                    //  launch apple map
                    self.launchNativeAppleMaps(from: sourceItem, to: destItem)
                    
                    self.isLoading = false
                    return
                }

                self.polylines = results.compactMap { $0.polyline }
                self.ETA = results.reduce(0) { $0 + $1.eta }
                if !self.polylines.isEmpty {
                    // use the first route's boundingMapRect as reference
                    var rect = self.polylines[0].boundingMapRect
                    
                    // starting from 2nd route, then keep merging
                    for i in 1..<self.polylines.count {
                        rect = rect.union(self.polylines[i].boundingMapRect)
                    }
                    self.totalMapRect = rect
                }

                self.isLoading = false
                
                let elapse = start.duration(to: clock.now)
                print("Caluculatin Route took: \(elapse)")
                print("ETA: \(Duration.seconds(self.ETA).formatted(.time(pattern: .hourMinute)))")
                
                
            } catch {
                // Task been canceled
                print("Task is canceled or interupted")
            }
        }
    }
    
    private func getETAs(coordinate coordinates: [CLLocationCoordinate2D], stops_names stopsNames: [String], transport_type transportType: MKDirectionsTransportType) async -> TimeInterval {
        var eta: TimeInterval = 0
        for i in 1..<coordinates.count {
            let MKDInstance = self.getMKDirectionsRequest(source_coor: coordinates[i - 1], destinatin_coor: coordinates[i], source_name: stopsNames[i - 1], destination_name: stopsNames[i], transport_type: transportType)
            
            do {
//                let MKDInstance = MKDirections(request: request)
                let seg_eta = try await MKDInstance.calculateETA().expectedTravelTime
                eta += seg_eta
                print("Segment ETA: \(seg_eta)")
            } catch {
                print("MKDirections Request failed: \(error)")
            }
        }
        return eta
    }
    
    private func getMKDirectionsRequest(source_coor sourceCoor: CLLocationCoordinate2D, destinatin_coor destCoor: CLLocationCoordinate2D, source_name sourceName: String, destination_name destName: String, transport_type transportType: MKDirectionsTransportType) -> MKDirections {
        let sourceItem = self.makeMKMapItem(location_coordinate: sourceCoor, location_address: nil, location_name: sourceName)
        
        let destItem = self.makeMKMapItem(location_coordinate: destCoor, location_address: nil, location_name: destName)
        
        
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destItem
        request.transportType = transportType
        
        return MKDirections(request: request)
    }
    
    private func makeMKMapItem(location_coordinate coordinate: CLLocationCoordinate2D, location_address address: MKAddress?, location_name name: String?) -> MKMapItem {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: address)
        item.name = name
        return item
    }
    
    private func launchNativeAppleMaps(from sourceItem: MKMapItem, to destItem: MKMapItem) {
        //  since Apple does not expose the entire transit polyline
        //  we have two solutions:
        //  1). shortcut to apple maps
        //  2). use google maps to get the polyline (Charges $$$$)

        // Set the launch options to enforce public transit
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]

        // Opens the native Apple Maps app with the calculated transit route
        MKMapItem.openMaps(with: [sourceItem, destItem], launchOptions: launchOptions)
    }
}


struct TripDetailPlaceholderView: View {
    let trip: Trip
    let selectedDay: Int?
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(
        sort: \Stop.orderIndex,
        order: .forward
    )
    private var stops: [Stop]

    private var coordinates: [CLLocationCoordinate2D] {
        stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    
    private var stopsNames: [String] {
        stops.map { $0.name }
    }
    
    @State private var viewModel = RouteViewModel()
    @State private var showingAddStop = false
    @State private var newStopName = ""
    @State private var pendingSelectedPlace: MKMapItem?
    @State private var editMode: EditMode = .inactive
    @State private var transportType: MKDirectionsTransportType = .automobile
    
    init(trip: Trip, selectedDay: Int? = nil) {
        self.trip = trip
        self.selectedDay = selectedDay
        let tripID = trip.id
        
        if let day = selectedDay {
            self._stops = Query(
                filter: #Predicate<Stop> {stop in stop.trip?.id == tripID && stop.dayNumber == day},
                sort: \Stop.orderIndex,
                order: .forward
            )
            
        } else {
            self._stops = Query(
                filter: #Predicate<Stop> { stop in stop.trip?.id == tripID },
                sort: \Stop.orderIndex,
                order: .forward
            )
        }
        
    }
    
    var body: some View {
        VStack {
            if stops.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text(trip.title)
                        .font(.title)
                        .bold()
                    
                    Text("No Stops Found in This Trip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                
            } else {
                VStack(spacing: 0) {
                    PolylineMapView(
                        coordinates: coordinates,
                        polylines: viewModel.polylines,
                        totalMapRect: viewModel.totalMapRect,
                        singleCoordinate: coordinates.first
                        
                    )
                        .frame(height: 240)
                    

                    List {
                        Text("ETA: \(Duration.seconds(viewModel.ETA).formatted(.time(pattern: .hourMinute)))")
                        
                        if editMode == .active {
                            ForEach(stops) { stop in
                                NavigationLink {
                                    StopDetailView(stop: stop)
                                } label: {
                                    Text(stop.name)
                                        .font(.caption)
                                }
                            }
                            .onDelete { indexSet in
                                guard editMode == .active else { return }
                                deleteStop(offsets: indexSet)
                            }
                            .onMove { indexSet, destination in
                                guard editMode == .active else { return }
                                var newOrder = Array(stops)
                                newOrder.move(fromOffsets: indexSet, toOffset: destination)
                                for (idx, stop) in newOrder.enumerated() {
                                    if stop.orderIndex != idx {
                                        stop.orderIndex = idx
                                    }
                                }
                            }
                        } else {
                            ForEach(stops) { stop in
                                NavigationLink {
                                    StopDetailView(stop: stop)
                                } label: {
                                    Text(stop.name)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .environment(\.editMode, $editMode)
                    .onChange(of: stops) { oldStops, newStops in
                        // 直接傳入轉換後的經緯度，ViewModel 會自己處理防抖動排隊
                        viewModel.calculateRoutes(from: coordinates, stopsNames: stopsNames, transportType: transportType)
                    }
                    .onChange(of: transportType) {
                        viewModel.calculateRoutes(from: coordinates, stopsNames: stopsNames, transportType: transportType)
                    }
                    .onAppear {
                        // 首次進入頁面直接計算（不需防抖動，直接觸發）
                        viewModel.calculateRoutes(from: coordinates, stopsNames: stopsNames, transportType: transportType)
                    }
                }
            }
        }
        .navigationTitle(selectedDay != nil ? "\(trip.title) · Day \(selectedDay!)" : trip.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    editMode = (editMode == .active) ? .inactive : .active
                } label: {
                    if editMode == .inactive {
                        Image(systemName: "list.bullet")
                    } else {
                        Image(systemName: "checkmark")

                    }
                }
            }
        }
        .sheet(isPresented: $showingAddStop) {
            NavigationStack {
                AddStopSearchView { selectedItem in
                    pendingSelectedPlace = selectedItem
                    addStop(forDay: selectedDay ?? 0)
                }
                .navigationTitle("Search Place")
                
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showingAddStop = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height:60)
                    .background(Circle().fill(Color.accentColor))

            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: {transportType = nextTransportType(for: transportType)}) {
                Image(systemName: symbolName(for: transportType))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.accentColor))
                    
            }
            .padding(.leading, 24)
            .padding(.bottom, 24)
        }

        
    }
    
    private func symbolName(for type: MKDirectionsTransportType) -> String {
        switch type {
        case .automobile:   return "car.fill"
        case .walking:      return "figure.walk"
        case .cycling:      return "bicycle"
        case .transit:      return "bus.fill"
        case .any:          return "infinity"
        default:            return "car.fill"
        }
    }
    
    private func nextTransportType(for type: MKDirectionsTransportType) -> MKDirectionsTransportType {
        switch type {
        case .automobile:   return .walking
        case .walking:      return .cycling
        case .cycling:      return .transit
        case .transit:      return .any
        case .any:          return .automobile
        default:            return .automobile
        }
    }
    
    private func addStop(forDay day: Int) {
        withAnimation {
            let nextIndex = (stops.last?.orderIndex ?? -1) + 1
            let newStop = Stop(
                name: pendingSelectedPlace?.name ?? "Somewhere",
                latitude: pendingSelectedPlace?.location.coordinate.latitude ?? 0.00,
                longitude: pendingSelectedPlace?.location.coordinate.longitude ?? 0.00,
                dayNumber: day,
                orderIndex: nextIndex,
                trip: trip
            )
            
            modelContext.insert(newStop)
            newStopName = ""
        }
        
    }
    
    private func addStop() {
        addStop(forDay: selectedDay ?? 0)
    }
    
    private func deleteStop(offsets: IndexSet) {
        withAnimation {
            for index in offsets{
                let stop = stops[index]
                modelContext.delete(stop)
            }
            
            for (newIndex, stop) in stops.enumerated() {
                if stop.orderIndex != newIndex {
                    stop.orderIndex = newIndex
                }
            }
        }
    }
}

private struct PolylineMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let polylines: [MKPolyline]
    let totalMapRect: MKMapRect
    let singleCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear previous overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add annotations (optional)
        for (idx, coord) in coordinates.enumerated() {
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            ann.title = "Stop \(idx + 1)"
            mapView.addAnnotation(ann)
        }

        //  if only one point, just show the pin
        guard !polylines.isEmpty else {
            if let singleCoordinate {
                let region = MKCoordinateRegion(
                    center: singleCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                mapView.setRegion(region, animated: false)
            }
            return
        }
        
        //  append polylines
        mapView.addOverlays(polylines)
        
        //  set map perspective
        mapView.setVisibleMapRect(
            totalMapRect,
            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
            animated: true
        )
    }
    
    func makeCoordinator() -> Coordinator {
            Coordinator()
    }
        
    // 記得實現 Coordinator 來渲染線條，否則畫面上會看不見線
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}


#Preview("TripDetail - without stops") {
    let trip = Trip(title: "Demo", startDate: Date(), endDate: Date(), numDays: 1)
    NavigationStack {
        TripDetailPlaceholderView(trip: trip)
            .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
    }
}

