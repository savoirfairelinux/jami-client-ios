/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

struct SettingsView: View {

    @StateObject var viewmodel: SwarmInfoViewModel
    @SwiftUI.State private var ignoreSwarm = true
    @SwiftUI.State private var shouldShowColorPannel = false
    var id: String!
    var swarmType: String!

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                //                                HStack {
                //                                    Toggle(L10n.Swarm.ignoreSwarm, isOn: $ignoreSwarm)
                //                                        .onChange(of: ignoreSwarm, perform: { value in
                //                                            print("Value has changed : \(value)")
                //                                            viewmodel.IgnoreSwarm(isOn: value)
                //                                        })
                //                                }
                //
                //                                Button(action: {
                //                                    viewmodel.leaveSwarm()
                //                                }, label: {
                //                                    HStack {
                //                                        Text(L10n.Swarm.leaveConversation)
                //                                            .multilineTextAlignment(.leading)
                //                                        Spacer()
                //                                    }
                //                                })

                //                ColorPicker(L10n.Swarm.chooseColor, selection: $swarmColor)

                ColorPicker(L10n.Swarm.chooseColor, selection: $viewmodel.finalColor)
                    .onChange(of: viewmodel.finalColor) { newValue in
                        viewmodel.updateSwarmColor(pickerColor: newValue)
                    }
                HStack {
                    Text(L10n.Swarm.typeOfSwarm)
                    Spacer()
                    Text(swarmType)
                }

                HStack {
                    Text(L10n.Swarm.identifier)
                        .padding(.trailing, 30)
                    Spacer()
                    Text(id)
                        .multilineTextAlignment(.trailing)
                        .truncationMode(.tail)
                        .lineLimit(1)
                }

            }
            .padding(.horizontal, 20)
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    func toHex() -> String? {
        // color to hex
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        var alpha = Float(1.0)

        if components.count >= 4 {
            alpha = Float(components[3])
        }

        if alpha != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255), lroundf(alpha * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
        }
    }
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor
        guard let originalCGColor = originalCGColor else { return nil }

        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}
