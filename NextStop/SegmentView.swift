//
//  SegmentView.swift
//  NextStop
//
//  Created by Alex Kung on 2026/8/21.
//

import SwiftUI
import SwiftData
import MapKit

struct SegmentView: View {
    let stop: Stop
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
            Text("\(stop.name)")
            
            Spacer().frame(maxWidth: 10)
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "tag.fill")
                    Text("\(stop.categoryRawValue ?? "")")
                }
                
                HStack {
                    Image(systemName: "note.text")
                    Text("Note")
                }
            }
            
            Spacer().frame(maxWidth: 10)
            
            Button {
            } label: {
                Image(systemName: "info.circle.fill")
//                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .font(.system(size: 18, weight: .semibold))
    }
}

#Preview {
    let stop = Stop(name: "Test Location", latitude: 25.0330, longitude: 121.5654)
    SegmentView(stop: stop)
        .modelContainer(for: [Stop.self, Trip.self], inMemory: true)
}

