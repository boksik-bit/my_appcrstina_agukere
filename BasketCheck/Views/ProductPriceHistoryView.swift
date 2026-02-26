import SwiftUI
import Charts

struct ProductPriceHistoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let product: ProductItem
    @State private var animateChart = false
    @State private var showEditSheet = false

    private var history: [PriceHistoryPoint] {
        store.priceHistory(for: product.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    productHeader
                    if history.count >= 2 {
                        priceChart
                        historyList
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditProductSheet(product: product)
                    .environment(store)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                    animateChart = true
                }
            }
        }
    }

    private var productHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.chartAccent.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundStyle(AppTheme.chartAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.title3.weight(.semibold))
                Text("\(product.category) · per \(product.unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let last = history.last {
                    Text("\(store.currencySymbol)\(String(format: "%.2f", last.price))")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.chartAccent)
                }
            }
            Spacer()
        }
        .cardStyle()
    }

    private var priceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Price Over Time", icon: "chart.xyaxis.line")

            Chart(history) { point in
                LineMark(
                    x: .value("Month", point.date),
                    y: .value("Price", animateChart ? point.price : (history.first?.price ?? 0))
                )
                .foregroundStyle(AppTheme.chartAccent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(24)

                AreaMark(
                    x: .value("Month", point.date),
                    y: .value("Price", animateChart ? point.price : (history.first?.price ?? 0))
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [AppTheme.chartAccent.opacity(0.3), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel(store.currencySymbol)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
        .cardStyle()
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "All Records", icon: "list.number")

            ForEach(history.reversed()) { point in
                HStack {
                    Text(point.monthLabel)
                        .font(.subheadline)
                        .frame(width: 70, alignment: .leading)
                    Spacer()
                    Text("\(store.currencySymbol)\(String(format: "%.2f", point.price))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.chartAccent)
                }
                .padding(.vertical, 6)
            }
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("Not Enough Data")
                .font(.headline)
            Text("Log prices for at least 2 different dates to see the price history chart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(32)
    }
}

#Preview {
    ProductPriceHistoryView(product: ProductItem(name: "Milk", category: "Dairy", unit: "gallon"))
        .environment(DataStore(persistence: .preview))
}
