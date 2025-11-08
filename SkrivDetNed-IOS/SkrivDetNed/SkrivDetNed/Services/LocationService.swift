//
//  LocationService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var currentLocationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Get current location once
    func getCurrentLocation() async -> (location: CLLocation?, name: String?)? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("⚠️ Location permission not granted")
            return nil
        }

        locationManager.requestLocation()

        // Wait for location update (with timeout)
        let startTime = Date()
        while currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        guard let location = currentLocation else {
            print("⚠️ Failed to get location")
            return nil
        }

        // Reverse geocode to get place name
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = [
                    placemark.name,
                    placemark.locality,
                    placemark.country
                ].compactMap { $0 }.joined(separator: ", ")

                currentLocationName = name
                print("📍 Location: \(name)")
                return (location, name)
            }
        } catch {
            print("⚠️ Geocoding failed: \(error)")
        }

        return (location, nil)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                self.currentLocation = location
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            print("📍 Location authorization: \(manager.authorizationStatus.rawValue)")
        }
    }
}
