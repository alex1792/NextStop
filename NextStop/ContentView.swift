//
//  ContentView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
//

import SwiftUI
import SwiftData
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]
    
    @State private var showingAddTripSheet = false
    @State private var newTripTitle = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var numDays: Int = 1
    @State private var showAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                //  if there is no trip data found, display the following section
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Found",
                        systemImage: "map",
                        description: Text("Click the + button at top to create a new trip!")
                    )
                } else {
                    //  show all the trips data found
                    List {
                        ForEach(trips) { trip in
                            NavigationLink {
                                DayView(trip: trip)
//                                TripDetailPlaceholderView(trip: trip)
                            } label: {
                                TripRowView(trip: trip)
                            }
                        }
                        .onDelete(perform: deleteTrips)
                    }
                }
            }
            .navigationTitle("Next Stop📍")
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
        }
    }
    
    //  functions for adding trip
    private func addTrip() {
        withAnimation {
            let days = computeNumDays(start: startDate, end: endDate)
//            print(days)
            let newTrip = Trip(
                title: newTripTitle,
                tripDescription: "Test description",
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
    
    private func computeNumDays(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: start)
        let startOfEnd = calendar.startOfDay(for: end)
        let diff = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd).day ?? 0
        return max(0, diff) + 1
    }
}





#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
}
