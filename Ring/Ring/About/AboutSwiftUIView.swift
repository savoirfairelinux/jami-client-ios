/*
 * Copyright (C) 2024 Savoir-faire Linux Inc. *
 *
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI
import WebKit

struct HTMLFileView: UIViewRepresentable {
    let htmlFilename: String

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.isOpaque = false
        webview.backgroundColor = .clear
        return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let htmlString = loadHTMLFromFile(named: htmlFilename) {
            // CSS to increase the font size
            let cssString = "<style>body { font-size: 60px; }</style>"

            // Append the CSS to the HTML string
            let modifiedHTMLString = cssString + htmlString

            // Load the modified HTML string
            uiView.loadHTMLString(modifiedHTMLString, baseURL: Bundle.main.bundleURL)
        }
    }

    func loadHTMLFromFile(named filename: String) -> String? {
        guard let filepath = Bundle.main.path(forResource: filename, ofType: "html") else {
            return nil
        }

        do {
            let contents = try String(contentsOfFile: filepath)
            return contents
        } catch {
            print("Error loading HTML: \(error)")
            return nil
        }
    }
}

struct AboutSwiftUIView: View {
    let model = AboutSwiftUIVM()
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 20)
            HStack(alignment: .center) {
                Image("jami_gnupackage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                Spacer()
                //                    .frame(maxWidth: .infinity)
                //                    .frame(height: 10)
                VStack(alignment: .center) {
                    Text(Constants.versionName)
                        .bold()
                    Text("Version: \(model.fullVersion)")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                //                .padding(15)
                //                .background(Color(UIColor.systemGroupedBackground))
                //                .cornerRadius(8)
            }
            .padding(.horizontal, 30)
            Spacer()
                .frame(height: 20)
            Text(.init(model.declarationText))
                .padding(.horizontal)
            Spacer()
                .frame(height: 20)
            Text(.init(model.noWarrantyText))
                .padding(.horizontal)
            Spacer()
                .frame(height: 20)
            Text(.init(model.mainUrlText))
                .padding(.horizontal)
            Spacer()
                .frame(height: 20)
            ScrollView {
                VStack(alignment: .leading) {
                    Text(model.createdLabel)
                        .bold()
                        .font(.caption)
                    Spacer()
                        .frame(height: 10)
                    Text(contributorsDevelopers)
                        .font(.caption)
                    Spacer()
                        .frame(height: 10)
                    Text(model.artworkLabel)
                        .bold()
                        .font(.caption)
                    Spacer()
                        .frame(height: 10)
                    Text(contributorsArts)
                        .font(.caption)
                }
                .padding(.vertical)
                //                HTMLFileView(htmlFilename: "projectcredits")
                //                    .padding()
                //                    .cornerRadius(5)
            }
            // .padding(5)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            Spacer()
                .frame(height: 20)
            HStack {
                Spacer()
                Button(action: {
                    model.openContributeLink()
                }, label: {
                    Text(model.contributeLabel)
                })
                Spacer()
                    .frame(width: 30)
                Button(action: {
                    model.sendFeedback()
                }, label: {
                    Text(model.feedbackLabel)
                })
            }
            .padding(.horizontal)
            Spacer()
                .frame(height: 10)
        }
    }
}
