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
        displayLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        displayLayer.bounds = uiView.frame
    }
}

struct ParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DisplayLayerView(displayLayer: model.displayLayer)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
            Text(model.name)
                .frame(width: 200, height: 20)
                .background(Color.red)
        }.padding()
    }
}
