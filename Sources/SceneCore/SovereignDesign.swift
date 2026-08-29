import AppKit
import SwiftUI

public enum SovereignDesign {
    public static let ink = Color(nsColor: NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.10, alpha: 1))
    public static let secondaryInk = Color(nsColor: NSColor(calibratedRed: 0.37, green: 0.34, blue: 0.29, alpha: 1))
    public static let paper = Color(nsColor: NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.87, alpha: 1))
    public static let panel = Color(nsColor: NSColor(calibratedRed: 0.985, green: 0.975, blue: 0.94, alpha: 1))
    public static let night = Color(nsColor: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.13, alpha: 1))
    public static let sage = Color(nsColor: NSColor(calibratedRed: 0.28, green: 0.39, blue: 0.34, alpha: 1))
    public static let rust = Color(nsColor: NSColor(calibratedRed: 0.64, green: 0.29, blue: 0.20, alpha: 1))
    public static let hairline = Color.black.opacity(0.10)
}

public struct SovereignKeyHint: View {
    private let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(SovereignDesign.secondaryInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
