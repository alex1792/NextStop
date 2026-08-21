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
                    let index: Int  //  the index of polyline in the itinerary
                    let polyline: MKPolyline?
                    let eta: TimeInterval
                }
                
                let results: [SegmentResult] = await withTaskGroup(of: SegmentResult?.self) { group in
                    for i in 1..<coordinates.count {
                        let MKDInstance = getMKDirectionsRequest(source_coor: coordinates[i - 1], destinatin_coor: coordinates[i], source_name: stopsNames[i - 1], destination_name: stopsNames[i], transport_type: transportType, time_interval: 0)
                        
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
                                
                                return SegmentResult(index: i - 1, polyline: response.routes.first?.polyline, eta: eta)
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
                
                //  sort the polylines based on segment index
                self.polylines = results.sorted{$0.index < $1.index}.compactMap{$0.polyline}
                print("Polylines are Sorted...")
                
                // 5. Make sure before updating UI, the task is not canceled at the last minute
                guard !Task.isCancelled else { return }
                
                //  check if transport type is .transit, then launch apple maps
                if transportType == .transit
                {
                    //  calculate ETA
                    self.ETA = await getETAs(coordinate: coordinates, stops_names: stopsNames, transport_type: transportType)
                    
                    self.isLoading = false
                    return
                }

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
    
    @State private var selection: Int = 0
    @State private var selectedSegmentIndex: Int? = nil
    
    private var displayPolylines: [MKPolyline] {
        if let idx = selectedSegmentIndex, idx < viewModel.polylines.count {
            return [viewModel.polylines[idx]]
        }
        return viewModel.polylines
    }
    
    private var displayMapRect: MKMapRect {
        if let idx = selectedSegmentIndex, idx < viewModel.polylines.count {
            return viewModel.polylines[idx].boundingMapRect
        }
        return viewModel.totalMapRect
    }
    
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
                        polylines: displayPolylines,
                        totalMapRect: displayMapRect,
                        singleCoordinate: coordinates.first
                        
                    )
                        .frame(height: 240)
                    
                    ETAHeaderView(eta: self.viewModel.ETA, isLoading: self.viewModel.isLoading, transportType: $transportType)
                    
                    TabView(selection: $selection) {
                        Tab("Itinerary", systemImage:"text.page.fill", value: 0){
                            ItineraryListView(stops: stops, editMode: $editMode, coordinates: coordinates, stopsNames: stopsNames, transportType: transportType, onRecalculate: {
                                viewModel.calculateRoutes(from: coordinates, stopsNames: stopsNames, transportType: transportType)
                            }, onDelete: deleteStop, selectedDay: selectedDay)
                        }
                        
                        Tab("Segments", systemImage: "map.fill", value: 1){
                            Spacer().frame(height: 12)
                            
                            SegmentNavigationView(coordinates: self.coordinates, stopsNames: self.stopsNames, transportType: self.transportType, onSelect: { idx in selectedSegmentIndex = idx })
                        }
                    }
                }
                .task(id: RouteInput(coordinates: coordinates, transportType: transportType)) {
                    viewModel.calculateRoutes(from: coordinates, stopsNames: stopsNames, transportType: transportType)
                }
            }
        }
//        .navigationTitle(selectedDay != nil ? "Day \(selectedDay!)" : trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                let displayText: String = selectedDay != nil ? "Day \(selectedDay!)" : trip.title
                Text(displayText)
                    .font(.title)
                    .bold()
            }
            
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
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                
                Button {
                    showingAddStop = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height:60)
                        .background(Circle().fill(Color.accentColor))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
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

private struct RouteInput: Equatable {
    let coords: [String]
    let transportType: MKDirectionsTransportType
    
    init(coordinates: [CLLocationCoordinate2D], transportType: MKDirectionsTransportType) {
        self.coords = coordinates.map { "\($0.latitude),\($0.longitude)" }
        self.transportType = transportType
    }
}

private struct ItineraryListView: View {
    let stops: [Stop]
    @Binding var editMode: EditMode
    let coordinates: [CLLocationCoordinate2D]
    let stopsNames: [String]
    let transportType: MKDirectionsTransportType
    let onRecalculate: () -> Void
    let onDelete: (IndexSet) -> Void
    
    let selectedDay: Int?
    
    var body: some View {
        List {
            if editMode == .active {
                ForEach(stops) { stop in
                    NavigationLink {
                        StopDetailView(stop: stop, transportType: transportType)
                    } label: {
                        Text(stop.name)
                            .font(.caption)
                    }
                }
                .onDelete { indexSet in
                    guard editMode == .active else { return }
                    onDelete(indexSet)
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
                        StopDetailView(stop: stop, transportType: transportType)
                    } label: {
                        Text(stop.name)
                            .font(.caption)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
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

private struct ETAHeaderView: View {
    let eta: TimeInterval
    let isLoading: Bool
    @Binding var transportType: MKDirectionsTransportType
    
    private var selectionBinding: Binding<Int> {
        Binding<Int>(
            get: {
                switch transportType {
                case .automobile: return 0
                case .walking: return 1
                case .cycling: return 2
                case .transit: return 3
                default: return 0
                }
            },
            set: { newValue in
                switch newValue {
                case 0: transportType = .automobile
                case 1: transportType = .walking
                case 2: transportType = .cycling
                case 3: transportType = .transit
                default: transportType = .automobile
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Travel Mode", selection: selectionBinding) {
                Image(systemName: symbolName(for: .automobile)).tag(0)
                Image(systemName: symbolName(for: .walking)).tag(1)
                Image(systemName: symbolName(for: .cycling)).tag(2)
                Image(systemName: symbolName(for: .transit)).tag(3)
            }
            .pickerStyle(.segmented) // 💡 讓它變成完全扁平的橫向切換鈕
            .padding(.horizontal, 8)
            .padding(.top, 12)       // 調整留白，避免頂部過擠
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 8)

            // ETA row beneath the tabs
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().progressViewStyle(.circular)
                    Text("Calculating")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Expected Travel Time")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(Duration.seconds(self.eta).formatted(.time(pattern: .hourMinute)))
                        .font(.footnote)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 5)
        }
        // Make the header sit flush against the map: no extra top padding
        .padding(.top, 0)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        // Clip content to the rounded shape so it doesn't look like it's floating/overflowing
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
}

private struct SegmentNavigationView: View {
    var coordinates: [CLLocationCoordinate2D]
    var stopsNames: [String]
    var transportType: MKDirectionsTransportType
    let onSelect: (Int) -> Void
    
    var body: some View {
        let segmentIndices = Array(1..<coordinates.count)
        
        ScrollView {
            VStack(spacing: 12) {
                ForEach(segmentIndices, id: \.self) { i in
                    let sourceCoor = self.coordinates[i-1]
                    let destCoor = self.coordinates[i]
                    let sourceName = self.stopsNames[i-1]
                    let destName = self.stopsNames[i]
                    
                    SegmentCard(
                        fromCoor: sourceCoor,
                        toCoor: destCoor,
                        fromName: sourceName,
                        toName: destName,
                        transportType: transportType,
                        onSelect: { onSelect(i - 1) }
                    )
                    
                }
            }
        }
    }
}

private struct SegmentCard: View {
    let fromCoor: CLLocationCoordinate2D
    let toCoor: CLLocationCoordinate2D
    let fromName: String
    let toName: String
    let transportType: MKDirectionsTransportType
    let onSelect: () -> Void
    
    @State private var isLoading: Bool = true
    @State private var eta: TimeInterval = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("from: \(fromName)")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("to: \(toName)")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Calculating ETA…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("ETA: \(Duration.seconds(eta).formatted(.time(pattern: .hourMinute)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
            }
            
            Spacer()
            
            Button {
                let sourceItem = getCurrentLocationMKMapItem()
                let destItem =  makeMKMapItem(location_coordinate: toCoor, location_address: nil, location_name: toName)
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentColor))
            }
            
            Spacer().frame(maxWidth: 10)

            Button {
                let sourceItem = makeMKMapItem(location_coordinate: fromCoor, location_address: nil, location_name: fromName)
                let destItem = makeMKMapItem(location_coordinate: toCoor, location_address: nil, location_name: toName)
                launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.green))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onTapGesture{ onSelect() }
        .task(id: transportType) {
            await loadETA()
        }
        
        Divider()
            .padding(.horizontal, 10)
    }
    
    // 將 async ETA 載入封裝在子 view 內
    private func loadETA() async {
        isLoading = true
        let value = await getETA(
            source_coor: fromCoor,
            dest_coor: toCoor,
            source_name: fromName,
            dest_name: toName,
            transport_type: transportType
        )
        // getETA 可能需要保證回傳值
        await MainActor.run {
            self.eta = value
            self.isLoading = false
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

