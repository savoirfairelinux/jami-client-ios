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

// struct MapView: View {
//    @ObservedObject var viewModel: MapViewModel
//    @Binding var annotations: [LocationSharingAnnotation]
//    @Binding var showZoomButton: Bool
//
//    var body: some View {
//        ZStack {
//            Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: annotations) { annotation in
//                MapAnnotation(coordinate: annotation.coordinate) {
//                    Image(uiImage: annotation.avatar)
//                        .resizable()
//                        .frame(width: 40, height: 40)
//                        .clipShape(Circle())
//                }
//            }
//            .edgesIgnoringSafeArea(.all)
//            .overlay(MapOverlay(region: $viewModel.region) { mapView, _ in
//                let overlay = MKTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
//                //                overlay.canReplaceMapContent = true
//                mapView.addOverlays([overlay], level: .aboveRoads)
//                mapView.addAnnotations(annotations)
//                mapView.layoutIfNeeded()
//            })
//            .onChange(of: annotations) { _ in
//                if viewModel.isFirstLoad && !annotations.isEmpty {
//                    viewModel.isFirstLoad = false
//                    zoomMap()
//                }
//            }
//
//            if showZoomButton {
//                VStack {
//                    Spacer()
//                    HStack {
//                        Spacer()
//                        Button(action: {
//                            zoomMap(onUserLocation: true)
//                        }) {
//                            Image(systemName: "location.fill")
//                                .foregroundColor(.black)
//                                .padding()
//                                .background(Color(.systemBackground))
//                                .clipShape(Circle())
//                                .padding(.trailing, 15)
//                                .padding(.bottom, 120)
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    func zoomMap(onUserLocation: Bool = false) {
//        if onUserLocation {
//            if let coordinate = CLLocationManager().location?.coordinate {
//                viewModel.zoom(on: coordinate)
//            }
//        } else {
//            if let firstCoordinate = annotations.first {
//                viewModel.zoom(on: firstCoordinate.coordinate)
//            }
//        }
//    }
// }

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

            button.translatesAutoresizingMaskIntoConstraints = false

            mapView.addSubview(button)
            mapView.bringSubviewToFront(button)

            NSLayoutConstraint.activate([
                button.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -120),
                button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -15),
                button.heightAnchor.constraint(equalToConstant: 50),
                button.widthAnchor.constraint(equalToConstant: 50)
            ])

            button.addAction(UIAction(handler: { _ in
                zoomMap(onUserLocation: true)
            }), for: .touchUpInside)
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
