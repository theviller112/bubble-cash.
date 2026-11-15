import SwiftUI
import UIKit

@main
struct BubbleCashApp: App {
    @StateObject private var wallet = Wallet()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(wallet)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let bg = Color.black
    static let group = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let raised = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let muted = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let accent = Color(red: 0.39, green: 0.82, blue: 1.0)
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let bubble: [Color] = [
        Color(red: 1.00, green: 0.62, blue: 0.86),
        Color(red: 0.66, green: 0.62, blue: 1.00),
        Color(red: 0.45, green: 0.93, blue: 0.98)
    ]
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.85)
}

// MARK: - Formatting helpers

func fmt(_ n: Int) -> String { n.formatted(.number) }

func amountValue(_ s: String) -> Int { Int(s.filter(\.isNumber)) ?? 0 }

/// Keeps only digits and re-inserts commas: "80000" -> "80,000"
func commaFormat(_ s: String) -> String {
    var digits = s.filter(\.isNumber)
    while digits.hasPrefix("0") { digits.removeFirst() }
    digits = String(digits.prefix(9))
    guard let n = Int(digits) else { return "" }
    return fmt(n)
}

/// "5551234567" -> "(555) 123-4567"
func phoneFormat(_ s: String) -> String {
    let d = Array(s.filter(\.isNumber).prefix(10)).map(String.init)
    if d.count > 6 { return "(\(d[0..<3].joined())) \(d[3..<6].joined())-\(d[6...].joined())" }
    if d.count > 3 { return "(\(d[0..<3].joined())) \(d[3...].joined())" }
    if !d.isEmpty { return "(\(d.joined())" }
    return ""
}

func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
}

/// The little bubble symbol used in front of amounts
struct BubbleSymbol: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().stroke(lineWidth: size * 0.12)
            Circle().frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.27, y: size * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Amount text field that adds commas as you type
struct AmountField: View {
    var placeholder = "0"
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .onChange(of: text) { _, new in
                let f = commaFormat(new)
                if f != new { text = f }
            }
    }
}

struct PhoneField: View {
    @Binding var text: String
    var body: some View {
        TextField("(555) 123-4567", text: $text)
            .keyboardType(.phonePad)
            .multilineTextAlignment(.trailing)
            .onChange(of: text) { _, new in
                let f = phoneFormat(new)
                if f != new { text = f }
            }
    }
}
