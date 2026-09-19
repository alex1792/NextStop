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

// Plain, Sendable snapshot of an MKMapItem lookup — lets the network lookup
// run inside a TaskGroup without a non-Sendable MKMapItem/Stop crossing the
// concurrency boundary (SwiftData models aren't Sendable).
struct ResolvedPlace: Sendable {
    var latitude: Double
    var longitude: Double
    var phoneNumber: String?
    var url: URL?
    var categoryRawValue: String?
    var address: String?
}

extension AIStop {
    func resolvePlace() async -> ResolvedPlace {
        let mapItem = await fetchMapItem()
        return ResolvedPlace(
            latitude: mapItem?.location.coordinate.latitude ?? 0.0,
            longitude: mapItem?.location.coordinate.longitude ?? 0.0,
            phoneNumber: mapItem?.phoneNumber,
            url: mapItem?.url,
            categoryRawValue: mapItem?.pointOfInterestCategory?.rawValue,
            address: mapItem?.address?.fullAddress ?? (address.isEmpty ? nil : address)
        )
    }

    func toStop(trip: Trip, resolved: ResolvedPlace) -> Stop {
        let stop = Stop(
            name: name,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            dayNumber: dayNumber,
            orderIndex: orderIndex,
            trip: trip,
            phoneNumber: resolved.phoneNumber,
            url: resolved.url,
            category: resolved.categoryRawValue.map { MKPointOfInterestCategory(rawValue: $0) },
            address: resolved.address
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

        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            messages.append(ChatMessage(role: .assistant, text: Self.unavailableMessage(for: reason)))
            state = .failed
            return
        }

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
            if #available(iOS 27.0, *), let modelError = error as? LanguageModelError {
                messages.append(ChatMessage(role: .assistant, text: Self.message(for: modelError)))
            } else {
                messages.append(ChatMessage(role: .assistant, text: "Sorry, something went wrong. Please try again."))
            }
            state = .failed
        }
    }

    private static func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so AI trip generation isn't available here."
        case .appleIntelligenceNotEnabled:
            return "Please turn on Apple Intelligence in Settings to use AI trip generation."
        case .modelNotReady:
            return "The on-device AI model is still downloading or preparing. Please try again in a bit."
        @unknown default:
            return "AI trip generation isn't available on this device right now."
        }
    }

    @available(iOS 27.0, *)
    private static func message(for error: LanguageModelError) -> String {
        switch error {
        case .guardrailViolation:
            return "That request couldn't be processed because it triggered a safety guardrail. Try rephrasing your trip description."
        case .refusal:
            return "The AI couldn't generate a response for that request. Try describing your trip differently."
        case .rateLimited:
            return "Too many requests right now. Please wait a moment and try again."
        case .contextSizeExceeded:
            return "That request is too long for the AI to process. Try a shorter or simpler description."
        case .unsupportedLanguageOrLocale:
            return "This language isn't supported for AI trip generation yet."
        default:
            return "Sorry, something went wrong. Please try again."
        }
    }

    func apply(to modelContext: ModelContext) async {
        guard let aiTrip = generatedTrip else { return }
        let trip = aiTrip.toTrip()

        for aiDay in aiTrip.days {
            let summaryContent = generatedSummary[aiDay.dayNumber] ?? aiDay.summary
            let daySummary = DaySummary(dayNumber: aiDay.dayNumber, summary: summaryContent, trip: trip)
            modelContext.insert(daySummary)
        }

        // Resolve all stops' places concurrently instead of one MKLocalSearch/geocode
        // request at a time — this is the difference between ~1s and ~20s of
        // "Saving..." for a full multi-day itinerary. Only the Sendable
        // ResolvedPlace crosses the concurrency boundary; the SwiftData Stop
        // models themselves are built back on the main actor below.
        let allAIStops = aiTrip.days.flatMap(\.stops)
        let resolvedPlaces = await withTaskGroup(of: (Int, ResolvedPlace).self) { group -> [Int: ResolvedPlace] in
            for (index, aiStop) in allAIStops.enumerated() {
                group.addTask { (index, await aiStop.resolvePlace()) }
            }
            var collected: [Int: ResolvedPlace] = [:]
            for await (index, resolved) in group {
                collected[index] = resolved
            }
            return collected
        }

        for (index, aiStop) in allAIStops.enumerated() {
            guard let resolved = resolvedPlaces[index] else { continue }
            let stop = aiStop.toStop(trip: trip, resolved: resolved)
            trip.stops.append(stop)
        }

        modelContext.insert(trip)
    }

    func reset() {
        messages = []
        generatedSummary = [:]
        state = .idle
    }
}
