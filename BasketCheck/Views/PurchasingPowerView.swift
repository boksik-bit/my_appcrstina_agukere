import SwiftUI
import Charts

struct PurchasingPowerView: View {
    @Environment(DataStore.self) private var store
    @State private var salaryInput = ""
    @State private var animateChart = false
    @State private var walletScale: CGFloat = 1.0

    private var powerData: [PurchasingPowerPoint] {
        store.purchasingPowerData
    }

    private var currentBaskets: Double {
        guard store.salary > 0, store.currentBasketCost > 0 else { return 0 }
        return store.salary / store.currentBasketCost
    }

    private var firstBaskets: Double {
        powerData.first?.basketsAffordable ?? currentBaskets
    }

    private var powerLossPercent: Double {
        guard firstBaskets > 0 else { return 0 }
        return ((currentBaskets - firstBaskets) / firstBaskets) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                salaryCard
                if store.salary > 0 {
                    powerSummaryCard
                    if powerData.count >= 2 {
                        powerChart
                    }
                    walletVisualization
                }
                DisclaimerFooter()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Purchasing Power")
        .onAppear {
            salaryInput = store.salary > 0 ? String(format: "%.0f", store.salary) : ""
            withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                animateChart = true
            }
            animateWallet()
        }
    }

    // MARK: - Salary Card

    private var salaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Monthly Salary", icon: "banknote")

            HStack {
                Text(store.currencySymbol)
                    .foregroundStyle(.secondary)
                    .font(.title3)
                TextField("Enter salary", text: $salaryInput)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.medium).monospacedDigit())
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    if let value = Double(salaryInput.replacingOccurrences(of: ",", with: ".")),
                       value > 0 {
                        store.updateSalary(value)
                        animateWallet()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.chartAccent)
            }
        }
        .cardStyle()
    }

    // MARK: - Power Summary

    private var powerSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "wallet.bifold.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Buying Power")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", currentBaskets))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.chartAccent)
                    Text("baskets now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if firstBaskets != currentBaskets && powerData.count >= 2 {
                    VStack(spacing: 4) {
                        Image(systemName: powerLossPercent < 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.title)
                            .foregroundStyle(powerLossPercent < 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                        PriceChangeLabel(percent: powerLossPercent)
                    }

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", firstBaskets))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("baskets before")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Power Chart

    private var powerChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Power Over Time", icon: "chart.xyaxis.line")

            Chart(powerData) { point in
                LineMark(
                    x: .value("Month", point.date),
                    y: .value("Baskets", animateChart ? point.basketsAffordable : firstBaskets)
                )
                .foregroundStyle(AppTheme.chartAccent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(30)

                AreaMark(
                    x: .value("Month", point.date),
                    y: .value("Baskets", animateChart ? point.basketsAffordable : firstBaskets)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [AppTheme.chartAccent.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel("Baskets Affordable")
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 220)
        }
        .cardStyle()
    }

    // MARK: - Wallet Visualization

    private var walletVisualization: some View {
        VStack(spacing: 12) {
            Text("Your Wallet's Buying Power")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    let fraction = currentBaskets / max(firstBaskets, 1)
                    let shouldShow = Double(i) / 5.0 < fraction
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(shouldShow ? AppTheme.priceDecrease : .gray.opacity(0.3))
                        .scaleEffect(shouldShow ? walletScale : 0.6)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.5)
                                .delay(Double(i) * 0.1),
                            value: walletScale
                        )
                }
            }

            if powerLossPercent < 0 {
                Text("Your buying power decreased by \(String(format: "%.1f%%", abs(powerLossPercent)))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.priceIncrease)
            }
        }
        .cardStyle()
    }

    private func animateWallet() {
        walletScale = 0.5
        withAnimation(.spring(response: 0.8, dampingFraction: 0.4).delay(0.3)) {
            walletScale = 1.0
        }
    }
}

#Preview {
    NavigationStack {
        PurchasingPowerView()
            .environment(DataStore(persistence: .preview))
    }
}
