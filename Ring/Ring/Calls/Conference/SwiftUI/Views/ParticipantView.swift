//
//  ParticipantView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ImageView: UIViewRepresentable {

    var image: UIImage

    func makeUIView(context: Context) -> some UIView {

        let imageView = UIImageView()
        imageView.image = image
        imageView.backgroundColor = .red
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return imageView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let imageView = uiView as? UIImageView {
            imageView.image = image
        }
    }
}

struct ParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Text(model.name)
                .frame(width: 200, height: 20)
                .background(Color.red)
        }
        .background(Color.black)
    }
}
