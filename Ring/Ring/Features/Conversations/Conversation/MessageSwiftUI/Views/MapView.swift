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

class LocationSharingAnnotation: NSObject, MKAnnotation, Identifiable {
    var avatar: UIImage!
    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    init(coordinate: CLLocationCoordinate2D, avatar: UIImage) {
        self.coordinate = coordinate
        self.avatar = avatar
    }
}

struct MapView: View {
    @Binding var annotations: [LocationSharingAnnotation]
    @Binding var showZoomButton: Bool
    @SwiftUI.State private var region = MKCoordinateRegion()

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: annotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    Image(uiImage: annotation.avatar)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }
            .edgesIgnoringSafeArea(.all)
            //            .overlay(mapOverlay())
            .onAppear(perform: {
                zoomMap()
            })

            if showZoomButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            zoomMap(onUserLocation: true)
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.black)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .padding(.trailing, 15)
                                .padding(.bottom, 120)
                        }
                    }
                }
            }
        }
    }

    //    func mapOverlay() -> some View {
    //        MapOverlay(overlayAction: { mapView in
    //            let urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    //            let overlay = MKTileOverlay(urlTemplate: urlTemplate)
    //            overlay.canReplaceMapContent = true
    //            mapView.addOverlay(overlay, level: .aboveLabels)
    //        })
    //    }

    func zoomMap(onUserLocation: Bool = false) {
        DispatchQueue.main.async {
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
    }

    func zoom(on coordinate: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: coordinate, span: span)
            self.region = region
        }
    }
}

struct MapOverlay: UIViewRepresentable {
    var overlayAction: (MKMapView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(overlayAction: overlayAction)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        overlayAction(uiView)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var overlayAction: (MKMapView) -> Void

        init(overlayAction: @escaping (MKMapView) -> Void) {
            self.overlayAction = overlayAction
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(annotations: .init(projectedValue: .constant([
            LocationSharingAnnotation(coordinate: CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417), avatar: UIImage())
        ])), showZoomButton: .constant(true))
    }
}
