import Foundation

/// A short, scripted bit of acting.
public enum Reaction: String, Sendable, CaseIterable {
    case flinch, jump, catchCopy, stretch, shakeHead, alienWiggle, wake

    public var duration: TimeInterval {
        switch self {
        case .flinch: 0.4
        case .jump: 1.0
        case .catchCopy: 0.8
        case .stretch: 1.2
        case .shakeHead: 1.2
        case .alienWiggle: 0.8
        case .wake: 0.6
        }
    }
}
