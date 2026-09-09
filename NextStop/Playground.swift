//
//  Playground.swift
//  NextStop
//
//  Created by Alex Kung on 2026/9/4.
//
import FoundationModels
import Playgrounds

#Playground {
    let session = LanguageModelSession {
        "You are a travel itinerary planner. Generate detailed trip itineraries with specific place names, full street addresses, and realistic visit durations."
    }
    let prompt = "Give me a 5 day itinerary for Tokyo, Japan. Total 20 Stops in 5 days."

    // Pass 1: generate structured itinerary
    let response = try await session.respond(to: prompt, generating: AITrip.self)
    let aiTrip = response.content

    // Pass 2: generate day summaries
    let summarySession = LanguageModelSession {
        "You are a travel writer. Write vivid, detailed travel day summaries."
    }
    for aiDay in aiTrip.days {
        let stopNames = aiDay.stops.map(\.name).joined(separator: ", ")
        let summaryPrompt = "Write a 3 to 5 sentence summary for Day \(aiDay.dayNumber) in \(aiTrip.destination), visiting: \(stopNames). Include food recommendations, cultural highlights, and practical tips."
        let summaryResponse = try await summarySession.respond(to: summaryPrompt)
        print("Day \(aiDay.dayNumber): \(summaryResponse.content)")
    }
}
