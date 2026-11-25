import SwiftUI

enum StudioTheme {
    static let background = Color(red: 20/255, green: 21/255, blue: 24/255)
    static let surface = Color(red: 28/255, green: 29/255, blue: 33/255)
    static let elevated = Color(red: 37/255, green: 38/255, blue: 43/255)
    static let border = Color(red: 48/255, green: 49/255, blue: 55/255)
    static let text = Color(red: 245/255, green: 245/255, blue: 247/255)
    static let secondary = Color(red: 163/255, green: 163/255, blue: 172/255)
}
extension Font {
    static func figures(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style).monospacedDigit().weight(weight)
    }
}
struct StudioButton: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StudioTheme.text)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? StudioTheme.elevated : StudioTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.white.opacity(0.65) : Color.clear, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
