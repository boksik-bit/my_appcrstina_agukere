import Foundation

enum OfficialInflationData {
    // Approximate average annual CPI rates for educational comparison only.
    // Generalized values not tied to any specific source or country.
    static let annualRates: [Int: Double] = [
        2018: 2.4,
        2019: 1.8,
        2020: 1.2,
        2021: 4.7,
        2022: 8.0,
        2023: 4.1,
        2024: 2.9,
        2025: 2.5,
        2026: 2.3,
        2027: 2.2,
        2028: 2.1,
        2029: 2.0,
        2030: 2.0
    ]

    static func monthlyRateForYear(_ year: Int) -> Double {
        (annualRates[year] ?? 2.5) / 12.0
    }

    static func cumulativeRate(from startDate: Date, to endDate: Date) -> Double {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let startMonth = calendar.component(.month, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        let endMonth = calendar.component(.month, from: endDate)

        var cumulative: Double = 0

        guard startYear <= endYear else { return 0 }

        for year in startYear...endYear {
            let rate = monthlyRateForYear(year)
            let from = (year == startYear) ? startMonth + 1 : 1
            let to = (year == endYear) ? endMonth : 12
            guard from <= to else { continue }
            for _ in from...to {
                cumulative += rate
            }
        }

        return cumulative
    }
}
