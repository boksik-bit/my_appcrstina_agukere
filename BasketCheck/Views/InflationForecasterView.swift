import SwiftUI
import Charts

struct InflationForecasterView: View {
    @Environment(DataStore.self) private var store
    @State private var forecastYears = 1
    @State private var customRate: Double?
    @State private var useCustomRate = false
    @State private var animateChart = false

    private var monthlyRate: Double {
        if useCustomRate, let rate = customRate {
            return rate / 12.0
        }
        return InflationEngine.estimatedMonthlyGrowthRate(
            products: store.products, records: store.priceRecords
        )
    }

    private var forecastData: [ForecastPoint] {
        guard store.currentBasketCost > 0 else { return [] }
        return InflationEngine.forecast(
            currentCost: store.currentBasketCost,
            monthlyGrowthPercent: monthlyRate,
            months: forecastYears * 12
        )
    }

    private var projectedCost: Double {
        forecastData.last?.projectedCost ?? store.currentBasketCost
    }

    private var projectedIncrease: Double {
        projectedCost - store.currentBasketCost
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if store.currentBasketCost > 0 {
                    projectionCard
                    rateSelector
                    if !forecastData.isEmpty {
                        forecastChart
                    }
                    yearSelector
                } else {
                    emptyState
                }
                DisclaimerFooter()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Forecast")
        .onAppear {
            withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                animateChart = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No Data Yet")
                .font(.title3.weight(.semibold))
            Text("Add products and log prices to generate a cost forecast based on your personal spending trends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Projection Card

    private var projectionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "crystal.ball")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("Cost Projection")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(store.currencySymbol)\(String(format: "%.2f", store.currentBasketCost))")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("In \(forecastYears) year\(forecastYears > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(store.currencySymbol)\(String(format: "%.2f", projectedCost))")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.priceIncrease)
                }
            }

            if projectedIncrease > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Your basket will cost \(store.currencySymbol)\(String(format: "%.2f", projectedIncrease)) more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    // MARK: - Rate Selector

    private var rateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $useCustomRate) {
                Text("Use custom inflation rate")
                    .font(.subheadline)
            }

            if useCustomRate {
                HStack {
                    Text("Annual rate:")
                        .font(.subheadline)
                    TextField("e.g. 5.0", value: $customRate, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Estimated from your data:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f%%/month", monthlyRate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.chartAccent)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Forecast Chart

    private var forecastChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Projected Basket Cost", icon: "chart.line.uptrend.xyaxis")

            Chart(forecastData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Cost", animateChart ? point.projectedCost : store.currentBasketCost)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [AppTheme.chartAccent, AppTheme.priceIncrease],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Cost", animateChart ? point.projectedCost : store.currentBasketCost)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [AppTheme.priceIncrease.opacity(0.2), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
            .chartYAxisLabel(store.currencySymbol)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: max(forecastYears * 3, 3))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                }
            }
            .frame(height: 240)
        }
        .cardStyle()
    }

    // MARK: - Year Selector

    private var yearSelector: some View {
        VStack(spacing: 8) {
            Text("Forecast Period")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Period", selection: $forecastYears) {
                Text("1 Year").tag(1)
                Text("3 Years").tag(3)
                Text("5 Years").tag(5)
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        InflationForecasterView()
            .environment(DataStore(persistence: .preview))
    }
}
