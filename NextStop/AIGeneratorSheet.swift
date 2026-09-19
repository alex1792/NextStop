//
//  AIGeneratorSheet.swift
//  NextStop
//
//  Created by Alex Kung on 2026/9/5.
//

import SwiftUI
import SwiftData

struct AIGeneratorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var generator = TripGenerator()
    @State private var promptText = ""
    @State private var isApplying = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesScrollView
                Divider()
                if generator.generatedTrip != nil {
                    actionButtons
                } else {
                    inputBar
                }
            }
            .navigationTitle("Plan with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if generator.messages.isEmpty {
                        welcomeView
                    }
                    ForEach(generator.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }
                    if generator.isGenerating {
                        TypingIndicatorView()
                            .id("typing")
                    }
                    if case .done(let aiTrip) = generator.state {
                        TripPreviewCard(aiTrip: aiTrip)
                            .padding(.horizontal)
                            .id("preview")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical)
            }
            .onChange(of: generator.messages.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: generator.isGenerating) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Plan your trip with AI")
                .font(.headline)
            Text("Describe where you want to go and how many days, and I'll build a complete itinerary for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Try Again") {
                generator.reset()
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    isApplying = true
                    await generator.apply(to: modelContext)
                    isApplying = false
                    dismiss()
                }
            } label: {
                if isApplying {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Saving...")
                    }
                } else {
                    Text("Apply Itinerary")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying)
        }
        .padding()
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Describe your trip...", text: $promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .disabled(generator.isGenerating)

            Button {
                let prompt = promptText.trimmingCharacters(in: .whitespaces)
                guard !prompt.isEmpty else { return }
                promptText = ""
                Task { await generator.send(prompt: prompt) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        promptText.trimmingCharacters(in: .whitespaces).isEmpty || generator.isGenerating
                            ? AnyShapeStyle(.tertiary)
                            : AnyShapeStyle(Color.accentColor)
                    )
            }
            .disabled(promptText.trimmingCharacters(in: .whitespaces).isEmpty || generator.isGenerating)
            .animation(.easeInOut(duration: 0.15), value: promptText.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .onAppear { animating = true }
    }
}

// MARK: - Trip Preview Card

struct TripPreviewCard: View {
    let aiTrip: AITrip

    private var totalStops: Int { aiTrip.days.flatMap(\.stops).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(aiTrip.title)
                        .font(.headline)
                    Text("\(aiTrip.days.count) days · \(totalStops) stops")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "map.fill")
                    .foregroundStyle(.tint)
            }

            Divider()

            ForEach(aiTrip.days, id: \.dayNumber) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day \(day.dayNumber)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(Array(day.stops.enumerated()), id: \.offset) { _, stop in
                        Label(stop.name, systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    AIGeneratorSheet()
}
