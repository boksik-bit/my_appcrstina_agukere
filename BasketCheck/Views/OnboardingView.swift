import SwiftUI

struct OnboardingView: View {
    @Environment(DataStore.self) private var store
    @State private var currentPage = 0
    @State private var productName = ""
    @State private var selectedUnit = "piece"
    @State private var selectedCategory = "Groceries"
    @State private var addedProducts: [String] = []
    @State private var prices: [UUID: String] = [:]
    @State private var showDuplicateAlert = false

    private let units = ["piece", "kg", "lb", "liter", "gallon", "dozen", "pack", "loaf"]
    private let categories = ["Groceries", "Dairy", "Bakery", "Meat", "Beverages",
                               "Personal Care", "Transport", "Utilities", "Other"]

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            addProductsPage.tag(1)
            logFirstPricesPage.tag(2)
            readyPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert("Product Already Exists", isPresented: $showDuplicateAlert) {
            Button("OK") {}
        } message: {
            Text("A product with this name is already in your basket. Try a different name.")
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cart.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.chartAccent)
                .symbolEffect(.pulse, options: .repeating)

            Text("Welcome to BasketCheck")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Track your personal inflation by logging prices of products you buy regularly.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingBullet(icon: "plus.circle.fill", text: "Add 3–5 items to your basket")
                OnboardingBullet(icon: "dollarsign.circle.fill", text: "Log prices each month")
                OnboardingBullet(icon: "chart.line.uptrend.xyaxis", text: "See your personal inflation index")
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.chartAccent)
            .padding(.horizontal, 32)

            Button {
                store.loadSampleData()
                store.completeOnboarding()
            } label: {
                Text("Explore with Sample Data")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.chartAccent)
            }
            .padding(.bottom, 20)

            DisclaimerFooter()
        }
    }

    // MARK: - Page 2: Add Products

    private var addProductsPage: some View {
        VStack(spacing: 16) {
            Text("Build Your Basket")
                .font(.title2.weight(.bold))
                .padding(.top, 32)

            Text("Add at least 3 products you buy regularly")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("Product name (e.g. Bread)", text: $productName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)

                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }

                Button {
                    let trimmed = productName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    if store.hasProduct(named: trimmed) {
                        showDuplicateAlert = true
                        return
                    }
                    store.addProduct(name: trimmed, category: selectedCategory, unit: selectedUnit)
                    addedProducts.append(trimmed)
                    productName = ""
                } label: {
                    Label("Add Product", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.chartAccent)
                .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            if !addedProducts.isEmpty {
                List {
                    ForEach(addedProducts, id: \.self) { name in
                        Label(name, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }

            Spacer()

            if addedProducts.count >= 3 {
                Button {
                    withAnimation { currentPage = 2 }
                } label: {
                    Text("Continue — Log First Prices")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.chartAccent)
                .padding(.horizontal, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("\(3 - addedProducts.count) more to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Page 3: Log First Prices

    private var logFirstPricesPage: some View {
        VStack(spacing: 16) {
            Text("Log Today's Prices")
                .font(.title2.weight(.bold))
                .padding(.top, 32)

            Text("Enter current prices for your products")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.products) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline.weight(.medium))
                            Text("per \(product.unit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text(store.currencySymbol)
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: priceBinding(for: product.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            Spacer()

            let filledCount = prices.values.filter {
                Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
            }.count

            Button {
                saveFirstPrices()
                withAnimation { currentPage = 3 }
            } label: {
                Text(filledCount > 0 ? "Save \(filledCount) Price\(filledCount == 1 ? "" : "s") & Continue" : "Skip for Now")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(filledCount > 0 ? AppTheme.chartAccent : .secondary)
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.priceDecrease)
                .symbolEffect(.bounce, options: .repeating.speed(0.5))

            Text("You're All Set!")
                .font(.largeTitle.weight(.bold))

            Text("Come back each month to log new prices. The more data you add, the more accurate your personal inflation index becomes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                store.completeOnboarding()
            } label: {
                Text("Start Tracking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.chartAccent)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            DisclaimerFooter()
        }
    }

    // MARK: - Helpers

    private func priceBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { prices[id] ?? "" },
            set: { prices[id] = $0 }
        )
    }

    private func saveFirstPrices() {
        let entries: [(productId: UUID, price: Double)] = prices.compactMap { id, text in
            guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
                  value > 0 else { return nil }
            return (productId: id, price: value)
        }
        if !entries.isEmpty {
            store.logPrices(entries)
        }
    }
}

// MARK: - Onboarding Bullet

private struct OnboardingBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.chartAccent)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(DataStore(persistence: .preview))
}
