/*
 *  Copyright (C) 2022-2023 Savoir-faire Linux Inc.
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
    @ObservedObject var viewModel: MapViewModel
    @Binding var annotations: [LocationSharingAnnotation]
    @Binding var showZoomButton: Bool
    private let mapView = MKMapView()
    private let button = UIButton(type: .custom)

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        // Add an OpenStreetMap tile overlay to the map view.
        let urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: urlTemplate)
        overlay.canReplaceMapContent = true
        mapView.addOverlay(overlay, level: .aboveLabels)

        if showZoomButton {
            button.frame = CGRect(origin: CGPoint(x: mapView.center.x, y: mapView.center.y), size: CGSize(width: 55, height: 55))
            button.backgroundColor = .systemBackground
            button.layer.cornerRadius = 16
            button.setImage(UIImage(systemName: "location.fill"), for: [])
            button.tintColor = .label

            mapView.addSubview(button)
            mapView.bringSubviewToFront(button)

            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -120),
                button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -15),
                button.heightAnchor.constraint(equalToConstant: 55),
                button.widthAnchor.constraint(equalToConstant: 55)
            ])

            button.addAction(UIAction(handler: { _ in
                zoomMap(onUserLocation: true)
            }), for: .allEvents)
        }

        addPins(mapView: mapView)
        zoomMap()

        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        addPins(mapView: view)
    }

    func addPins(mapView: MKMapView) {
        if mapView.annotations.compactMap({ $0.coordinate }) != annotations.compactMap({ $0.coordinate }) {
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(annotations)
        }
    }

    func zoomMap(onUserLocation: Bool = false) {
        if onUserLocation {
            if let coordinate = CLLocationManager().location?.coordinate {
                zoom(on: coordinate)
            }
        } else {
            if let firstCoordinate = annotations.first {
                zoom(on: firstCoordinate.coordinate)
            }
        }
    }

    func zoom(on coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
}

extension MapView {
    class Coordinator: NSObject, MKMapViewDelegate {

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKTileOverlay {
                let renderer = MKTileOverlayRenderer(overlay: overlay)
                return renderer
            } else {
                return MKTileOverlayRenderer()
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let customAnnotation = annotation as? LocationSharingAnnotation else {
                return nil
            }

            let reuseId = customAnnotation.avatar?.description ?? customAnnotation.description

            var anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            } else {
                anView?.annotation = customAnnotation
            }

            let imageWidth = 35
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: imageWidth, height: imageWidth))
            imageView.image = customAnnotation.avatar
            imageView.layer.cornerRadius = imageView.layer.frame.size.width / 2
            imageView.layer.masksToBounds = true
            anView?.addSubview(imageView)

            return anView
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(viewModel: MapViewModel(), annotations: .init(projectedValue: .constant([
            LocationSharingAnnotation(coordinate: CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417), avatar: UIImage())
        ])), showZoomButton: .constant(true))
    }
}
