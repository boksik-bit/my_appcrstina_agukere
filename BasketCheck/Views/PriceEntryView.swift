import SwiftUI

struct PriceEntryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var prices: [UUID: String] = [:]
    @State private var entryDate = Date()
    @State private var showSavedAlert = false
    @State private var searchText = ""

    private var filteredProducts: [ProductItem] {
        if searchText.isEmpty { return store.products }
        return store.products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Price per unit", systemImage: "info.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.chartAccent)
                    Text("Enter the current price for one unit of each product (e.g. $3.50 for one loaf of bread, not the total you spent). Each Save adds a new record for the selected date — change the date above to log a different day or month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                DatePicker("Record date", selection: $entryDate, displayedComponents: .date)
            } header: {
                Text("When did you see these prices?")
            } footer: {
                Text("Use different dates to build history. CPI needs records in at least 2 different months.")
                    .font(.caption2)
            }

            Section {
                ForEach(filteredProducts) { product in
                    PriceInputRow(
                        product: product,
                        priceText: binding(for: product.id),
                        lastPrice: store.latestPrice(for: product.id),
                        currencySymbol: store.currencySymbol
                    )
                }
            } header: {
                Text("Prices")
            } footer: {
                Text("Leave blank to skip. Each Save creates new records — previous entries are kept.")
                    .font(.caption2)
            }

            Section {
                DisclaimerFooter()
            }
        }
        .searchable(text: $searchText, prompt: "Search products")
        .navigationTitle("Log Prices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { savePrices() }
                    .fontWeight(.semibold)
                    .disabled(validEntries.isEmpty)
            }
        }
        .alert("Prices Saved", isPresented: $showSavedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(validEntries.count) price(s) recorded for \(entryDate.formatted(date: .abbreviated, time: .omitted)). Your records are kept — you can add more dates anytime.")
        }
    }

    private var validEntries: [(productId: UUID, price: Double)] {
        prices.compactMap { (id, text) in
            guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
                  value > 0 else { return nil }
            return (productId: id, price: value)
        }
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { prices[id] ?? "" },
            set: { prices[id] = $0 }
        )
    }

    private func savePrices() {
        store.logPrices(validEntries, date: entryDate)
        showSavedAlert = true
    }
}

// MARK: - Price Input Row

private struct PriceInputRow: View {
    let product: ProductItem
    @Binding var priceText: String
    let lastPrice: Double?
    let currencySymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 4) {
                        Text(product.category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                        Text("per \(product.unit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(currencySymbol)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let lastPrice {
                Text("Latest: \(currencySymbol)\(String(format: "%.2f", lastPrice))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PriceEntryView()
            .environment(DataStore(persistence: .preview))
    }
}
