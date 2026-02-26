import Foundation
import CoreData
import Observation

@Observable
final class DataStore {
    var products: [ProductItem] = []
    var priceRecords: [PriceEntry] = []
    var currency: String = "USD"
    var salary: Double = 0
    var budget: Double = 0
    var reminderDay: Int = 1
    var reminderEnabled: Bool = false
    var hasCompletedOnboarding: Bool = false

    private let persistence: PersistenceController
    private var settingsObjectID: NSManagedObjectID?

    var currencySymbol: String {
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥",
            "RUB": "₽", "CAD": "C$", "AUD": "A$", "CHF": "Fr",
            "CNY": "¥", "INR": "₹", "BRL": "R$", "KRW": "₩"
        ]
        return symbols[currency] ?? currency
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        loadAll()
    }

    func loadAll() {
        loadProducts()
        loadPriceRecords()
        loadSettings()
    }

    // MARK: - Products

    func loadProducts() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Product")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let results = try persistence.viewContext.fetch(request)
            products = results.map { obj in
                ProductItem(
                    id: obj.value(forKey: "id") as? UUID ?? UUID(),
                    name: obj.value(forKey: "name") as? String ?? "",
                    category: obj.value(forKey: "category") as? String ?? "General",
                    unit: obj.value(forKey: "unit") as? String ?? "piece",
                    photoData: obj.value(forKey: "photoData") as? Data,
                    createdAt: obj.value(forKey: "createdAt") as? Date ?? Date()
                )
            }
        } catch {
            print("Fetch products error: \(error)")
        }
    }

    @discardableResult
    func addProduct(name: String, category: String, unit: String, photoData: Data? = nil) -> UUID {
        let ctx = persistence.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "Product", in: ctx)!
        let obj = NSManagedObject(entity: entity, insertInto: ctx)
        let id = UUID()
        obj.setValue(id, forKey: "id")
        obj.setValue(name, forKey: "name")
        obj.setValue(category.isEmpty ? "General" : category, forKey: "category")
        obj.setValue(unit, forKey: "unit")
        obj.setValue(photoData, forKey: "photoData")
        obj.setValue(Date(), forKey: "createdAt")
        persistence.save()
        loadProducts()
        return id
    }

    func updateProduct(_ item: ProductItem, name: String, category: String, unit: String) {
        guard let obj = fetchObject("Product", id: item.id) else { return }
        obj.setValue(name, forKey: "name")
        obj.setValue(category, forKey: "category")
        obj.setValue(unit, forKey: "unit")
        persistence.save()
        loadProducts()
    }

    func deleteProduct(_ item: ProductItem) {
        guard let obj = fetchObject("Product", id: item.id) else { return }
        persistence.viewContext.delete(obj)
        persistence.save()
        loadProducts()
        loadPriceRecords()
    }

    // MARK: - Price Records

    func loadPriceRecords() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PriceRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["product"]
        do {
            let results = try persistence.viewContext.fetch(request)
            priceRecords = results.compactMap { obj in
                guard let product = obj.value(forKey: "product") as? NSManagedObject else { return nil }
                return PriceEntry(
                    id: obj.value(forKey: "id") as? UUID ?? UUID(),
                    productId: product.value(forKey: "id") as? UUID ?? UUID(),
                    productName: product.value(forKey: "name") as? String ?? "",
                    date: obj.value(forKey: "date") as? Date ?? Date(),
                    price: obj.value(forKey: "price") as? Double ?? 0
                )
            }
        } catch {
            print("Fetch records error: \(error)")
        }
    }

    func logPrice(productId: UUID, price: Double, date: Date = Date()) {
        let ctx = persistence.viewContext
        guard let productObj = fetchObject("Product", id: productId) else { return }
        let entity = NSEntityDescription.entity(forEntityName: "PriceRecord", in: ctx)!
        let record = NSManagedObject(entity: entity, insertInto: ctx)
        record.setValue(UUID(), forKey: "id")
        record.setValue(date, forKey: "date")
        record.setValue(price, forKey: "price")
        record.setValue(productObj, forKey: "product")
        persistence.save()
        loadPriceRecords()
    }

    func logPrices(_ entries: [(productId: UUID, price: Double)], date: Date = Date()) {
        let ctx = persistence.viewContext
        for entry in entries {
            guard entry.price > 0,
                  let productObj = fetchObject("Product", id: entry.productId) else { continue }
            let entity = NSEntityDescription.entity(forEntityName: "PriceRecord", in: ctx)!
            let record = NSManagedObject(entity: entity, insertInto: ctx)
            record.setValue(UUID(), forKey: "id")
            record.setValue(date, forKey: "date")
            record.setValue(entry.price, forKey: "price")
            record.setValue(productObj, forKey: "product")
        }
        persistence.save()
        loadPriceRecords()
    }

    /// Copies current (latest) prices to the 1st of last month. Use when you only have this month's data
    /// and want to see CPI — it creates a baseline so you get 0% change for now, but the chart appears.
    func copyCurrentPricesToLastMonth() {
        let calendar = Calendar.current
        guard let lastMonthFirst = calendar.date(byAdding: .month, value: -1, to: Date()).flatMap({ calendar.startOfMonth(for: $0) }) else { return }

        var entries: [(productId: UUID, price: Double)] = []
        for product in products {
            if let price = latestPrice(for: product.id), price > 0 {
                entries.append((productId: product.id, price: price))
            }
        }
        guard !entries.isEmpty else { return }
        logPrices(entries, date: lastMonthFirst)
    }

    var hasMultipleMonthsOfData: Bool {
        let calendar = Calendar.current
        let months = Set(priceRecords.map { calendar.component(.month, from: $0.date) * 1000 + calendar.component(.year, from: $0.date) })
        return months.count >= 2
    }

    // MARK: - Settings

    func loadSettings() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "UserSettings")
        request.fetchLimit = 1
        do {
            if let s = try persistence.viewContext.fetch(request).first {
                settingsObjectID = s.objectID
                currency = s.value(forKey: "currency") as? String ?? "USD"
                salary = s.value(forKey: "salary") as? Double ?? 0
                budget = s.value(forKey: "budget") as? Double ?? 0
                reminderDay = Int(s.value(forKey: "reminderDay") as? Int16 ?? 1)
                reminderEnabled = s.value(forKey: "reminderEnabled") as? Bool ?? false
            } else {
                createDefaultSettings()
            }
        } catch {
            print("Fetch settings error: \(error)")
        }
    }

    private func createDefaultSettings() {
        let ctx = persistence.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "UserSettings", in: ctx)!
        let s = NSManagedObject(entity: entity, insertInto: ctx)
        s.setValue(UUID(), forKey: "id")
        s.setValue("USD", forKey: "currency")
        s.setValue(0.0, forKey: "salary")
        s.setValue(0.0, forKey: "budget")
        s.setValue(Int16(1), forKey: "reminderDay")
        s.setValue(false, forKey: "reminderEnabled")
        persistence.save()
        settingsObjectID = s.objectID
    }

    func updateCurrency(_ value: String) {
        currency = value
        saveSettings()
    }

    func updateSalary(_ value: Double) {
        salary = value
        saveSettings()
    }

    func updateBudget(_ value: Double) {
        budget = value
        saveSettings()
    }

    func updateReminder(day: Int, enabled: Bool) {
        reminderDay = day
        reminderEnabled = enabled
        saveSettings()
    }

    private func saveSettings() {
        guard let oid = settingsObjectID else { return }
        let s = persistence.viewContext.object(with: oid)
        s.setValue(currency, forKey: "currency")
        s.setValue(salary, forKey: "salary")
        s.setValue(budget, forKey: "budget")
        s.setValue(Int16(reminderDay), forKey: "reminderDay")
        s.setValue(reminderEnabled, forKey: "reminderEnabled")
        persistence.save()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func hasProduct(named name: String) -> Bool {
        products.contains { $0.name.lowercased() == name.lowercased() }
    }

    func loadSampleData() {
        let calendar = Calendar.current
        let now = Date()

        let samples: [(String, String, String, Double)] = [
            ("White Bread", "Bakery", "loaf", 3.49),
            ("Whole Milk", "Dairy", "gallon", 4.29),
            ("Gasoline", "Transport", "gallon", 3.59),
            ("Rice", "Groceries", "kg", 2.99),
            ("Eggs", "Dairy", "dozen", 3.89),
            ("Ground Coffee", "Beverages", "pack", 9.99)
        ]

        var ids: [UUID] = []
        for (name, cat, unit, _) in samples {
            if !hasProduct(named: name) {
                ids.append(addProduct(name: name, category: cat, unit: unit))
            }
        }

        guard !ids.isEmpty else { return }

        let ctx = persistence.viewContext
        for monthOffset in stride(from: -6, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }
            for (i, productId) in ids.enumerated() {
                guard let productObj = fetchObject("Product", id: productId) else { continue }
                let basePrice = samples[i].3
                let growth = 1.0 + Double(monthOffset + 6) * Double.random(in: 0.008...0.022)
                let price = (basePrice * growth * 100).rounded() / 100

                let entity = NSEntityDescription.entity(forEntityName: "PriceRecord", in: ctx)!
                let record = NSManagedObject(entity: entity, insertInto: ctx)
                record.setValue(UUID(), forKey: "id")
                record.setValue(date, forKey: "date")
                record.setValue(price, forKey: "price")
                record.setValue(productObj, forKey: "product")
            }
        }
        persistence.save()

        updateSalary(5000)
        loadProducts()
        loadPriceRecords()
    }

    func resetAllData() {
        for name in ["PriceRecord", "Product", "UserSettings"] {
            let req = NSFetchRequest<NSManagedObject>(entityName: name)
            if let objs = try? persistence.viewContext.fetch(req) {
                objs.forEach { persistence.viewContext.delete($0) }
            }
        }
        persistence.save()

        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        products = []
        priceRecords = []
        currency = "USD"
        salary = 0
        budget = 0
        settingsObjectID = nil
        createDefaultSettings()
    }

    // MARK: - Computed

    var currentBasketCost: Double {
        InflationEngine.currentBasketCost(products: products, records: priceRecords)
    }

    var previousMonthBasketCost: Double {
        InflationEngine.previousMonthBasketCost(products: products, records: priceRecords)
    }

    var basketChangePercent: Double {
        guard previousMonthBasketCost > 0 else { return 0 }
        return ((currentBasketCost - previousMonthBasketCost) / previousMonthBasketCost) * 100
    }

    var basketChangeAmount: Double {
        currentBasketCost - previousMonthBasketCost
    }

    var monthlyCPIData: [CPIDataPoint] {
        InflationEngine.monthlyCPI(products: products, records: priceRecords)
    }

    var averageAnnualInflation: Double {
        InflationEngine.averageAnnualInflation(cpiData: monthlyCPIData)
    }

    var purchasingPowerData: [PurchasingPowerPoint] {
        guard salary > 0 else { return [] }
        return InflationEngine.purchasingPowerHistory(
            salary: salary, products: products, records: priceRecords
        )
    }

    var priceAnomalies: [PriceAnomaly] {
        InflationEngine.detectAnomalies(products: products, records: priceRecords)
    }

    var categories: [String] {
        Array(Set(products.compactMap { $0.category.isEmpty ? nil : $0.category })).sorted()
    }

    func latestPrice(for productId: UUID) -> Double? {
        priceRecords.first(where: { $0.productId == productId })?.price
    }

    func priceHistory(for productId: UUID) -> [PriceHistoryPoint] {
        InflationEngine.priceHistory(for: productId, records: priceRecords)
    }

    var categoryInflation: [CategoryInflationItem] {
        InflationEngine.categoryInflation(products: products, records: priceRecords)
    }

    var yearOverYearData: YearOverYearData? {
        InflationEngine.yearOverYear(products: products, records: priceRecords)
    }

    var basketAsBudgetPercent: Double? {
        guard budget > 0, currentBasketCost > 0 else { return nil }
        return (currentBasketCost / budget) * 100
    }

    // MARK: - CSV Export/Import

    func exportToCSV() -> String {
        var lines: [String] = ["product_id,name,category,unit,date,price"]
        for record in priceRecords.sorted(by: { $0.date < $1.date }) {
            guard let product = products.first(where: { $0.id == record.productId }) else { continue }
            let escaped = { (s: String) in s.replacingOccurrences(of: "\"", with: "\"\"") }
            lines.append("\(record.productId.uuidString),\"\(escaped(product.name))\",\"\(escaped(product.category))\",\"\(product.unit)\",\(record.date.timeIntervalSince1970),\(record.price)")
        }
        return lines.joined(separator: "\n")
    }

    func importFromCSV(_ content: String) -> (imported: Int, errors: [String]) {
        var imported = 0
        var errors: [String] = []
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return (0, ["Empty or invalid file"]) }

        var productIdByName: [String: UUID] = [:]
        for product in products {
            productIdByName[product.name.lowercased()] = product.id
        }

        for (idx, line) in lines.dropFirst().enumerated() {
            let row = parseCSVLine(line)
            guard row.count >= 6 else {
                errors.append("Row \(idx + 2): expected 6 columns")
                continue
            }
            let name = row[1].trimmingCharacters(in: .whitespaces)
            let category = row[2].trimmingCharacters(in: .whitespaces)
            let unit = row[3].trimmingCharacters(in: .whitespaces)
            guard let timestamp = Double(row[4]),
                  let price = Double(row[5]), price > 0 else {
                errors.append("Row \(idx + 2): invalid date or price")
                continue
            }
            let date = Date(timeIntervalSince1970: timestamp)
            let productId: UUID
            if let existing = productIdByName[name.lowercased()] {
                productId = existing
            } else {
                productId = addProduct(name: name, category: category.isEmpty ? "General" : category, unit: unit.isEmpty ? "piece" : unit)
                productIdByName[name.lowercased()] = productId
            }
            logPrice(productId: productId, price: price, date: date)
            imported += 1
        }
        return (imported, errors)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if (char == "," && !inQuotes) {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    // MARK: - Private

    private func fetchObject(_ entity: String, id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? persistence.viewContext.fetch(request).first
    }
}
