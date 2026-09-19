//
//  ContentView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
//

import SwiftUI
import SwiftData
import MapKit

//  shared by ContentView.addTrip() and EditTripSheet so both stay in sync
func computeNumDays(start: Date, end: Date) -> Int {
    let calendar = Calendar.current
    let startOfStart = calendar.startOfDay(for: start)
    let startOfEnd = calendar.startOfDay(for: end)
    let diff = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd).day ?? 0
    return max(0, diff) + 1
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]

    @State private var showingAddTripSheet = false
    @State private var showingChatSheet = false
    @State private var newTripTitle = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var numDays: Int = 1
    @State private var showAlert: Bool = false
    @State private var selectedTrip: Trip? = nil
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showDeleteTripConfirm = false
    
    var body: some View {
        NavigationStack {
            Group {
                //  if there is no trip data found, display the following section
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "map",
                        description: Text("Tap \(Image(systemName: "plus")) to plan a new trip.\nOr tap \(Image(systemName: "ellipsis.message.fill")) to let AI build one for you.")
                    )
                } else {
                    //  show all the trips data found
                    List {
                        ForEach(trips) { trip in
                            NavigationLink {
                                DayView(trip: trip)
                            } label: {
                                TripRowView(trip: trip)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    selectedTrip = trip
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                        }
                        .onDelete { offsets in
                            pendingDeleteOffsets = offsets
                            showDeleteTripConfirm = true
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 80)
                    }
                }
            }
            .navigationTitle("Next Stop")
            .overlay(alignment: .bottomLeading) {
                Button(action: {showingChatSheet = true}) {
                    Image(systemName: "ellipsis.message.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 4)
                }
                .padding(.leading, 24)
                .padding(.bottom, 24)
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showingAddTripSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            //  create trip window sheet
            .sheet(isPresented: $showingAddTripSheet) {
                NavigationStack {
                    VStack(alignment: .leading) {
                        Form {
                            Section("Trip Information"){
                                TextField("Example: 5 Days Trip to Tokyo", text: $newTripTitle)
                            }
                            Section("Dates") {
                                DatePicker(
                                    "Start Date",
                                    selection: $startDate,
                                    displayedComponents: [.date],
                                )
                                .onChange(of: startDate) { _, newStart in
                                    if endDate < newStart {
                                        endDate = newStart
                                    }
                                }
                                
                                DatePicker(
                                    "End Date",
                                    selection: $endDate,
                                    in: startDate...,
                                    displayedComponents: [.date]
                                )
                                .onChange(of: endDate) { _, newEnd in
                                    if newEnd < startDate {
                                        endDate = startDate
                                        showAlert = true
                                    }
                                }
                            }
                        }
                        .navigationTitle("Create Itinenary")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    newTripTitle = ""
                                    showingAddTripSheet = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Create") {
                                    addTrip()
                                }
                                .disabled(newTripTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                }
                .alert("Invalid End Date", isPresented: $showAlert) {
                    Button("OK", role: .cancel){
                        showAlert = false
                    }
                    
                } message: {
                    Text("End date must be the same day as or after the start date")
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedTrip) { trip in
                EditTripSheet(trip: trip)
            }
            .sheet(isPresented: $showingChatSheet) {
                AIGeneratorSheet()
            }
            .confirmationDialog(
                "Delete this trip?",
                isPresented: $showDeleteTripConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        deleteTrips(offsets: offsets)
                    }
                    pendingDeleteOffsets = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteOffsets = nil
                }
            } message: {
                Text("This will permanently delete all stops and photos in this trip. This cannot be undone.")
            }
        }
    }
    
    //  functions for adding trip
    private func addTrip() {
        withAnimation {
            let days = computeNumDays(start: startDate, end: endDate)
            let newTrip = Trip(
                title: newTripTitle,
                startDate: startDate,
                endDate:  endDate,
                numDays: days
            )
            
            modelContext.insert(newTrip)
            
            newTripTitle = ""
            startDate = Date()
            endDate = Date()
            showingAddTripSheet = false
        }
    }
    
    //  functon for delete trip
    private func deleteTrips(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                //  delete trips[index] from swift data
                modelContext.delete(trips[index])
            }
        }
    }
}

//  MARK: - EditTripSheet
struct EditTripSheet: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Information") {
                    TextField("Title", text: $trip.title)
                }
                Section("Dates") {
                    DatePicker("Start Date", selection: $trip.startDate, displayedComponents: .date,)
                        .onChange(of: trip.startDate) { _, newStartDate in
                            if trip.endDate < newStartDate {
                                trip.endDate = newStartDate
                            }
                            updateNumDays(start: newStartDate, end: trip.endDate)
                        }
                    DatePicker("End Date", selection: $trip.endDate, in: trip.startDate..., displayedComponents: .date)
                        .onChange(of: trip.endDate) { _, newEndDate in
                            updateNumDays(start: trip.startDate, end: newEndDate)
                        }
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {dismiss()}
                }
            }
        }
        .presentationDetents([.medium])
    }

    //  shrinking the trip drops stops/day-summaries beyond the new range;
    //  growing it needs no extra work since DayView renders 1...numDays on its own
    private func updateNumDays(start: Date, end: Date) {
        let newNumDays = computeNumDays(start: start, end: end)
        if newNumDays < trip.numDays {
            for stop in trip.stops where stop.dayNumber > newNumDays {
                modelContext.delete(stop)
            }
            for summary in trip.daySummary where summary.dayNumber > newNumDays {
                modelContext.delete(summary)
            }
        }
        trip.numDays = newNumDays
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
}
