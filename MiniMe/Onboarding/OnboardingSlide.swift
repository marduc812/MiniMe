//
//  OnboardingSlide.swift
//  MiniMe
//

import Foundation

/// One screen of the setup flow.
enum OnboardingSlide: Equatable, Identifiable {
    case welcome
    case tool(Tool)
    case done

    var id: String {
        switch self {
        case .welcome:        return "welcome"
        case .tool(let tool): return "tool.\(tool.rawValue)"
        case .done:           return "done"
        }
    }
}

/// The ordered slides and where the user currently is in them.
///
/// Navigation is kept in a plain value type rather than on `OnboardingManager`
/// so it can be exercised without a window, a permission check or a defaults
/// domain — the manager owns side effects, this owns the sequence.
struct OnboardingDeck {
    let slides: [OnboardingSlide]
    private(set) var index: Int = 0

    /// The full wizard: welcome, every tool in `Tool.allCases` order, then done.
    ///
    /// Built from `Tool.allCases` so a tool added later gets a slide for free,
    /// which is the promise `Tool.swift` already makes about being the single
    /// source of truth.
    init() {
        slides = [.welcome] + Tool.allCases.map(OnboardingSlide.tool) + [.done]
    }

    /// A one-slide deck for the "you revoked a permission" path — the tool's own
    /// slide and nothing else.
    init(singleTool tool: Tool) {
        slides = [.tool(tool)]
    }

    /// False for a single-slide deck, which shows no dots and no Back/Next.
    var isWizard: Bool { slides.count > 1 }

    var current: OnboardingSlide { slides[index] }

    var canGoBack: Bool { index > 0 }

    var isOnLastSlide: Bool { index == slides.count - 1 }

    mutating func advance() {
        guard !isOnLastSlide else { return }
        index += 1
    }

    mutating func goBack() {
        guard canGoBack else { return }
        index -= 1
    }
}
