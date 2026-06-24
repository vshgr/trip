import SwiftUI
import WidgetKit

enum AppRootSection: String, CaseIterable, Identifiable {
    case trips
    case profile

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .trips:
            return "Поездки"
        case .profile:
            return "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .trips:
            return "suitcase"
        case .profile:
            return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    var body: some View {
        Group {
            if authStore.isSignedIn {
                VStack(spacing: 0) {
                    Group {
                        switch selectedRootSection {
                        case .trips:
                            if let selectedTrip {
                                TripWorkspaceView(planStore: store, expenseStore: expenseStore, trip: selectedTrip)
                            } else {
                                TripsView(
                                    store: tripCatalogStore,
                                    expenseStore: expenseStore,
                                    selectedTripID: $selectedTripID
                                )
                            }
                        case .profile:
                            ProfileTabView(authStore: authStore)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AppRootTabBar(selectedSection: $selectedRootSection) {
                        selectedTripID = nil
                    }
                }
            } else {
                AuthLandingView(authStore: authStore)
            }
        }
        .tint(AppColors.accent)
        .preferredColorScheme(.light)
        .onAppear {
            WidgetCenter.shared.reloadTimelines(ofKind: "TripWidget")
        }
        .onChange(of: selectedTripID) { _, newValue in
            if let newValue, let trip = tripCatalogStore.trips.first(where: { $0.id == newValue }) {
                store.setActiveTrip(trip)
            }
        }
        .onChange(of: tripCatalogStore.trips) { _, _ in
            syncSelectedTrip()
        }
    }

    @StateObject private var store = TripStore()
    @StateObject private var expenseStore = ExpenseStore()
    @StateObject private var tripCatalogStore = TripCatalogStore()
    @StateObject private var authStore = AuthStore()
    @State private var selectedRootSection: AppRootSection = .trips
    @State private var selectedTripID: UUID?

    private var selectedTrip: TravelTrip? {
        guard let selectedTripID else {
            return nil
        }

        return tripCatalogStore.trips.first { $0.id == selectedTripID }
    }

    private func syncSelectedTrip() {
        guard let selectedTripID else {
            return
        }

        if !tripCatalogStore.trips.contains(where: { $0.id == selectedTripID }) {
            self.selectedTripID = nil
        }
    }
}
