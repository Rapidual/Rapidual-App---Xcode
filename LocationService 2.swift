//
//  LocationService.swift  
//  Rapidual - App
//
//  Created by Thomas Peters on 10/16/24.
//
//  NOTE: This file is DEPRECATED. Use LocationService.swift instead.
//  This duplicate exists due to file management issues.
//

import Foundation
import CoreLocation
import Combine

/// Service that manages location tracking and authorization
/// DEPRECATED: Use the main LocationService.swift file instead
@MainActor
class LocationServiceLegacy: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authorization status
    @Published private(set) var status: LocationStatus = .notDetermined
    
    /// Full placemark information from reverse geocoding
    @Published private(set) var placemark: CLPlacemark?
    
    /// City/locality name extracted from placemark
    @Published private(set) var locality: String?
    
    /// Whether the current location is within the service area
    @Published private(set) var isInServiceArea: Bool?
    
    /// Current user location
    @Published private(set) var currentLocation: CLLocation?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // Service area boundaries (Irvine, CA and surrounding areas)
    private let serviceAreaCenter = CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265)
    private let serviceAreaRadiusMeters: CLLocationDistance = 25000 // 25km radius
    
    // Additional service areas can be defined here
    private let serviceAreas: [ServiceArea] = [
        ServiceArea(center: CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265), radius: 25000),
        ServiceArea(center: CLLocationCoordinate2D(latitude: 33.6189, longitude: -117.9289), radius: 15000),
        ServiceArea(center: CLLocationCoordinate2D(latitude: 33.6411, longitude: -117.9187), radius: 12000),
        ServiceArea(center: CLLocationCoordinate2D(latitude: 33.7458, longitude: -117.8265), radius: 10000)
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        updateStatus()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .other
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization from the user
    func requestAuthorization() {
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            status = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            status = .authorized
            startLocationUpdates()
        @unknown default:
            status = .notDetermined
        }
    }
    
    /// Refresh the current location
    func refreshLocation() {
        guard status == .authorized else {
            return
        }
        
        locationManager.requestLocation()
    }
    
    /// Start continuous location updates
    func startLocationUpdates() {
        guard status == .authorized else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// Stop location updates to save battery
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Private Methods
    
    private func updateStatus() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            status = .notDetermined
        case .restricted:
            status = .restricted
        case .denied:
            status = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            status = .authorized
        @unknown default:
            status = .notDetermined
        }
    }
    
    private func checkServiceArea(for location: CLLocation) {
        // Check if location is within any of the defined service areas
        let isInArea = serviceAreas.contains { area in
            let areaLocation = CLLocation(latitude: area.center.latitude, longitude: area.center.longitude)
            let distance = location.distance(from: areaLocation)
            return distance <= area.radius
        }
        
        isInServiceArea = isInArea
    }
    
    private func performReverseGeocoding(for location: CLLocation) {
        // Cancel any pending geocoding requests
        geocoder.cancelGeocode()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                Task { @MainActor in
                    self.placemark = placemark
                    self.locality = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationServiceLegacy: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateStatus()
            
            // If authorized, start getting location
            if status == .authorized {
                startLocationUpdates()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location
            checkServiceArea(for: location)
            performReverseGeocoding(for: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        
        // Handle specific error cases
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                Task { @MainActor in
                    status = .denied
                }
            case .locationUnknown:
                print("Location unknown, will retry automatically")
            case .network:
                print("Network error while getting location")
            default:
                print("Other location error: \(clError.code)")
            }
        }
    }
}

// MARK: - Supporting Types

extension LocationServiceLegacy {
    
    /// Location authorization status
    enum LocationStatus {
        case notDetermined
        case restricted
        case denied
        case authorized
    }
}

// MARK: - Convenience Extensions

extension LocationServiceLegacy.LocationStatus {
    
    /// Whether location services are available
    var isAvailable: Bool {
        switch self {
        case .authorized:
            return true
        case .notDetermined, .restricted, .denied:
            return false
        }
    }
    
    /// User-friendly description of the status
    var description: String {
        switch self {
        case .notDetermined:
            return "Location permission not requested"
        case .restricted:
            return "Location services are restricted"
        case .denied:
            return "Location permission denied"
        case .authorized:
            return "Location authorized"
        }
    }
}

extension CLLocationCoordinate2D {
    
    /// Calculate distance to another coordinate in meters
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
}
