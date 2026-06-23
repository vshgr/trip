import SwiftUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let selectedTrip {
                    TripWorkspaceView(planStore: store, expenseStore: expenseStore, trip: selectedTrip)
                } else {
                    TripsView(
                        store: tripCatalogStore,
                        expenseStore: expenseStore,
                        selectedTripID: $selectedTripID
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TripsTabBar(isShowingTrips: selectedTripID == nil) {
                selectedTripID = nil
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
