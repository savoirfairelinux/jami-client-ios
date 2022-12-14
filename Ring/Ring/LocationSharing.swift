//
//  LocationSharing.swift
//  Ring
//
//  Created by Alireza Toghiani on 12/14/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

import MapKit

// struct LocationSharing: UIViewRepresentable {
//
//    init() {
//        //        let tileOverlay = MKTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
//        //        tileOverlay.canReplaceMapContent = true
//        //        view.addOverlay(tileOverlay, level: .aboveLabels)
//    }
//
//    func makeUIView(context: Context) -> MKMapView {
//        MKMapView(frame: .zero)
//    }
//
//    func updateUIView(_ view: MKMapView, context: Context) {
//        // Set the map's center coordinate and zoom level
//        let coordinate = CLLocationCoordinate2D(
//            latitude: 34.011286, longitude: -116.166868)
//        let span = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
//        let region = MKCoordinateRegion(center: coordinate, span: span)
//        view.setRegion(region, animated: true)
//    }
// }

struct LocationSharing: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        view.addAnnotation(annotation)
    }
}

struct LocationSharing_Previews: PreviewProvider {
    static var previews: some View {
        LocationSharing(coordinate: CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417))
    }
}
