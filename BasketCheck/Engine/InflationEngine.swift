import Foundation

// MARK: - Data Models

struct CPIDataPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let personalCPI: Double
    let referenceCPI: Double
    let monthLabel: String
}

struct PurchasingPowerPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let basketsAffordable: Double
    let monthLabel: String
}

struct PriceAnomaly: Identifiable, Sendable {
    let id = UUID()
    let productName: String
    let previousPrice: Double
    let currentPrice: Double
    let changePercent: Double
}

struct ForecastPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let projectedCost: Double
    let monthLabel: String
}

struct PriceHistoryPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let price: Double
    let monthLabel: String
}

struct CategoryInflationItem: Identifiable, Sendable {
    let id = UUID()
    let category: String
    let changePercent: Double
    let previousCost: Double
    let currentCost: Double
}

struct YearOverYearData: Sendable {
    let currentCost: Double
    let yearAgoCost: Double
    let changePercent: Double
    let yearAgoLabel: String
}

struct ProductItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: String
    var unit: String
    var photoData: Data?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, category: String = "General",
         unit: String = "piece", photoData: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.unit = unit
        self.photoData = photoData
        self.createdAt = createdAt
    }
}

struct PriceEntry: Identifiable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let date: Date
    let price: Double

    init(id: UUID = UUID(), productId: UUID, productName: String = "",
         date: Date = Date(), price: Double) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.date = date
        self.price = price
    }
}

// MARK: - Inflation Engine

enum InflationEngine {

    static func currentBasketCost(products: [ProductItem], records: [PriceEntry]) -> Double {
        products.reduce(0) { total, product in
            let latest = records
                .filter { $0.productId == product.id }
                .max(by: { $0.date < $1.date })
            return total + (latest?.price ?? 0)
        }
    }

    static func basketCostAt(
        date: Date, products: [ProductItem], records: [PriceEntry]
    ) -> Double {
        products.reduce(0) { total, product in
            let latest = records
                .filter { $0.productId == product.id && $0.date <= date }
                .max(by: { $0.date < $1.date })
            return total + (latest?.price ?? 0)
        }
    }

    static func previousMonthBasketCost(
        products: [ProductItem], records: [PriceEntry]
    ) -> Double {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return basketCostAt(date: cutoff, products: products, records: records)
    }

    // MARK: - Monthly CPI

    static func monthlyCPI(
        products: [ProductItem], records: [PriceEntry]
    ) -> [CPIDataPoint] {
        guard !records.isEmpty else { return [] }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"

        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date else { return [] }

        var months: [Date] = []
        var current = calendar.startOfMonth(for: earliest)
        let now = Date()

        while current <= now {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        guard months.count >= 2 else { return [] }

        let baseEnd = calendar.date(byAdding: .month, value: 1, to: months[0])!
        let baseCost = basketCostAt(date: baseEnd, products: products, records: records)
        guard baseCost > 0 else { return [] }

        var referenceCumulative: Double = 0
        var result: [CPIDataPoint] = []

        for month in months.dropFirst() {
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            let cost = basketCostAt(date: endOfMonth, products: products, records: records)
            guard cost > 0 else { continue }

            let personalCPI = ((cost - baseCost) / baseCost) * 100

            let year = calendar.component(.year, from: month)
            referenceCumulative += OfficialInflationData.monthlyRateForYear(year)

            result.append(CPIDataPoint(
                date: month,
                personalCPI: personalCPI,
                referenceCPI: referenceCumulative,
                monthLabel: formatter.string(from: month)
            ))
        }

        return result
    }

    // MARK: - Average Inflation

    static func averageAnnualInflation(cpiData: [CPIDataPoint]) -> Double {
        guard let last = cpiData.last, !cpiData.isEmpty else { return 0 }
        let months = Double(cpiData.count)
        return (last.personalCPI / months) * 12
    }

    static func estimatedMonthlyGrowthRate(
        products: [ProductItem], records: [PriceEntry]
    ) -> Double {
        let data = monthlyCPI(products: products, records: records)
        guard data.count >= 2 else { return 0 }
        let points = data.enumerated().map {
            (x: Double($0.offset), y: $0.element.personalCPI)
        }
        return linearRegression(points: points).slope
    }

    // MARK: - Forecast

    static func forecast(
        currentCost: Double, monthlyGrowthPercent: Double, months: Int
    ) -> [ForecastPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        let now = Date()
        let rate = monthlyGrowthPercent / 100.0

        return (0...months).compactMap { m in
            guard let date = calendar.date(byAdding: .month, value: m, to: now) else { return nil }
            let cost = currentCost * pow(1 + rate, Double(m))
            return ForecastPoint(
                date: date, projectedCost: cost,
                monthLabel: formatter.string(from: date)
            )
        }
    }

    // MARK: - Purchasing Power

    static func purchasingPowerHistory(
        salary: Double, products: [ProductItem], records: [PriceEntry]
    ) -> [PurchasingPowerPoint] {
        guard salary > 0, !records.isEmpty else { return [] }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"

        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date else { return [] }

        var months: [Date] = []
        var current = calendar.startOfMonth(for: earliest)
        let now = Date()

        while current <= now {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        return months.compactMap { month in
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            let cost = basketCostAt(date: endOfMonth, products: products, records: records)
            guard cost > 0 else { return nil }
            return PurchasingPowerPoint(
                date: month,
                basketsAffordable: salary / cost,
                monthLabel: formatter.string(from: month)
            )
        }
    }

    // MARK: - Anomalies

    static func detectAnomalies(
        products: [ProductItem], records: [PriceEntry]
    ) -> [PriceAnomaly] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }

        return products.compactMap { product in
            let sorted = records
                .filter { $0.productId == product.id }
                .sorted { $0.date < $1.date }

            let recent = sorted.last(where: { $0.date > cutoff })
            let older = sorted.last(where: { $0.date <= cutoff })

            guard let currentPrice = recent?.price,
                  let previousPrice = older?.price,
                  previousPrice > 0 else { return nil }

            let change = ((currentPrice - previousPrice) / previousPrice) * 100

            return PriceAnomaly(
                productName: product.name,
                previousPrice: previousPrice,
                currentPrice: currentPrice,
                changePercent: change
            )
        }
        .sorted { abs($0.changePercent) > abs($1.changePercent) }
    }

    // MARK: - Price History (per product)

    static func priceHistory(
        for productId: UUID, records: [PriceEntry]
    ) -> [PriceHistoryPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"

        return records
            .filter { $0.productId == productId }
            .sorted { $0.date < $1.date }
            .map { PriceHistoryPoint(
                date: $0.date,
                price: $0.price,
                monthLabel: formatter.string(from: $0.date)
            ) }
    }

    // MARK: - Category Inflation

    static func categoryInflation(
        products: [ProductItem], records: [PriceEntry]
    ) -> [CategoryInflationItem] {
        let calendar = Calendar.current
        guard let nowCutoff = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }

        let categories = Set(products.map { $0.category })
        return categories.compactMap { category -> CategoryInflationItem? in
            let catProducts = products.filter { $0.category == category }
            let currentCost = catProducts.reduce(0.0) { sum, p in
                let latest = records.filter { $0.productId == p.id && $0.date > nowCutoff }
                    .max(by: { $0.date < $1.date })
                return sum + (latest?.price ?? 0)
            }
            let previousCost = catProducts.reduce(0.0) { sum, p in
                let latest = records.filter { $0.productId == p.id && $0.date <= nowCutoff }
                    .max(by: { $0.date < $1.date })
                return sum + (latest?.price ?? 0)
            }
            guard previousCost > 0 else { return nil }
            let change = ((currentCost - previousCost) / previousCost) * 100
            return CategoryInflationItem(
                category: category,
                changePercent: change,
                previousCost: previousCost,
                currentCost: currentCost
            )
        }
        .sorted { abs($0.changePercent) > abs($1.changePercent) }
    }

    // MARK: - Year over Year

    static func yearOverYear(
        products: [ProductItem], records: [PriceEntry]
    ) -> YearOverYearData? {
        let calendar = Calendar.current
        let now = Date()
        guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }

        let currentCost = basketCostAt(date: now, products: products, records: records)
        let yearAgoCost = basketCostAt(date: yearAgo, products: products, records: records)
        guard yearAgoCost > 0 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return YearOverYearData(
            currentCost: currentCost,
            yearAgoCost: yearAgoCost,
            changePercent: ((currentCost - yearAgoCost) / yearAgoCost) * 100,
            yearAgoLabel: formatter.string(from: yearAgo)
        )
    }

    // MARK: - Linear Regression

    static func linearRegression(
        points: [(x: Double, y: Double)]
    ) -> (slope: Double, intercept: Double) {
        let n = Double(points.count)
        guard n > 1 else { return (0, points.first?.y ?? 0) }

        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return (0, sumY / n) }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }
}

// MARK: - Calendar Helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
