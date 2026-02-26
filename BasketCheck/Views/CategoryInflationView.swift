import SwiftUI
import Charts

struct CategoryInflationView: View {
    @Environment(DataStore.self) private var store
    @State private var animateChart = false

    private var items: [CategoryInflationItem] {
        store.categoryInflation
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if items.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    categoryChart
                    categoryList
                }
                DisclaimerFooter()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("By Category")
        .onAppear {
            withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                animateChart = true
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Inflation by Category")
                    .font(.headline)
                Spacer()
            }

            Text("See which product categories drive your personal inflation the most")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Change vs Last Month", icon: "chart.bar.fill")

            Chart(items) { item in
                BarMark(
                    x: .value("Category", categoryLabel(item.category)),
                    y: .value("Change %", animateChart ? item.changePercent : 0)
                )
                .foregroundStyle(item.changePercent >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                .cornerRadius(6)
                .annotation(position: item.changePercent >= 0 ? .top : .bottom, spacing: 2) {
                    Text(String(format: "%.1f%%", item.changePercent))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.changePercent >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                }
            }
            .chartYAxisLabel("% change")
            .frame(height: max(CGFloat(items.count) * 36, 180))
        }
        .cardStyle()
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Details", icon: "list.bullet")

            ForEach(items) { item in
                HStack {
                    Text(categoryEmoji(item.category))
                    Text(item.category)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(store.currencySymbol)\(String(format: "%.2f", item.previousCost)) → \(store.currencySymbol)\(String(format: "%.2f", item.currentCost))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    PriceChangeLabel(percent: item.changePercent)
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Need 2 Months of Data")
                .font(.title3.weight(.semibold))
            Text("Log prices for at least 2 different months to see inflation by category.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func categoryLabel(_ cat: String) -> String {
        switch cat {
        case "Groceries": return "Groceries"
        case "Dairy": return "Dairy"
        case "Bakery": return "Bakery"
        case "Meat": return "Meat"
        case "Beverages": return "Beverages"
        case "Personal Care": return "Care"
        case "Transport": return "Transport"
        case "Utilities": return "Utilities"
        default: return cat
        }
    }

    private func categoryEmoji(_ cat: String) -> String {
        switch cat {
        case "Groceries": return "🥬"
        case "Dairy": return "🥛"
        case "Bakery": return "🍞"
        case "Meat": return "🥩"
        case "Beverages": return "☕"
        case "Personal Care": return "🧴"
        case "Transport": return "⛽"
        case "Utilities": return "💡"
        default: return "📦"
        }
    }
}

#Preview {
    NavigationStack {
        CategoryInflationView()
            .environment(DataStore(persistence: .preview))
    }
}
