import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status {
        case notDetermined, denied, restricted, authorized
    }

    @Published var status: Status = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isInServiceArea: Bool?
    @Published var placemark: CLPlacemark?
    @Published var locality: String?

    private let manager = CLLocationManager()
    private let serviceAreas: [ServiceArea]

    private var geocodeTask: Task<Void, Never>?

    override init() {
        self.serviceAreas = ServiceArea.defaultAreas
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(manager.authorizationStatus)
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            refreshLocation()
        default:
            break
        }
    }

    private func updateAuthorization(_ clStatus: CLAuthorizationStatus) {
        switch clStatus {
        case .notDetermined: status = .notDetermined
        case .restricted:    status = .restricted
        case .denied:        status = .denied
        case .authorizedAlways, .authorizedWhenInUse: status = .authorized
        @unknown default:    status = .notDetermined
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        isInServiceArea = serviceAreas.contains { $0.contains(loc.coordinate) }
        reverseGeocode(location: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }

    private func reverseGeocode(location: CLLocation) {
        geocodeTask?.cancel()

        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            geocodeTask = Task { [weak self] in
                guard let self else { return }
                do {
                    guard let request = MKReverseGeocodingRequest(location: location) else {
                        self.placemark = nil
                        self.locality = nil
                        return
                    }
                    let items = try await request.mapItems
                    if Task.isCancelled { return }
                    if let first = items.first {
                        self.placemark = first.placemark
                        self.locality = first.placemark.locality
                    } else {
                        self.placemark = nil
                        self.locality = nil
                    }
                } catch is CancellationError {
                } catch {
                    self.placemark = nil
                    self.locality = nil
                }
            }
        } else {
            // Instantiate CLGeocoder only in the legacy path to avoid deprecation warnings on new SDKs.
            let legacyGeocoder = CLGeocoder()
            legacyGeocoder.cancelGeocode()
            legacyGeocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                guard let self else { return }
                if let _ = error {
                    self.placemark = nil
                    self.locality = nil
                    return
                }
                if let first = placemarks?.first {
                    self.placemark = first
                    self.locality = first.locality
                } else {
                    self.placemark = nil
                    self.locality = nil
                }
            }
        }
    }
}
