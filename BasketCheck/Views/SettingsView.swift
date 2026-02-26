import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @State private var showResetConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var selectedCurrency: String = "USD"
    @State private var budgetInput: String = ""
    @State private var reminderDay: Int = 1
    @State private var reminderEnabled = false
    @State private var showSampleDataLoaded = false
    @State private var showCSVImport = false
    @State private var showImportResult = false
    @State private var importResult: (imported: Int, errors: [String]) = (0, [])
    @State private var importError: Error?

    private let currencies = [
        ("USD", "US Dollar ($)"),
        ("EUR", "Euro (€)"),
        ("GBP", "British Pound (£)"),
        ("JPY", "Japanese Yen (¥)"),
        ("CAD", "Canadian Dollar (C$)"),
        ("AUD", "Australian Dollar (A$)"),
        ("CHF", "Swiss Franc (Fr)"),
        ("CNY", "Chinese Yuan (¥)"),
        ("INR", "Indian Rupee (₹)"),
        ("RUB", "Russian Ruble (₽)"),
        ("BRL", "Brazilian Real (R$)"),
        ("KRW", "Korean Won (₩)")
    ]

    var body: some View {
        Form {
            currencySection
            budgetSection
            reminderSection
            exportSection
            dataSection
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear {
            selectedCurrency = store.currency
            budgetInput = store.budget > 0 ? String(format: "%.0f", store.budget) : ""
            reminderDay = store.reminderDay
            reminderEnabled = store.reminderEnabled
        }
        .confirmationDialog(
            "Reset All Data",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                store.resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all products, price records, and settings. This action cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Sample Data Loaded", isPresented: $showSampleDataLoaded) {
            Button("OK") {}
        } message: {
            Text("6 products with 7 months of price history have been added. Explore all features now!")
        }
        .fileImporter(
            isPresented: $showCSVImport,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text(importMessage)
        }
    }

    private var importMessage: String {
        if importResult.errors.isEmpty {
            return "Successfully imported \(importResult.imported) price record(s)."
        } else {
            return "Imported \(importResult.imported) record(s). \(importResult.errors.count) error(s): \(importResult.errors.prefix(3).joined(separator: "; "))"
        }
    }

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importResult = (0, ["Could not access file"])
                showImportResult = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                importResult = store.importFromCSV(content)
                showImportResult = true
            } catch {
                importResult = (0, [error.localizedDescription])
                showImportResult = true
            }
        case .failure(let error):
            importResult = (0, [error.localizedDescription])
            showImportResult = true
        }
    }

    // MARK: - Currency

    private var currencySection: some View {
        Section {
            Picker("Currency", selection: $selectedCurrency) {
                ForEach(currencies, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .onChange(of: selectedCurrency) { _, newValue in
                store.updateCurrency(newValue)
            }
        } header: {
            Label("Currency", systemImage: "dollarsign.circle")
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        Section {
            HStack {
                Text(store.currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("Monthly budget", text: $budgetInput)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: budgetInput) { _, newValue in
                let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) ?? 0
                store.updateBudget(max(0, value))
            }
        } header: {
            Label("Monthly Budget", systemImage: "banknote")
        } footer: {
            Text("Set your monthly spending budget to see how your basket compares. Shown on the Basket tab.")
        }
    }

    // MARK: - Reminder

    private var reminderSection: some View {
        Section {
            Toggle("Monthly Reminder", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, enabled in
                    if enabled { requestNotificationPermission() }
                    store.updateReminder(day: reminderDay, enabled: enabled)
                    if enabled { scheduleReminder() }
                }

            if reminderEnabled {
                Picker("Day of Month", selection: $reminderDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }
                .onChange(of: reminderDay) { _, day in
                    store.updateReminder(day: day, enabled: reminderEnabled)
                    scheduleReminder()
                }
            }
        } header: {
            Label("Price Check Reminder", systemImage: "bell.badge")
        } footer: {
            Text("Get a monthly reminder to log your prices and keep your inflation data up to date.")
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            Button {
                exportPDF()
            } label: {
                Label("Export PDF Report", systemImage: "doc.richtext")
            }
            .disabled(store.products.isEmpty)

            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "doc.text")
            }
            .disabled(store.products.isEmpty)

            Button {
                showCSVImport = true
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
        } header: {
            Label("Reports & Backup", systemImage: "chart.bar.doc.horizontal")
        } footer: {
            Text("CSV contains all products and price history. Use for backup or to merge data from another device.")
        }
    }

    private func exportCSV() {
        let content = store.exportToCSV()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "BasketCheck_\(formatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            print("CSV export error: \(error)")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            HStack {
                Text("Products")
                Spacer()
                Text("\(store.products.count)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Price Records")
                Spacer()
                Text("\(store.priceRecords.count)")
                    .foregroundStyle(.secondary)
            }

            Button {
                store.loadSampleData()
                showSampleDataLoaded = true
            } label: {
                Label("Load Sample Data", systemImage: "tray.and.arrow.down")
            }
            .disabled(!store.products.isEmpty)

            Button("Reset All Data", role: .destructive) {
                showResetConfirmation = true
            }
        } header: {
            Label("Data", systemImage: "cylinder.split.1x2")
        } footer: {
            if store.products.isEmpty {
                Text("Load sample data to explore all features with pre-filled products and price history.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Privacy")
                Spacer()
                Text("100% Offline")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("About BasketCheck")
                    .font(.subheadline.weight(.medium))
                Text("BasketCheck helps you understand your personal inflation by tracking prices of products you buy regularly. All data stays on your device — nothing is collected or sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Reference Data")
                    .font(.subheadline.weight(.medium))
                Text("The \"General Avg.\" line shown in the CPI chart uses approximate annual inflation estimates for educational comparison only. These are not official government statistics and may differ from actual published CPI data for your country or region.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            DisclaimerFooter()
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - PDF

    private func exportPDF() {
        let data = PDFGenerator.generateReport(store: store)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "BasketCheck_Report_\(formatter.string(from: Date())).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            print("PDF write error: \(error)")
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["monthly-price-check"])

        guard reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Check Prices"
        content.body = "Open BasketCheck and log today's prices to keep your inflation data accurate."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.day = reminderDay
        dateComponents.hour = 10

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly-price-check", content: content, trigger: trigger)
        center.add(request)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(DataStore(persistence: .preview))
    }
}
