/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import UIKit

enum PreviewMotion {

    struct Body: Equatable {
        var position: CGPoint
        var velocity: CGVector

        init(position: CGPoint, velocity: CGVector = .zero) {
            self.position = position
            self.velocity = velocity
        }
    }

    struct Spring: Equatable {
        let response: TimeInterval
        let dampingRatio: CGFloat

        var stiffness: CGFloat {
            let frequency = 2 * CGFloat.pi / CGFloat(response)
            return frequency * frequency
        }

        var damping: CGFloat {
            4 * CGFloat.pi * dampingRatio / CGFloat(response)
        }
    }

    struct WallTravel: Equatable {
        let from: UIEdgeInsets
        let destination: UIEdgeInsets
        let duration: TimeInterval
        private(set) var elapsed: TimeInterval

        init(from: UIEdgeInsets, destination: UIEdgeInsets, duration: TimeInterval) {
            self.from = from
            self.destination = destination
            self.duration = duration
            self.elapsed = 0
        }

        static func settled(_ insets: UIEdgeInsets) -> WallTravel {
            return WallTravel(from: insets, destination: insets, duration: 0)
        }

        var isFinished: Bool { elapsed >= duration }

        var progress: CGFloat {
            guard duration > 0, elapsed < duration else { return 1 }
            return easeInOut(CGFloat(elapsed / duration))
        }

        var chromePresence: CGFloat {
            let start: CGFloat = from.top + from.bottom > 0 ? 1 : 0
            let end: CGFloat = destination.top + destination.bottom > 0 ? 1 : 0
            return start + (end - start) * progress
        }

        var current: UIEdgeInsets {
            guard duration > 0, elapsed < duration else { return destination }
            let progress = self.progress
            return UIEdgeInsets(
                top: from.top + (destination.top - from.top) * progress,
                left: from.left + (destination.left - from.left) * progress,
                bottom: from.bottom + (destination.bottom - from.bottom) * progress,
                right: from.right + (destination.right - from.right) * progress)
        }

        mutating func advance(by interval: TimeInterval) {
            elapsed = min(duration, elapsed + max(0, interval))
        }
    }

    static let push = Spring(response: 0.42, dampingRatio: 0.72)
    static let settle = Spring(response: 0.5, dampingRatio: 1)
    static let fling = Spring(response: 0.45, dampingRatio: 0.76)

    static let restitution: CGFloat = 0.2
    static let restDistance: CGFloat = 0.5
    static let restSpeed: CGFloat = 4
    static let maximumIntegrationStep: CGFloat = 1.0 / 120.0

    static func easeInOut(_ fraction: CGFloat) -> CGFloat {
        let clamped = min(max(0, fraction), 1)
        return clamped < 0.5
            ? 2 * clamped * clamped
            : 1 - pow(-2 * clamped + 2, 2) / 2
    }

    static func step(_ body: Body,
                     toward attractor: CGPoint,
                     within walls: CGRect,
                     spring: Spring,
                     restitution: CGFloat = PreviewMotion.restitution,
                     interval: CGFloat) -> Body {
        var body = body
        var remaining = max(0, interval)
        while remaining > 0 {
            let stepInterval = min(maximumIntegrationStep, remaining)
            remaining -= stepInterval
            integrate(&body, toward: attractor, spring: spring, interval: stepInterval)
            resolveContacts(&body, within: walls, restitution: restitution)
        }
        return body
    }

    static func settled(at attractor: CGPoint, within walls: CGRect) -> Body {
        return Body(position: clamp(attractor, within: walls))
    }

    static func isAtRest(_ body: Body, at attractor: CGPoint) -> Bool {
        return abs(body.position.x - attractor.x) < restDistance
            && abs(body.position.y - attractor.y) < restDistance
            && hypot(body.velocity.dx, body.velocity.dy) < restSpeed
    }

    static func clamp(_ point: CGPoint, within walls: CGRect) -> CGPoint {
        return CGPoint(x: min(max(walls.minX, point.x), walls.maxX),
                       y: min(max(walls.minY, point.y), walls.maxY))
    }

    private static func integrate(_ body: inout Body, toward attractor: CGPoint,
                                  spring: Spring, interval: CGFloat) {
        let accelerationX = -spring.stiffness * (body.position.x - attractor.x)
            - spring.damping * body.velocity.dx
        let accelerationY = -spring.stiffness * (body.position.y - attractor.y)
            - spring.damping * body.velocity.dy
        body.velocity.dx += accelerationX * interval
        body.velocity.dy += accelerationY * interval
        body.position.x += body.velocity.dx * interval
        body.position.y += body.velocity.dy * interval
    }

    private static func resolveContacts(_ body: inout Body, within walls: CGRect,
                                        restitution: CGFloat) {
        if body.position.x < walls.minX {
            body.position.x = walls.minX
            if body.velocity.dx < 0 { body.velocity.dx *= -restitution }
        } else if body.position.x > walls.maxX {
            body.position.x = walls.maxX
            if body.velocity.dx > 0 { body.velocity.dx *= -restitution }
        }
        if body.position.y < walls.minY {
            body.position.y = walls.minY
            if body.velocity.dy < 0 { body.velocity.dy *= -restitution }
        } else if body.position.y > walls.maxY {
            body.position.y = walls.maxY
            if body.velocity.dy > 0 { body.velocity.dy *= -restitution }
        }
    }
}
