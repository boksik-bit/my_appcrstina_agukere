import SwiftUI

struct CurrentBasketView: View {
    @Environment(DataStore.self) private var store
    @State private var showPriceEntry = false
    @State private var animateValue = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    basketCostCard
                    quickStatsGrid
                    if let yoy = store.yearOverYearData {
                        yearOverYearCard(yoy)
                    }
                    if store.budget > 0, let pct = store.basketAsBudgetPercent {
                        budgetCard(percent: pct)
                    }
                    if !store.priceAnomalies.isEmpty {
                        topAnomalyCard
                    }
                    DisclaimerFooter()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Basket")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPriceEntry = true
                    } label: {
                        Label("Log Prices", systemImage: "plus.circle.fill")
                    }
                    .disabled(store.products.isEmpty)
                }
            }
            .sheet(isPresented: $showPriceEntry) {
                NavigationStack {
                    PriceEntryView()
                        .environment(store)
                }
            }
            .onAppear { animateValue = true }
        }
    }

    // MARK: - Basket Cost Card

    private var basketCostCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.chartAccent)
                Text("Current Basket")
                    .font(.headline)
                Spacer()
            }

            AnimatedCounter(
                value: store.currentBasketCost,
                format: "%.2f",
                prefix: store.currencySymbol
            )
            .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("Sum of latest price per product")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.previousMonthBasketCost > 0 {
                HStack(spacing: 8) {
                    PriceChangeLabel(
                        percent: store.basketChangePercent,
                        amount: store.basketChangeAmount,
                        currencySymbol: store.currencySymbol
                    )
                    Text("vs last month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.basketChangePercent > 0 {
                MeltingBillsView(intensity: min(store.basketChangePercent * 5, 100))
                    .padding(.top, 4)
            }

            Button {
                showPriceEntry = true
            } label: {
                Label("Log Prices Today", systemImage: "pencil.line")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.chartAccent)
            .disabled(store.products.isEmpty)
        }
        .cardStyle()
    }

    // MARK: - Quick Stats

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Products",
                value: "\(store.products.count)",
                icon: "list.bullet",
                color: AppTheme.chartAccent
            )
            StatCard(
                title: "Records",
                value: "\(store.priceRecords.count)",
                icon: "doc.text",
                color: .purple
            )
            StatCard(
                title: "Avg. Inflation",
                value: store.hasMultipleMonthsOfData ? String(format: "%.1f%%", store.averageAnnualInflation) : "—",
                subtitle: store.hasMultipleMonthsOfData ? nil : "Need 2+ months",
                icon: "chart.line.uptrend.xyaxis",
                color: store.hasMultipleMonthsOfData ? (store.averageAnnualInflation >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease) : .secondary
            )
            StatCard(
                title: "Baskets/Salary",
                value: store.salary > 0 && store.currentBasketCost > 0
                    ? String(format: "%.1f", store.salary / store.currentBasketCost)
                    : "—",
                icon: "wallet.bifold",
                color: .orange
            )
        }
    }

    // MARK: - Year over Year

    private func yearOverYearCard(_ yoy: YearOverYearData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text("Year over Year")
                    .font(.headline)
                Spacer()
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(yoy.yearAgoLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(store.currencySymbol)\(String(format: "%.2f", yoy.yearAgoCost))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(store.currencySymbol)\(String(format: "%.2f", yoy.currentCost))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Spacer()
                PriceChangeLabel(percent: yoy.changePercent)
            }
        }
        .cardStyle()
    }

    // MARK: - Budget

    private func budgetCard(percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "banknote")
                    .font(.title2)
                    .foregroundStyle(.mint)
                Text("Budget")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.0f", percent))% of budget")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(percent > 100 ? AppTheme.priceIncrease : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(percent > 100 ? AppTheme.priceIncrease : AppTheme.chartAccent)
                        .frame(width: min(percent / 100.0 * geo.size.width, geo.size.width), height: 8)
                }
            }
            .frame(height: 8)
        }
        .cardStyle()
    }

    // MARK: - Top Anomaly

    private var topAnomalyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Top Price Change", icon: "exclamationmark.triangle.fill")

            if let top = store.priceAnomalies.first {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(top.productName)
                            .font(.subheadline.weight(.medium))
                        Text("\(store.currencySymbol)\(String(format: "%.2f", top.previousPrice)) → \(store.currencySymbol)\(String(format: "%.2f", top.currentPrice))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PriceChangeLabel(percent: top.changePercent)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    CurrentBasketView()
        .environment(DataStore(persistence: .preview))
}
