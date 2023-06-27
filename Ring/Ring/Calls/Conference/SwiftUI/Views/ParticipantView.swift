//
//  ParticipantView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct DisplayLayerView: UIViewRepresentable {

    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(displayLayer)
        displayLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DisplayLayerView(displayLayer: model.displayLayer)
        }
    }
}
