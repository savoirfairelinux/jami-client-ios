//
//  TestMessageModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class TestMessageModel: ObservableObject {
    @Published var content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
    @Published var image: UIImage?// UIImage(asset: Asset.fallbackAvatar)
    @Published var avatarImage: UIImage? = UIImage(asset: Asset.addAvatar)
    @Published var username = "Eduard"
    @Published var replyTo: TestMessageModel?
    @Published var replied: [TestMessageModel]?
    @Published var receivedDate: Date? = Date()
    var isIncoming = false
    @Published var read: [UIImage]? = [UIImage(asset: Asset.fallbackAvatar)!, UIImage(asset: Asset.fallbackAvatar)!]
    var corners: UIRectCorner = .bottomLeft
    var sequencing: MessageSequencing = .firstOfSequence {
        didSet {
            print("&&&&&&sequencing is set to \(sequencing)")
            switch sequencing {
            case .firstOfSequence:
                if isIncoming {
                    self.corners = [.topLeft, .topRight, .bottomRight]
                } else {
                    self.corners = [.topLeft, .topRight, .bottomLeft]
                }
                // self.content = ""
                self.content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
            case .lastOfSequence:
                if isIncoming {
                    self.corners = [.topRight, .bottomLeft, .bottomRight]
                } else {
                    self.corners = [.topLeft, .bottomLeft, .bottomRight]
                }
                // self.content = ""
                self.content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
            case .middleOfSequence:
                if isIncoming {
                    corners = [.topRight, .bottomRight]
                } else {
                    corners = [.topLeft, .bottomLeft ]
                }
                // content = ""
                content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
            case .singleMessage:
                corners = [.allCorners]
                //  content = ""
                content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
            case .unknown:
                break
            }
        }
    }

    var timeString: String? {
        // get the current time
        let currentDateTime = Date()

        // prepare formatter
        let dateFormatter = DateFormatter()

        if Calendar.current.compare(currentDateTime, to: receivedDate!, toGranularity: .day) == .orderedSame {
            // age: [0, received the previous day[
            dateFormatter.dateFormat = "h:mma"
        } else if Calendar.current.compare(currentDateTime, to: receivedDate!, toGranularity: .weekOfYear) == .orderedSame {
            // age: [received the previous day, received 7 days ago[
            dateFormatter.dateFormat = "E h:mma"
        } else if Calendar.current.compare(currentDateTime, to: receivedDate!, toGranularity: .year) == .orderedSame {
            // age: [received 7 days ago, received the previous year[
            dateFormatter.dateFormat = "MMM d, h:mma"
        } else {
            // age: [received the previous year, inf[
            dateFormatter.dateFormat = "MMM d, yyyy h:mma"
        }

        // generate the string containing the message time
        return dateFormatter.string(from: receivedDate!).uppercased()
    }

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sequencing = .firstOfSequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sequencing = .lastOfSequence
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sequencing = .middleOfSequence
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sequencing = .singleMessage
                        self.isIncoming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.sequencing = .firstOfSequence
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.sequencing = .lastOfSequence
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.sequencing = .middleOfSequence
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.sequencing = .singleMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // let content = "Invitation received"
}
