import SwiftUI
import Charts

struct PersonalCPIView: View {
    @Environment(DataStore.self) private var store
    @State private var animateChart = false
    @State private var selectedPoint: CPIDataPoint?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.monthlyCPIData.isEmpty {
                        emptyState
                    } else {
                        summaryCards
                        cpiChart
                        legendView
                        monthlyBreakdown
                    }
                    DisclaimerFooter()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Personal CPI")
            .onAppear {
                withAnimation(.easeInOut(duration: AppTheme.chartDrawDuration)) {
                    animateChart = true
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryCards: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Your Inflation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let last = store.monthlyCPIData.last {
                    Text(String(format: "%.1f%%", last.personalCPI))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(last.personalCPI >= 0 ? AppTheme.priceIncrease : AppTheme.priceDecrease)
                }
                Text("cumulative")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()

            VStack(spacing: 4) {
                Text("General Avg.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let last = store.monthlyCPIData.last {
                    Text(String(format: "%.1f%%", last.referenceCPI))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.referenceLine)
                }
                Text("cumulative")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()

            VStack(spacing: 4) {
                Text("Annual Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", store.averageAnnualInflation))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.chartAccent)
                Text("estimated")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    // MARK: - Chart

    private var cpiChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Inflation Over Time", icon: "chart.xyaxis.line")

            Chart {
                ForEach(store.monthlyCPIData) { point in
                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Personal CPI", animateChart ? point.personalCPI : 0)
                    )
                    .foregroundStyle(AppTheme.chartAccent)
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(30)

                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Personal CPI", animateChart ? point.personalCPI : 0)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [AppTheme.chartAccent.opacity(0.3), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Official CPI", animateChart ? point.referenceCPI : 0)
                    )
                    .foregroundStyle(AppTheme.referenceLine)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .interpolationMethod(.catmullRom)
                }

                if let selected = selectedPoint {
                    RuleMark(x: .value("Selected", selected.date))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, spacing: 4) {
                            VStack(spacing: 2) {
                                Text(selected.monthLabel)
                                    .font(.caption2.weight(.semibold))
                                Text("You: \(String(format: "%.1f%%", selected.personalCPI))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.chartAccent)
                                Text("Avg: \(String(format: "%.1f%%", selected.referenceCPI))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.referenceLine)
                            }
                            .padding(6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartYAxisLabel("% change")
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geo[plotFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedPoint = store.monthlyCPIData
                                            .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                    }
                                }
                                .onEnded { _ in selectedPoint = nil }
                        )
                }
            }
            .frame(height: 260)
        }
        .cardStyle()
    }

    // MARK: - Legend

    private var legendView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle().fill(AppTheme.chartAccent).frame(width: 10, height: 10)
                    Text("Your Inflation").font(.caption)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(AppTheme.referenceLine, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .frame(width: 20, height: 2)
                    Text("General Avg.").font(.caption)
                }
            }
            Text("General avg. based on approximate annual CPI estimates, not official government data.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Breakdown

    private var monthlyBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Monthly Data", icon: "list.number")

            ForEach(store.monthlyCPIData.suffix(6).reversed()) { point in
                HStack {
                    Text(point.monthLabel)
                        .font(.subheadline)
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    PriceChangeLabel(percent: point.personalCPI)
                    Spacer()
                    Text("Avg: \(String(format: "%.1f%%", point.referenceCPI))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Need 2 Months of Data")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Your CPI compares basket cost across months. Right now you likely have prices for just one month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Two options:")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                        Text("Quick: Use current prices as last month's baseline. You'll see 0% change for now, but the chart will appear.")
                            .font(.caption)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                        Text("Manual: Log Prices → change date to last month → save. Then log this month's prices.")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            if store.currentBasketCost > 0 {
                Button {
                    store.copyCurrentPricesToLastMonth()
                } label: {
                    Label("Add Last Month as Baseline", systemImage: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.chartAccent)
            }

            Button {
                store.loadSampleData()
            } label: {
                Text("Or load sample data with 7 months")
                    .font(.caption)
                    .foregroundStyle(AppTheme.chartAccent)
            }
        }
        .padding(32)
    }
}

#Preview {
    PersonalCPIView()
        .environment(DataStore(persistence: .preview))
}
