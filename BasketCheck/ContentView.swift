import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        if store.hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            CurrentBasketView()
                .tabItem {
                    Label("Basket", systemImage: "cart.fill")
                }
                .tag(0)

            PersonalCPIView()
                .tabItem {
                    Label("My CPI", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            ProductCatalogView()
                .tabItem {
                    Label("Products", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(2)

            moreTab
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(3)
        }
        .tint(AppTheme.chartAccent)
    }

    private var moreTab: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        InflationForecasterView()
                            .environment(store)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Inflation Forecast")
                                    .font(.subheadline.weight(.medium))
                                Text("Project future basket costs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                    }

                    NavigationLink {
                        PurchasingPowerView()
                            .environment(store)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Purchasing Power")
                                    .font(.subheadline.weight(.medium))
                                Text("How far your salary goes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "wallet.bifold.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                    }

                    NavigationLink {
                        PriceAnomaliesView()
                            .environment(store)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Price Anomalies")
                                    .font(.subheadline.weight(.medium))
                                Text("Biggest price changes this month")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.priceIncrease)
                        }
                    }

                    NavigationLink {
                        CategoryInflationView()
                            .environment(store)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Category Breakdown")
                                    .font(.subheadline.weight(.medium))
                                Text("Inflation by product category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.pie.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Analytics")
                }

                Section {
                    NavigationLink {
                        SettingsView()
                            .environment(store)
                    } label: {
                        Label {
                            Text("Settings")
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
        }
    }
}

#Preview {
    ContentView()
        .environment(DataStore(persistence: .preview))
}
