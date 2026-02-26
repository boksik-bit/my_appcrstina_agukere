import SwiftUI
import Charts

struct PriceAnomaliesView: View {
    @Environment(DataStore.self) private var store
    @State private var animateChart = false

    private var anomalies: [PriceAnomaly] {
        store.priceAnomalies
    }

    private var risers: [PriceAnomaly] {
        anomalies.filter { $0.changePercent > 0 }
    }

    private var fallers: [PriceAnomaly] {
        anomalies.filter { $0.changePercent < 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if anomalies.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    anomalyChart
                    if !risers.isEmpty { risersList }
                    if !fallers.isEmpty { fallersList }
                }
                DisclaimerFooter()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Price Anomalies")
        .onAppear {
            withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                animateChart = true
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Monthly Price Changes")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(risers.count)")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.priceIncrease)
                    Text("Price Increases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack {
                    Text("\(fallers.count)")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.priceDecrease)
                    Text("Price Drops")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
    }

    // MARK: - Chart

    private var anomalyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Price Change by Product", icon: "chart.bar.fill")

            Chart(anomalies) { item in
                BarMark(
                    x: .value("Product", item.productName),
                    y: .value("Change %", animateChart ? item.changePercent : 0)
                )
                .foregroundStyle(item.changePercent >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                .cornerRadius(6)
                .annotation(position: item.changePercent >= 0 ? .top : .bottom) {
                    Text(String(format: "%.0f%%", item.changePercent))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.changePercent >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                }
            }
            .chartYAxisLabel("% change")
            .frame(height: max(CGFloat(anomalies.count) * 30, 200))
        }
        .cardStyle()
    }

    // MARK: - Risers

    private var risersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Biggest Increases", icon: "arrow.up.right.circle.fill")

            ForEach(risers.prefix(5)) { item in
                AnomalyRow(anomaly: item, currencySymbol: store.currencySymbol)
                if item.id != risers.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Fallers

    private var fallersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Price Drops", icon: "arrow.down.right.circle.fill")

            ForEach(fallers.prefix(5)) { item in
                AnomalyRow(anomaly: item, currencySymbol: store.currencySymbol)
                if item.id != fallers.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No Anomalies Detected")
                .font(.title3.weight(.semibold))
            Text("Log prices for at least 2 months to detect price anomalies and see which products changed the most.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Anomaly Row

private struct AnomalyRow: View {
    let anomaly: PriceAnomaly
    let currencySymbol: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(anomaly.productName)
                    .font(.subheadline.weight(.medium))
                Text("\(currencySymbol)\(String(format: "%.2f", anomaly.previousPrice)) → \(currencySymbol)\(String(format: "%.2f", anomaly.currentPrice))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PriceChangeLabel(percent: anomaly.changePercent)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PriceAnomaliesView()
            .environment(DataStore(persistence: .preview))
    }
}
