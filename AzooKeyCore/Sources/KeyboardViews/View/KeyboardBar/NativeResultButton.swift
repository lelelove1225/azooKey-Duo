import SwiftUI
import UIKit

/// The SwiftUI label retains styling, accessibility and its context menu. UIKit
/// handles the tap, including cancellation by the enclosing scroll view/menu.
struct NativeResultButton: UIViewRepresentable {
    var isEnabled: Bool
    var onPressChanged: (Bool) -> Void
    var onActivate: () -> Void

    func makeUIView(context: Context) -> TouchSurface {
        TouchSurface()
    }

    func updateUIView(_ view: TouchSurface, context: Context) {
        view.onActivate = onActivate
        view.onPressChanged = onPressChanged
        view.isEnabled = isEnabled
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TouchSurface, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    static func dismantleUIView(_ view: TouchSurface, coordinator: ()) {
        view.onActivate = nil
        view.onPressChanged = nil
    }

    final class TouchSurface: UIButton {
        var onActivate: (() -> Void)?
        var onPressChanged: ((Bool) -> Void)?

        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
            // SwiftUI exposes the label and button action to VoiceOver.
            isAccessibilityElement = false
            addTarget(self, action: #selector(pressed), for: [.touchDown, .touchDragEnter])
            addTarget(self, action: #selector(released), for: [.touchCancel, .touchUpOutside, .touchDragExit])
            addTarget(self, action: #selector(activate), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() { onPressChanged?(true) }
        @objc private func released() { onPressChanged?(false) }
        @objc private func activate() {
            onPressChanged?(false)
            guard isEnabled else { return }
            onActivate?()
        }
    }
}
