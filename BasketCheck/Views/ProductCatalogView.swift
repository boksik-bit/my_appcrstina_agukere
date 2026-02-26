import SwiftUI

struct ProductCatalogView: View {
    @Environment(DataStore.self) private var store
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedProduct: ProductItem?
    @State private var editingProduct: ProductItem?

    private var allCategories: [String] {
        ["All"] + store.categories
    }

    private var filteredProducts: [ProductItem] {
        var result = store.products
        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.products.isEmpty {
                    emptyState
                } else {
                    productList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Products")
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddProductSheet()
                    .environment(store)
            }
            .sheet(item: $selectedProduct) { product in
                ProductPriceHistoryView(product: product)
                    .environment(store)
            }
            .sheet(item: $editingProduct) { product in
                EditProductSheet(product: product)
                    .environment(store)
            }
        }
    }

    // MARK: - Product List

    private var productList: some View {
        List {
            if store.categories.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allCategories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation { selectedCategory = category }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                ForEach(filteredProducts) { product in
                    ProductRow(product: product, currencySymbol: store.currencySymbol,
                               lastPrice: store.latestPrice(for: product.id))
                        .contentShape(Rectangle())
                        .onTapGesture { selectedProduct = product }
                        .contextMenu {
                            Button {
                                editingProduct = product
                            } label: {
                                Label("Edit Product", systemImage: "pencil")
                            }
                            Button {
                                selectedProduct = product
                            } label: {
                                Label("Price History", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                }
                .onDelete { indices in
                    for index in indices {
                        store.deleteProduct(filteredProducts[index])
                    }
                }
            } header: {
                Text("\(filteredProducts.count) product\(filteredProducts.count == 1 ? "" : "s")")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "basket")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Your Basket is Empty")
                .font(.title3.weight(.semibold))
            Text("Add products you buy regularly to start tracking your personal inflation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showAddSheet = true
            } label: {
                Label("Add First Product", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.chartAccent)
            Spacer()
        }
    }
}

// MARK: - Product Row

private struct ProductRow: View {
    let product: ProductItem
    let currencySymbol: String
    let lastPrice: Double?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(categoryEmoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(product.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(categoryColor.opacity(0.15)))
                    Text("per \(product.unit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let price = lastPrice {
                Text("\(currencySymbol)\(String(format: "%.2f", price))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.chartAccent)
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryColor: Color {
        switch product.category {
        case "Groceries": return .green
        case "Dairy": return .blue
        case "Bakery": return .orange
        case "Meat": return .red
        case "Beverages": return .purple
        case "Personal Care": return .pink
        case "Transport": return .indigo
        case "Utilities": return .yellow
        default: return .gray
        }
    }

    private var categoryEmoji: String {
        switch product.category {
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

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? AppTheme.chartAccent : Color(.systemGray5))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Add Product Sheet

private struct AddProductSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Groceries"
    @State private var unit = "piece"
    @State private var showDuplicateAlert = false

    private let categories = ["Groceries", "Dairy", "Bakery", "Meat", "Beverages",
                               "Personal Care", "Transport", "Utilities", "Other"]
    private let units = ["piece", "kg", "lb", "liter", "gallon", "dozen", "pack", "loaf", "oz"]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicate: Bool {
        !trimmedName.isEmpty && store.hasProduct(named: trimmedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Product name", text: $name)
                    if isDuplicate {
                        Text("A product with this name already exists.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.priceIncrease)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addProduct(name: trimmedName, category: category, unit: unit)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty || isDuplicate)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Product Sheet

struct EditProductSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let product: ProductItem
    @State private var name = ""
    @State private var category = "General"
    @State private var unit = "piece"

    private let categories = ["General", "Groceries", "Dairy", "Bakery", "Meat", "Beverages",
                               "Personal Care", "Transport", "Utilities", "Other"]
    private let units = ["piece", "kg", "lb", "liter", "gallon", "dozen", "pack", "loaf", "oz"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Product") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }

                Section {
                    Button("Delete Product", role: .destructive) {
                        store.deleteProduct(product)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateProduct(product, name: name, category: category, unit: unit)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = product.name
                category = product.category
                unit = product.unit
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ProductCatalogView()
        .environment(DataStore(persistence: .preview))
}
