/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        mapView.delegate = context.coordinator
        // Add an OpenStreetMap tile overlay to the map view.
        let urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: urlTemplate)
        overlay.canReplaceMapContent = true
        mapView.addOverlay(overlay, level: .aboveLabels)

        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: coordinates.first!, span: span)
        mapView.setRegion(region, animated: true)
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        for coordinate in coordinates {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            view.addAnnotation(annotation)
        }
    }
}

extension MapView {
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKTileOverlay {
                let renderer = MKTileOverlayRenderer(overlay: overlay)
                return renderer
            } else {
                return MKTileOverlayRenderer()
            }
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(coordinates: [CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417)])
    }
}
