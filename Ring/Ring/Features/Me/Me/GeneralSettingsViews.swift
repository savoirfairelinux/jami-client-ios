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

import SwiftUI

struct FileTransferSettingsView: View {
    @StateObject var model: GeneralSettings

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Automaticly accept incoming files")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.automaticlyDownloadIncomingFiles },
                        set: { newValue in model.enableAutomaticlyDownload(enable: newValue) }
                    ))
                    .labelsHidden()
                }
                HStack {
                    Text("Accept transfer limit") + Text("(in Mb, 0 = unlimited)")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    TextField("", text: $model.downloadLimit, onCommit: {
                        model.saveDownloadLimit()
                    })
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .disabled(!model.automaticlyDownloadIncomingFiles)
                    .foregroundColor(model.automaticlyDownloadIncomingFiles ? .jamiColor : Color(UIColor.secondaryLabel))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("File transfer")
    }
}

struct LocationSharingSettingsView: View {
    @SwiftUI.State private var showingDurationPicker = false
    @StateObject var model: GeneralSettings

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }

    var body: some View {
        ZStack {
            List {
                Section {
                    HStack {
                        Text("Limit the duration of location sharing")
                            .layoutPriority(1)
                        Spacer()
                        Toggle("", isOn: Binding<Any>.customBinding(
                            get: { model.limitLocationSharing },
                            set: { newValue in model.enableLocationSharingLimit(enable: newValue) }
                        ))
                        .labelsHidden()
                    }
                    if model.limitLocationSharing {
                        HStack {
                            Text("Position share duration")
                            Spacer()
                            Text(model.locationSharingDurationString)
                                .onTapGesture {
                                    showingDurationPicker = true
                                }
                        }
                    }

                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Location sharing")
            }
            if showingDurationPicker {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            showingDurationPicker = false
                        }
                    }

                DurationPickerView(duration: $model.locationSharingDuration, isPresented: $showingDurationPicker)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut)
            }
        }
    }
}

struct VideoSettingsView: View {
    @StateObject var model: GeneralSettings

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Enable video acceleration")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.videoAccelerationEnabled },
                        set: { newValue in model.enableVideoAcceleration(enable: newValue) }
                    ))
                    .labelsHidden()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Video")
        }
    }
}
