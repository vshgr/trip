import SwiftUI

struct TripsTabBar: View {
    let isShowingTrips: Bool
    let onTripsTap: () -> Void

    var body: some View {
        Button {
            onTripsTap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "suitcase")
                    .font(.system(size: 20, weight: .semibold))

                Text("Поездки")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isShowingTrips ? AppColors.accent : AppColors.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .background(Color.white)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}

enum TripWorkspaceSection: String, CaseIterable, Identifiable {
    case plan
    case expenses

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .plan:
            return "План"
        case .expenses:
            return "Траты"
        }
    }
}

struct TripWorkspaceView: View {
    @ObservedObject var planStore: TripStore
    @ObservedObject var expenseStore: ExpenseStore
    let trip: TravelTrip
    @State private var section: TripWorkspaceSection = .plan

    var body: some View {
        VStack(spacing: 0) {
            TripWorkspaceHeader(trip: trip, selectedSection: $section)

            switch section {
            case .plan:
                PlanTabView(store: planStore, trip: trip)
            case .expenses:
                ExpensesView(store: expenseStore, trip: trip)
            }
        }
        .onAppear {
            planStore.setActiveTrip(trip)
        }
        .onChange(of: trip) { _, newValue in
            planStore.setActiveTrip(newValue)
        }
    }
}

struct TripWorkspaceHeader: View {
    let trip: TravelTrip
    @Binding var selectedSection: TripWorkspaceSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(trip.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)

                if !trip.participants.isEmpty {
                    Text(trip.participants.joined(separator: ", "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(tripDateRangeString(start: trip.startDate, end: trip.endDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                TripProgressBar(trip: trip)
                    .padding(.top, 5)
            }

            HStack(spacing: 6) {
                ForEach(TripWorkspaceSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Text(section.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedSection == section ? Color.white : AppColors.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedSection == section ? AppColors.accent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color.white)
    }
}
