//
//  Order Tracking.swift
//  Rapidual - Perplexity
//
//  Created by Thomas Peters on 11/16/25.
//

import SwiftUI
import Combine

class OrderTrackingViewModel: ObservableObject {
    @Published var driverName: String = "John Doe"
    @Published var estimatedArrival: String = "15 minutes"
    @Published var liveLocation: String = "En route"
    @Published var status: String = "Picked up"
    
    // Simulate updates
    func updateStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.status = "In wash"
            self.estimatedArrival = "1 hour"
        }
    }
}

struct OrderTrackingView: View {
    @StateObject private var viewModel = OrderTrackingViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Order Tracking")
                .font(.largeTitle)
            
            Text("Driver: \(viewModel.driverName)")
            Text("Estimated Arrival: \(viewModel.estimatedArrival)")
            Text("Live Location: \(viewModel.liveLocation)")
            Text("Status: \(viewModel.status)")
            
            // Placeholder for map view
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
                .overlay(Text("Map View Here"))
        }
        .padding()
        .onAppear {
            viewModel.updateStatus()
        }
    }
}

#Preview {
    OrderTrackingView()
}
