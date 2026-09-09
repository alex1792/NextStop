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

//  MARK: - RouteViewModel
@Observable
@MainActor
class RouteViewModel {
    var polylines: [MKPolyline] = []
    var totalMapRect: MKMapRect = .null
    var isLoading = false
    var ETA: TimeInterval = 0
    
    // Tracking and Canceling the tasks in queue
    private var routingTask: Task<Void, Never>?
    
    func calculateRoutes(from stops: [Stop], transportType: MKDirectionsTransportType = .automobile) {
        guard stops.count >= 2 else {
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
                    for i in 1..<stops.count {
                        let MKDInstance = getMKDirectionsRequest(from: stops[i-1], to: stops[i], transport_type: transportType, time_interval: 0)
                        
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
                    self.ETA = await getETAs(from: stops, transport_type: transportType)
                    
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

//  MARK: - TripDetailPlaceholderView
struct TripDetailPlaceholderView: View {
    let trip: Trip
    let selectedDay: Int?
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(
        sort: \Stop.orderIndex,
        order: .forward
    )
    private var stops: [Stop]
    
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
    
    private var shareText: String {
        var lines: [String] = [trip.title]

        if let day = selectedDay {
            let dayDate = Calendar.current.date(byAdding: .day, value: day - 1, to: trip.startDate) ?? trip.startDate
            lines.append("Day \(day) · \(dayDate.formatted(date: .abbreviated, time: .omitted))")
        } else {
            lines.append("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) — \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
        }

        lines.append("")

        for stop in stops {
            lines.append("• \(stop.name)")
            if let addr = stop.addressRaw { lines.append("  \(addr)") }
            if !stop.note.isEmpty { lines.append("  Note: \(stop.note)") }
        }
        return lines.joined(separator: "\n")
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
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text(trip.title)
                        .font(.title2)
                        .bold()

                    Text("No stops planned yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                
            } else {
                VStack(spacing: 0) {
                    PolylineMapView(
                        stops: stops,
                        polylines: displayPolylines,
                        totalMapRect: displayMapRect,
                    )
                        .frame(height: 240)
                    
                    ETAHeaderView(eta: self.viewModel.ETA, isLoading: self.viewModel.isLoading, transportType: $transportType)
                    
                    
                    TabView(selection: $selection) {
                        Tab("Itinerary", systemImage:"text.page.fill", value: 0){
                            ItineraryListView(stops: stops, editMode: $editMode, transportType: transportType, onRecalculate: {
                                viewModel.calculateRoutes(from: stops, transportType: transportType)
                            }, onDelete: deleteStop, selectedDay: selectedDay)
                        }
                        
                        Tab("Segments", systemImage: "map.fill", value: 1){
                            Spacer().frame(height: 12)

                            SegmentNavigationView(stops: self.stops, transportType: self.transportType, onSelect: { idx in selectedSegmentIndex = idx })
                                .onAppear {editMode = .inactive}
                        }

                        Tab("Overview", systemImage: "list.clipboard", value: 2) {
                            TripOverviewView(
                                stops: stops,
                                summary: trip.daySummary.first(where: { $0.dayNumber == selectedDay }),
                                eta: viewModel.ETA,
                                isLoading: viewModel.isLoading
                            )
                            .onAppear { editMode = .inactive }
                        }
                    }
                }
                .task(id: RouteInput(stops: stops, transportType: transportType)) {
                    viewModel.calculateRoutes(from: stops, transportType: transportType)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                let displayText: String = selectedDay != nil ? "Day \(selectedDay!)" : trip.title
                Text(displayText)
                    .font(.title)
                    .bold()
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                if selection == 0 {
                    Button {
                        editMode = (editMode == .active) ? .inactive : .active
                    } label: {
                        if editMode == .inactive {
                            Image(systemName: "pencil")
                        } else {
                            Image(systemName: "checkmark")
                        }
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
            if editMode == .inactive {
                HStack {
                    Spacer()

                    Button {
                        showingAddStop = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
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
                trip: trip,
                phoneNumber: pendingSelectedPlace?.phoneNumber,
                url: pendingSelectedPlace?.url,
                category: pendingSelectedPlace?.pointOfInterestCategory,
                address: pendingSelectedPlace?.address?.fullAddress
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

//  MARK: - RouteInput
private struct RouteInput: Equatable {
    let coords: [String]
    let transportType: MKDirectionsTransportType
    
    init(stops: [Stop], transportType: MKDirectionsTransportType) {
        self.coords = stops.map { "\($0.latitude),\($0.longitude)" }
        self.transportType = transportType
    }
}

//  MARK: - ItineraryListView
private struct ItineraryListView: View {
    let stops: [Stop]
    @Binding var editMode: EditMode
    let transportType: MKDirectionsTransportType
    let onRecalculate: () -> Void
    let onDelete: (IndexSet) -> Void
    
    let selectedDay: Int?
    
    var body: some View {
        List {
            ForEach(Array(stops.enumerated()), id: \.element.persistentModelID) { index, stop in
                NavigationLink {
                    StopDetailView(stop: stop, transportType: transportType)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .center)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.fill").font(.caption2)
                                Text(stop.categoryDisplayName)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            if !stop.note.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(stop.durationFormatted)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
            .onDelete { indexSet in
                onDelete(indexSet)
            }
            .onMove { indexSet, destination in
                var newOrder = Array(stops)
                newOrder.move(fromOffsets: indexSet, toOffset: destination)
                for (idx, stop) in newOrder.enumerated() {
                    if stop.orderIndex != idx {
                        stop.orderIndex = idx
                    }
                }
            }
            .deleteDisabled(editMode == .inactive)
            .moveDisabled(editMode == .inactive)
        }
        .environment(\.editMode, $editMode)
    }
}

//  MARK: - ETAHeaderView
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
                    Text("Travel time")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(Duration.seconds(self.eta).formatted(.time(pattern: .hourMinute)))
                        .font(.subheadline)
                        .fontWeight(.bold)
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
                .fill(.regularMaterial)
        )
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

//  MARK: - SegmentNavigationView
private struct SegmentNavigationView: View {
    var stops: [Stop]
    var transportType: MKDirectionsTransportType
    let onSelect: (Int) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                let locationCardIndices = 1..<stops.count
                
                LocationCardView(stop: stops[0], transportType: transportType)
                
                ForEach(locationCardIndices, id: \.self) { i in
                    NavigationView(source: stops[i - 1], dest: stops[i])
                    
                    LocationCardView(stop: stops[i], transportType: transportType)
                }
            }
        }
    }
}

//  MARK: - SegmentCard
private struct SegmentCard: View {
    let source: Stop
    let dest: Stop
    let transportType: MKDirectionsTransportType
    let onSelect: () -> Void
    
    @State private var isLoading: Bool = true
    @State private var eta: TimeInterval = 0
    @State private var distance: CLLocationDistance?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("from: \(source.name)")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("to: \(dest.name)")
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
                    HStack {
                        Text("Distance: \(formatDistance(distance))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer().frame(maxWidth: 20)
                        
                        Text("Expected Travel Time: \(Duration.seconds(eta).formatted(.time(pattern: .hourMinute)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                }
                
            }
            
            Spacer()
            
            Button {
                let sourceItem = getCurrentLocationMKMapItem()
                let destItem =  makeMKMapItem(from: dest)
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
                let sourceItem = makeMKMapItem(from: source)
                let destItem = makeMKMapItem(from: dest)
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
            from: source,
            to: dest,
            transport_type: transportType
        )
        
        let dist = await getDistance(
            from: source,
            to: dest,
            transport_type: transportType,
            time_interval: 0.0
        )
        
        // getETA 可能需要保證回傳值
        await MainActor.run {
            self.eta = value
            self.distance = dist
            self.isLoading = false
        }
        
        
    }
}

//  MARK: - TripOverviewView
private struct TripOverviewView: View {
    let stops: [Stop]
    let summary: DaySummary?
    let eta: TimeInterval
    let isLoading: Bool

    private var totalStayMinutes: Int { stops.reduce(0) { $0 + $1.durationMinutes } }

    private var formattedStay: String {
        let h = totalStayMinutes / 60, m = totalStayMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var formattedETA: String {
        isLoading ? "—" : Duration.seconds(eta).formatted(.time(pattern: .hourMinute))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats row
                HStack(spacing: 12) {
                    OverviewStatCell(icon: "mappin.circle.fill", title: "Stops", value: "\(stops.count)")
                    OverviewStatCell(icon: "clock.fill", title: "Stay", value: formattedStay)
                    OverviewStatCell(icon: "car.fill", title: "Travel", value: formattedETA)
                }
                
                //  DaySummary
                if let summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day Summary")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    
                        Text(summary.summary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                

                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.persistentModelID) { index, stop in
                        HStack(alignment: .top, spacing: 14) {
                            // Timeline indicator column
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.25))
                                        .frame(width: 2, height: 12)
                                } else {
                                    Color.clear.frame(width: 2, height: 12)
                                }

                                ZStack {
                                    Circle().fill(.tint).frame(width: 26, height: 26)
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }

                                if index < stops.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.25))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 26)

                            // Stop info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stop.name)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.top, 2)

                                HStack(spacing: 4) {
                                    Image(systemName: "clock").font(.caption2)
                                    Text(stop.durationFormatted).font(.caption)
                                    if stop.categoryDisplayName != "—" {
                                        Text("·").foregroundStyle(.tertiary)
                                        Text(stop.categoryDisplayName).font(.caption)
                                    }
                                }
                                .foregroundStyle(.secondary)

                                if let addr = stop.addressRaw {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.bottom, 18)

                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
    }
}

//  MARK: - OverviewStatCell
private struct OverviewStatCell: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("TripDetail - without stops") {
    let trip = Trip(title: "Demo", startDate: Date(), endDate: Date(), numDays: 1)
    NavigationStack {
        TripDetailPlaceholderView(trip: trip)
            .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
    }
}

