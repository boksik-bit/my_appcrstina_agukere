import UIKit

enum PDFGenerator {

    static func generateReport(store: DataStore) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = "Personal Inflation Report"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36

            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))"
            dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
            y += 24

            // Disclaimer
            let disclaimerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 9),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let disclaimerRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
            AppTheme.disclaimer.draw(in: disclaimerRect, withAttributes: disclaimerAttrs)
            y += 36

            // Separator
            y = drawSeparator(context: context.cgContext, y: y, margin: margin, width: contentWidth)

            // Summary
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.label
            ]

            "Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 24

            let symbol = store.currencySymbol
            let summaryLines = [
                "Current Basket Cost: \(symbol)\(String(format: "%.2f", store.currentBasketCost))",
                "Previous Month: \(symbol)\(String(format: "%.2f", store.previousMonthBasketCost))",
                "Monthly Change: \(String(format: "%.1f%%", store.basketChangePercent))",
                "Avg. Annual Inflation: \(String(format: "%.1f%%", store.averageAnnualInflation))",
                "Products Tracked: \(store.products.count)",
                "Total Price Records: \(store.priceRecords.count)"
            ]

            for line in summaryLines {
                line.draw(at: CGPoint(x: margin + 12, y: y), withAttributes: bodyAttrs)
                y += 18
            }
            y += 12

            y = drawSeparator(context: context.cgContext, y: y, margin: margin, width: contentWidth)

            // Price Table
            "Price History (Latest)".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 24

            let colHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.label
            ]

            "Product".draw(at: CGPoint(x: margin, y: y), withAttributes: colHeaderAttrs)
            "Unit".draw(at: CGPoint(x: margin + 200, y: y), withAttributes: colHeaderAttrs)
            "Price".draw(at: CGPoint(x: margin + 300, y: y), withAttributes: colHeaderAttrs)
            "Change".draw(at: CGPoint(x: margin + 400, y: y), withAttributes: colHeaderAttrs)
            y += 18

            for product in store.products {
                if y > pageHeight - margin - 60 {
                    context.beginPage()
                    y = margin
                }

                let latest = store.latestPrice(for: product.id)
                let priceStr = latest.map { "\(symbol)\(String(format: "%.2f", $0))" } ?? "—"

                let anomaly = store.priceAnomalies.first(where: { $0.productName == product.name })
                let changeStr = anomaly.map { String(format: "%.1f%%", $0.changePercent) } ?? "—"

                product.name.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                product.unit.draw(at: CGPoint(x: margin + 200, y: y), withAttributes: bodyAttrs)
                priceStr.draw(at: CGPoint(x: margin + 300, y: y), withAttributes: bodyAttrs)
                changeStr.draw(at: CGPoint(x: margin + 400, y: y), withAttributes: bodyAttrs)
                y += 16
            }

            y += 12
            y = drawSeparator(context: context.cgContext, y: y, margin: margin, width: contentWidth)

            // Forecast
            if store.currentBasketCost > 0 {
                if y > pageHeight - margin - 100 {
                    context.beginPage()
                    y = margin
                }

                "12-Month Forecast".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
                y += 24

                let monthlyRate = InflationEngine.estimatedMonthlyGrowthRate(
                    products: store.products, records: store.priceRecords
                )
                let projected = store.currentBasketCost * pow(1 + monthlyRate / 100, 12)
                let diff = projected - store.currentBasketCost

                let forecastLines = [
                    "Current Basket: \(symbol)\(String(format: "%.2f", store.currentBasketCost))",
                    "Projected (12 months): \(symbol)\(String(format: "%.2f", projected))",
                    "Estimated Increase: \(symbol)\(String(format: "%.2f", diff))",
                    "Based on \(String(format: "%.2f%%", monthlyRate)) avg. monthly growth"
                ]

                for line in forecastLines {
                    line.draw(at: CGPoint(x: margin + 12, y: y), withAttributes: bodyAttrs)
                    y += 18
                }
            }

            // Footer disclaimer
            let footerY = pageHeight - margin
            AppTheme.disclaimer.draw(
                in: CGRect(x: margin, y: footerY - 20, width: contentWidth, height: 20),
                withAttributes: disclaimerAttrs
            )
        }
    }

    private static func drawSeparator(
        context: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat
    ) -> CGFloat {
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + width, y: y))
        context.strokePath()
        return y + 16
    }
}
