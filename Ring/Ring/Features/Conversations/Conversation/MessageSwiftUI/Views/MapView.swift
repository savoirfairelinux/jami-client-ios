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

class LocationSharingAnnotation: NSObject, MKAnnotation {
    var avatar: UIImage!
    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// class OpenStreetMapTileOverlay: MKTileOverlay, URLSessionDownloadDelegate {
//    let cache = NSCache<NSString, NSData>()
//    let downloadQueue = OperationQueue()
//    var downloadsInProgress = [URL: Operation]()
//
//    override func url(forTilePath path: MKTileOverlayPath) -> URL {
//        return URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
//    }
//
//    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
//        let tileURL = url(forTilePath: path)
//
//        // Check if tile is already cached
//        if let cachedData = cache.object(forKey: tileURL.absoluteString as NSString) {
//            result(cachedData as Data, nil)
//            return
//        }
//
//        // Check if tile download is already in progress
//        if downloadsInProgress[tileURL] != nil {
//            return
//        }
//
//        // Download tile
//        let downloadOperation = BlockOperation {
//            let sessionConfiguration = URLSessionConfiguration.default
//            sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
//            let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
//            let downloadTask = session.downloadTask(with: tileURL)
//            downloadTask.resume()
//        }
//        downloadOperation.completionBlock = {
//            if self.downloadsInProgress.keys.contains(tileURL) {
//                self.downloadsInProgress.removeValue(forKey: tileURL)
//            }
//        }
//        downloadsInProgress[tileURL] = downloadOperation
//        downloadQueue.addOperation(downloadOperation)
//    }
//
//    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//        guard let url = downloadTask.originalRequest?.url else { return }
//
//        do {
//            let data = try Data(contentsOf: location)
//            cache.setObject(data as NSData, forKey: url.absoluteString as NSString)
//            if let response = downloadTask.response as? HTTPURLResponse,
//               response.statusCode == 200 {
//                if let imageData = NSData(contentsOf: location) {
//                    DispatchQueue.main.async {
//                        self.cache.setObject(imageData, forKey: url.absoluteString as NSString)
//
//                        let enumerator = self.cache.keyEnumerator()
//                        var key: NSString?
//
//                        while let currentKey = enumerator.nextObject() as? NSString? {
//                            key = currentKey
//
//                            if let date = self.cache.object(forKey: key!) as? Date {
//                                if date.timeIntervalSinceNow < -3600 { // Replace with your own expiration logic
//                                    self.cache.removeObject(forKey: key!)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            if let tileOperation = downloadsInProgress[url] {
//                tileOperation.completionBlock?()
//            }
//        } catch {
//            print("Error downloading tile: \(error.localizedDescription)")
//        }
//    }
//
//    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        if let error = error {
//            print("Error downloading tile: \(error.localizedDescription)")
//        }
//    }
//
//    private class func prune(_ cache: NSCache<AnyObject, AnyObject>) {
//
//    }
// }

struct MapView: UIViewRepresentable {
    @Binding var coordinates: [(CLLocationCoordinate2D, UIImage)] {
        didSet {
            zoomMap(mapView: mapView)
        }
    }
    let mapView = MKMapView()

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        // Add an OpenStreetMap tile overlay to the map view.
        let urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: urlTemplate)
        overlay.canReplaceMapContent = true
        mapView.addOverlay(overlay, level: .aboveLabels)
        //        addOverlay(to: mapView)

        addPins(mapView: mapView)
        zoomMap(mapView: mapView)
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        addPins(mapView: view)
    }

    func addPins(mapView: MKMapView) {
        if mapView.annotations.compactMap({ $0.coordinate }) != coordinates.compactMap({ $0.0 }) {
            mapView.removeAnnotations(mapView.annotations)
            for coordinate in coordinates {
                let annotation = LocationSharingAnnotation(coordinate: coordinate.0)
                annotation.avatar = coordinate.1
                mapView.addAnnotation(annotation)
            }
        }
    }

    func zoomMap(mapView: MKMapView) {
        if let firstCoordinate = coordinates.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: firstCoordinate.0, span: span)
            mapView.setRegion(region, animated: true)
        }
    }

    //    private func addOverlay(to mapView: MKMapView) {
    //        // Add a custom tile overlay to the map view that downloads and caches OpenStreetMap tiles
    //        let overlay = OpenStreetMapTileOverlay()
    //        overlay.canReplaceMapContent = true
    //        mapView.addOverlay(overlay, level: .aboveLabels)
    //    }
}

extension MapView {
    class Coordinator: NSObject, MKMapViewDelegate {

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer()
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

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(coordinates: .init(projectedValue: .constant([(CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417), UIImage())])))
    }
}
