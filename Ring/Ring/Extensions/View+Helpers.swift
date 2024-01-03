/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }

    func menuItemStyle() -> some View {
        self
            .frame(width: 22, height: 22)
            .foregroundColor(Color(UIColor.jamiButtonLight))
    }

    func measureSize() -> some View {
        self.modifier(MeasureSizeModifier())
    }

    func shadowForConversation() -> some View {
        self.shadow(color: Color(UIColor.quaternaryLabel), radius: 2, x: 1, y: 2)
    }
}

extension Animation {
    static func dragableCaptureViewAnimation() -> Animation {
        return Animation.interpolatingSpring(stiffness: 100, damping: 20, initialVelocity: 0)
    }
}
