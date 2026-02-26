import SwiftUI

// MARK: - Design System

enum AppTheme {
    static let priceIncrease = Color(red: 1.0, green: 0.322, blue: 0.322)
    static let priceDecrease = Color(red: 0.0, green: 0.902, blue: 0.463)
    static let chartAccent = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let referenceLine = Color.orange

    static let lightBackground = Color(red: 0.973, green: 0.976, blue: 0.98)
    static let darkBackground = Color(red: 0.071, green: 0.071, blue: 0.071)

    static let cornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 28
    static let cardPadding: CGFloat = 16

    static let chartDrawDuration: Double = 1.5
    static let counterDuration: Double = 1.2
    static let walletShrinkDuration: Double = 2.0

    static let disclaimer = "This is a private personal inflation tracking tool for awareness and budgeting. Not official statistics or financial advice."
}

// MARK: - Card Modifier

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 10, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Price Change Label

struct PriceChangeLabel: View {
    let percent: Double
    let amount: Double?
    let currencySymbol: String

    init(percent: Double, amount: Double? = nil, currencySymbol: String = "$") {
        self.percent = percent
        self.amount = amount
        self.currencySymbol = currencySymbol
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: percent >= 0 ? "arrow.up.right" : "arrow.down.right")
            if let amount {
                Text(String(format: "%@%.2f (%.1f%%)",
                            percent >= 0 ? "+" : "",
                            amount, abs(percent)))
            } else {
                Text(String(format: "%@%.1f%%", percent >= 0 ? "+" : "", percent))
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(percent >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
    }
}

// MARK: - Disclaimer Footer

struct DisclaimerFooter: View {
    var body: some View {
        Text(AppTheme.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
    }
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Double
    let format: String
    let prefix: String

    init(value: Double, format: String = "%.2f", prefix: String = "") {
        self.value = value
        self.format = format
        self.prefix = prefix
    }

    var body: some View {
        Text("\(prefix)\(String(format: format, value))")
            .contentTransition(.numericText(value: value))
            .animation(.easeInOut(duration: AppTheme.counterDuration), value: value)
    }
}

// MARK: - Melting Bills Animation

struct MeltingBillsView: View {
    let intensity: Double

    @State private var offsets: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var opacities: [Double] = Array(repeating: 1, count: 5)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Text("💵")
                    .font(.title)
                    .offset(y: offsets[i])
                    .opacity(opacities[i])
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: intensity) { _, _ in startAnimation() }
    }

    private func startAnimation() {
        let clampedIntensity = min(max(intensity, 0), 100)
        for i in 0..<5 {
            let delay = Double(i) * 0.15
            withAnimation(.easeIn(duration: 1.5).delay(delay)) {
                offsets[i] = CGFloat(clampedIntensity) * 0.5
                opacities[i] = max(1.0 - clampedIntensity / 120.0, 0.3)
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.chartAccent)
            Text(title)
                .font(.headline)
        }
    }
}
