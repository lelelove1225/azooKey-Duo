import Foundation

/// Resolve the active Duo display, not the keyboard/window width (which changes in Split View).
public enum DuoKeyboardLayout {
    public static func layout(screenSize: CGSize, modelIdentifier: String) -> LanguageLayout? {
        guard modelIdentifier == "iPhone19,4",
              screenSize.width.isFinite, screenSize.height.isFinite,
              screenSize.width > 0, screenSize.height > 0 else {
            return nil
        }
        // Observed on Duo: cover 466×678 pt; inner 669×951 pt.
        // The shorter edge is invariant under rotation and independent of app/window width.
        return min(screenSize.width, screenSize.height) >= 600 ? .qwerty : .flick
    }
}
