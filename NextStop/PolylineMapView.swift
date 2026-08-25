//
//  PolylineMapView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/25.
//
import SwiftUI
import SwiftData
import MapKit

struct PolylineMapView: UIViewRepresentable {
    let stops: [Stop]
    let polylines: [MKPolyline]
    let totalMapRect: MKMapRect

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
        for (idx, stop) in stops.enumerated() {
            let ann = MKPointAnnotation()
            ann.coordinate = stop.coordinate
            ann.title = "Stop \(idx + 1)"
            mapView.addAnnotation(ann)
        }

        //  if only one point, just show the pin
        guard !polylines.isEmpty else {
            if let first = stops.first {
                let region = MKCoordinateRegion(
                    center: first.coordinate,
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
