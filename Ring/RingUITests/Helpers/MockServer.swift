/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import Foundation

import Embassy

class MockNameServer: MockServer {
    let registeredNames = ["alice", "bob", "charlie"]

    init() {
        super.init(app: { environ, startResponse, sendBody in
            let respondWithError: (@escaping ((String, [(String, String)]) -> Void),
                                   @escaping ((Data) -> Void), String)
                -> Void = { startResponse, sendBody, message in
                    startResponse(
                        "500 Internal Server Error",
                        [("Content-Type", "text/plain")]
                    )
                    sendBody(Data(message.utf8))
                    sendBody(Data())
                }

            let respondWithNotFound: (@escaping ((String, [(String, String)]) -> Void),
                                      @escaping ((Data) -> Void))
                -> Void = { startResponse, sendBody in
                    startResponse(
                        "404 Not Found",
                        [("Content-Type", "text/plain")]
                    )
                    sendBody(Data("Not Found".utf8))
                    sendBody(Data())
                }

            let respondWithJSON: (
                @escaping ((String, [(String, String)]) -> Void),
                @escaping ((Data) -> Void),
                Data
            ) -> Void = { startResponse, sendBody, jsonData in
                startResponse("200 OK", [("Content-Type", "application/json")])
                sendBody(jsonData)
                sendBody(Data())
            }

            guard let path = environ["PATH_INFO"] as? String,
                  let method = environ["REQUEST_METHOD"] as? String
            else {
                respondWithError(startResponse, sendBody, "Invalid request")
                return
            }

            if !path.hasPrefix("/name/") {
                respondWithNotFound(startResponse, sendBody)
            }
            let nameValue = String(path.dropFirst("/name/".count))
            // Let's check if the name is in our list of registered names
            let names = ["alice", "bob", "charlie"]
            let isRegistered = names.contains(nameValue)
            var response = [String: Any]()
            if method == "GET" {
                if isRegistered {
                    let someSha1 = "someSha1Value"
                    response = ["name": nameValue, "addr": someSha1]
                } else {
                    response = ["error": "name not registered"]
                }
            } else if method == "POST" {
                if isRegistered {
                    response = ["error": "name is registered"]
                } else {
                    response = ["success": true]
                }
            }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                respondWithJSON(startResponse, sendBody, jsonData)
            } catch {
                respondWithError(startResponse, sendBody, "500 Internal Server Error")
            }
        })
    }

    func getNotRegisteredName() -> String {
        return "not_registered"
    }

    func getRegisteredName() -> String {
        return registeredNames.randomElement()!
    }
}

class MockServer {
    let localServer = "localhost"
    let port = 8080
    var loop: EventLoop!
    var server: HTTPServer!

    init(app: @escaping SWSGI) {
        // Create an event loop
        loop = try! SelectorEventLoop(selector: try! KqueueSelector())
        server = DefaultHTTPServer(eventLoop: loop, interface: localServer, port: port, app: app)
    }

    func start() throws {
        try server.start()

        DispatchQueue.global().async {
            self.loop.runForever()
        }
    }

    func stop() {
        server.stop()
        loop.stop()
    }
}
