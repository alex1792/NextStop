//
//  StopDetailView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/28.
//

import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct StopDetailView: View {
    @Bindable var stop: Stop
    var transportType: MKDirectionsTransportType = .automobile

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedPhoto: StopPhoto? = nil

    @FocusState private var isNoteFocused: Bool

    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map View — rounded corners to integrate with card-based layout
                PolylineMapView(stops: [stop], polylines: [], totalMapRect: MKMapRect())
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Location name and category tag
                VStack(alignment: .leading, spacing: 5) {
                    Text(stop.name)
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.fill")
                        Text(stop.categoryDisplayName)
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Info card — grouped with consistent icon size and inset dividers
                VStack(spacing: 0) {
                    // Address (always shown)
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.tint)
                            .font(.system(size: 15))
                            .frame(width: 20)
                        Text(stop.addressRaw ?? "—")
                            .font(.system(size: 15))
                            .foregroundStyle(stop.addressRaw != nil ? .primary : .secondary)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            let sourceItem = getCurrentLocationMKMapItem()
                            let destItem = makeMKMapItem(from: stop)
                            launchNativeAppleMaps(from: sourceItem, to: destItem, transport_type: transportType)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.system(size: 13))
                                Text("Start")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if let phone = stop.phoneNumber {
                        Divider().padding(.leading, 48)

                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.tint)
                                .font(.system(size: 15))
                                .frame(width: 20)
                            Text(phone)
                                .font(.system(size: 15))
                                .lineLimit(1)

                            Spacer()

                            Button {
                                dialPhoneNumber(phone, openURL: openURL)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "phone.arrow.up.right.fill")
                                        .font(.system(size: 13))
                                    Text("Call")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if let url = stop.url {
                        Divider().padding(.leading, 48)

                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundStyle(.tint)
                                .font(.system(size: 15))
                                .frame(width: 20)

                            Link(url.host(percentEncoded: false) ?? url.absoluteString, destination: url)
                                .font(.system(size: 15))
                                .foregroundStyle(.tint)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Duration card
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.tint)
                            .font(.system(size: 15))
                            .frame(width: 20)
                        Text("Stay: \(stop.durationFormatted)")
                            .font(.system(size: 15))
                        Spacer()
                        Stepper("", value: $stop.durationMinutes, in: 0...720, step: 10)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Notes section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("Add a note...", text: $stop.note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .focused($isNoteFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Photos section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        if !stop.photos.isEmpty {
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tint)
                            }
                        }
                    }

                    if stop.photos.isEmpty {
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.secondary)
                                        Text("Add Photo")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stop.photos, id: \.persistentModelID) { photo in
                                    if let uiImage = UIImage(data: photo.imageData) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .onTapGesture { selectedPhoto = photo }

                                            Button {
                                                if let idx = stop.photos.firstIndex(where: { $0.persistentModelID == photo.persistentModelID }) {
                                                    let toDelete = stop.photos.remove(at: idx)
                                                    modelContext.delete(toDelete)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, .black.opacity(0.55))
                                                    .padding(4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: selectedPhotos) { _, items in
                    Task {
                        for item in items {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                let photo = StopPhoto(imageData: data)
                                stop.photos.append(photo)
                            }
                        }
                        selectedPhotos = []
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(item: $selectedPhoto) { photo in
            if let uiImage = UIImage(data: photo.imageData) {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    ZoomableImageView(image: uiImage)
                        .ignoresSafeArea()
                    Button { selectedPhoto = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding(20)
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNoteFocused = false }
            }
        }
    }
}

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.frame = scrollView.bounds
        scrollView.contentSize = scrollView.bounds.size
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            let xInset = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
            let yInset = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: yInset, left: xInset, bottom: yInset, right: xInset)
        }
    }
}

#Preview {
    let stop1 = Stop(name: "Location 1", latitude: 25.0330, longitude: 121.5654, address: "1448 1/2 W 28th St, Los Angeles, CA 90007")
    StopDetailView(stop: stop1, transportType: .automobile)
        .modelContainer(for: [Stop.self, StopPhoto.self], inMemory: true)
}
