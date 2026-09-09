//
//  AITripGenerator.swift
//  NextStop
//
//  Created by Alex Kung on 2026/9/5.
//

import Foundation
import FoundationModels
import SwiftData
import MapKit

// MARK: - Generable Types

@Generable
struct AITrip {
    var title: String
    var tripDescription: String
    var destination: String
    var startDate: String
    var endDate: String
    @Guide(description: "One entry per day of the trip.")
    var days: [AIDay]
}

@Generable
struct AIDay {
    var dayNumber: Int
    @Guide(description: "A 3 to 5 sentence summary of this day including food, activities, cultures, and highlights.")
    var summary: String
    @Guide(description: "At least 3 stops to visit.", .minimumCount(3))
    var stops: [AIStop]
}

@Generable
struct AIStop {
    var name: String
    var dayNumber: Int
    var orderIndex: Int
    var category: String
    var address: String
    var durationMinutes: Int
    var description: String
}

// MARK: - Conversion Extensions

extension AITrip {
    func toTrip() -> Trip {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let start = formatter.date(from: startDate) ?? Date()
        let end = formatter.date(from: endDate) ?? Calendar.current.date(
            byAdding: .day, value: days.count - 1, to: start
        ) ?? Date()

        let trip = Trip(title: title, startDate: start, endDate: end, numDays: days.count)
        trip.tripDescription = tripDescription.isEmpty ? nil : tripDescription
        return trip
    }
}

extension AIStop {
    func toStop(trip: Trip) async -> Stop {
        let mapItem = await fetchMapItem()
//        let (lat, lng) = await geocoordinate(from: address)
        
        let stop = Stop(
            name: name,
            latitude: mapItem?.location.coordinate.latitude ?? 0.0,
            longitude: mapItem?.location.coordinate.longitude ?? 0.0,
            dayNumber: dayNumber,
            orderIndex: orderIndex,
            trip: trip,
            phoneNumber: mapItem?.phoneNumber,
            url: mapItem?.url,
            category: mapItem?.pointOfInterestCategory,
            address: mapItem?.address?.fullAddress ?? (address.isEmpty ? nil : address)
        )
        stop.durationMinutes = durationMinutes > 0 ? durationMinutes : 60
        return stop
    }
    
    private func fetchMapItem() async -> MKMapItem? {
        let searchQuery = address.isEmpty ? name : "\(name), \(address)"
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchQuery
        
        if let items = try? await MKLocalSearch(request: searchRequest).start().mapItems,
           let first = items.first {
            return first
        }
        
        // Fallback：純地址 geocoding（無 POI metadata）
        guard !address.isEmpty,
              let geocodeRequest = MKGeocodingRequest(addressString: address) else {
            return nil
        }
        return try? await geocodeRequest.mapItems.first
    }

    private func geocoordinate(from address: String) async -> (Double, Double) {
        guard !address.isEmpty,
              let request = MKGeocodingRequest(addressString: address) else {
            return (0.0, 0.0)
        }
        guard let mapItem = try? await request.mapItems.first else {
            return (0.0, 0.0)
        }
        let coord = mapItem.location.coordinate
        return (coord.latitude, coord.longitude)
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role { case user, assistant }
}

// MARK: - Trip Generator

@Observable
@MainActor
final class TripGenerator {

    enum State {
        case idle
        case generating
        case done(AITrip)
        case failed
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var generatedSummary: [Int: String] = [:]  //  dayNumber -> daySummary
    private(set) var state: State = .idle

    var isGenerating: Bool {
        if case .generating = state { return true }
        return false
    }

    var generatedTrip: AITrip? {
        if case .done(let trip) = state { return trip }
        return nil
    }

    func send(prompt: String) async {
        guard !isGenerating else { return }
        messages.append(ChatMessage(role: .user, text: prompt))
        state = .generating

        do {
            let session = LanguageModelSession {
                "You are a travel itinerary planner. Generate detailed trip itineraries with specific place names, full street addresses, and realistic visit durations."
            }
            let response = try await session.respond(to: prompt, generating: AITrip.self)
            let aiTrip = response.content
            let stopCount = aiTrip.days.flatMap(\.stops).count
            messages.append(ChatMessage(
                role: .assistant,
                text: "Here's your \(aiTrip.days.count)-day itinerary for \(aiTrip.destination) with \(stopCount) stops!"
            ))
            
            // generate summary for each day
            let summarySession = LanguageModelSession {
                "You are a travel writer. Write vivid, detailed travel day summaries."
            }
            for aiDay in aiTrip.days {
                let stopNames = aiDay.stops.map(\.name).joined(separator: ", ")
                let summaryPrompt = "Write a 3 to 5 sentence summary for Day \(aiDay.dayNumber) in \(aiTrip.destination), visiting: \(stopNames). Include food recommendations, cultural highlights, and practical tips."
                let summaryResponse = try await summarySession.respond(to: summaryPrompt)
                messages.append(ChatMessage(
                    role: .assistant,
                    text: summaryResponse.content
                ))
                generatedSummary[aiDay.dayNumber] = summaryResponse.content
            }
            
            state = .done(aiTrip)
        } catch {
            messages.append(ChatMessage(role: .assistant, text: "Sorry, something went wrong. Please try again."))
            state = .failed
        }
    }

    func apply(to modelContext: ModelContext) async {
        guard let aiTrip = generatedTrip else { return }
        let trip = aiTrip.toTrip()
        for aiDay in aiTrip.days {
            let summaryContent = generatedSummary[aiDay.dayNumber] ?? aiDay.summary
            let daySummary = DaySummary(dayNumber: aiDay.dayNumber, summary: summaryContent, trip: trip)
            modelContext.insert(daySummary)
            
            for aiStop in aiDay.stops {
                let stop = await aiStop.toStop(trip: trip)
                trip.stops.append(stop)
            }
        }
        modelContext.insert(trip)
    }

    func reset() {
        messages = []
        generatedSummary = [:]
        state = .idle
    }
}
