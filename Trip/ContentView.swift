import SwiftUI
import MapKit
import WidgetKit

struct ContentView: View {
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

    private func syncSelectedTrip() {
        guard let selectedTripID else {
            return
        }

        if !tripCatalogStore.trips.contains(where: { $0.id == selectedTripID }) {
            self.selectedTripID = nil
        }
    }
}

private struct TripsTabBar: View {
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

private enum TripWorkspaceSection: String, CaseIterable, Identifiable {
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

private struct TripWorkspaceView: View {
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

private struct TripWorkspaceHeader: View {
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

private struct PlanTabView: View {
    @ObservedObject var store: TripStore
    let trip: TravelTrip
    @State private var selectedDayID = 0

    private var selectedDay: TripDay {
        store.days.first { $0.id == selectedDayID } ?? store.days.first ?? TripStore.days(for: trip)[0]
    }

    private var planCities: [String] {
        trip.cities.isEmpty ? Array(Set(store.days.map(\.city))).sorted() : trip.cities
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonthCalendarView(days: store.days, store: store, selectedDayID: $selectedDayID)
                    TimelineView(day: selectedDay, store: store, cities: planCities)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .background(TripBackground())
        .preferredColorScheme(.light)
        .onAppear {
            syncSelectedDay()
            WidgetCenter.shared.reloadTimelines(ofKind: "TripWidget")
        }
        .onChange(of: store.days) { _, _ in
            syncSelectedDay()
            WidgetCenter.shared.reloadTimelines(ofKind: "TripWidget")
        }
    }

    private func syncSelectedDay() {
        guard !store.days.contains(where: { $0.id == selectedDayID }) else {
            return
        }

        selectedDayID = store.days.first?.id ?? 0
    }
}

private struct EuropeTripStatusWidget: View {
    let days: [TripDay]

    private var status: EuropeTripStatus {
        EuropeTripStatus(days: days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(AppColors.accent, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Ближайшее")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppColors.muted)
                        .textCase(.uppercase)

                    Text(status.nextCityTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(alignment: .top, spacing: 10) {
                WidgetMetricBlock(
                    title: "До города",
                    value: status.daysUntilNextCityText,
                    detail: status.nextCityDetail,
                    systemImage: "calendar"
                )

                WidgetMetricBlock(
                    title: "План",
                    value: status.nextPlanDayTitle,
                    detail: status.nextPlanDetail,
                    systemImage: status.nextPlanSystemImage
                )
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct WidgetMetricBlock: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 18)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EuropeTripStatus {
    let days: [TripDay]
    private let calendar = Calendar(identifier: .gregorian)

    var nextCityTitle: String {
        guard let nextCity else {
            return "Маршрут завершён"
        }

        return nextCity.day.city
    }

    var daysUntilNextCityText: String {
        guard let nextCity else {
            return "0 дней"
        }

        return dayCountText(daysUntil(nextCity.date))
    }

    var nextCityDetail: String {
        guard let nextCity else {
            return "Новых городов в маршруте больше нет"
        }

        return "\(nextCity.day.date), \(nextCity.day.weekday)"
    }

    var nextPlanDayTitle: String {
        guard let nextPlan else {
            return "Нет планов"
        }

        return nextPlan.day.date
    }

    var nextPlanDetail: String {
        guard let nextPlan else {
            return "В ближайших днях поездки пока пусто"
        }

        return "\(nextPlan.item.timeLabel): \(nextPlan.item.title)"
    }

    var nextPlanSystemImage: String {
        nextPlan?.item.category.systemImage ?? "list.bullet"
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var datedDays: [(day: TripDay, date: Date)] {
        days.compactMap { day in
            guard let dateKey = day.dateKey, let date = Self.dateKeyFormatter.date(from: dateKey) else {
                return nil
            }

            return (day, calendar.startOfDay(for: date))
        }
        .sorted { $0.date < $1.date }
    }

    private var nextCity: (day: TripDay, date: Date)? {
        let datedDays = datedDays
        guard !datedDays.isEmpty else {
            return nil
        }

        guard let referenceIndex = datedDays.firstIndex(where: { $0.date >= today }) else {
            return nil
        }

        if today < datedDays[referenceIndex].date {
            return datedDays[referenceIndex]
        }

        let currentCity = datedDays[referenceIndex].day.city
        return datedDays[(referenceIndex + 1)...].first { $0.day.city != currentCity }
    }

    private var nextPlan: (day: TripDay, date: Date, item: PlanItem)? {
        datedDays
            .filter { $0.date >= today && !$0.day.items.isEmpty }
            .compactMap { day, date in
                guard let item = day.items.sorted(by: isPlanItemBefore).first else {
                    return nil
                }

                return (day, date, item)
            }
            .first
    }

    private func daysUntil(_ date: Date) -> Int {
        max(0, calendar.dateComponents([.day], from: today, to: date).day ?? 0)
    }

    private func isPlanItemBefore(_ first: PlanItem, _ second: PlanItem) -> Bool {
        if first.hasSchedule != second.hasSchedule {
            return first.hasSchedule
        }

        let firstMinutes = TripStore.minutes(from: first.startTime)
        let secondMinutes = TripStore.minutes(from: second.startTime)
        if firstMinutes != secondMinutes {
            return (firstMinutes ?? 10_000) < (secondMinutes ?? 10_000)
        }

        return first.sortIndex < second.sortIndex
    }

    private func dayCountText(_ count: Int) -> String {
        let lastTwoDigits = count % 100
        let lastDigit = count % 10

        if (11...14).contains(lastTwoDigits) {
            return "\(count) дней"
        }

        switch lastDigit {
        case 1:
            return "\(count) день"
        case 2...4:
            return "\(count) дня"
        default:
            return "\(count) дней"
        }
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct HeaderView: View {
    let trip: TravelTrip
    let dayCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trip.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColors.ink)

            HStack(spacing: 10) {
                Text(tripDateRangeString(start: trip.startDate, end: trip.endDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.muted)

                Circle()
                    .fill(AppColors.faint)
                    .frame(width: 4, height: 4)

                Text("\(dayCount) дней")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
            }

            Text(trip.cities.joined(separator: ", "))
                .font(.caption.weight(.medium))
                .lineSpacing(3)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct MonthCalendarView: View {
    let days: [TripDay]
    @ObservedObject var store: TripStore
    @Binding var selectedDayID: Int
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private var calendarCells: [TripDay?] {
        Array(repeating: nil, count: leadingBlanks) + days.map(Optional.some)
    }

    private var leadingBlanks: Int {
        guard
            let firstKey = days.first?.dateKey,
            let firstDate = Self.keyFormatter.date(from: firstKey)
        else {
            return 0
        }

        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: firstDate)
        return (weekday + 5) % 7
    }

    private var title: String {
        guard let first = days.first else {
            return "План поездки"
        }

        guard let firstKey = first.dateKey, let firstDate = Self.keyFormatter.date(from: firstKey) else {
            return first.date
        }

        guard
            let lastKey = days.last?.dateKey,
            let lastDate = Self.keyFormatter.date(from: lastKey),
            !Calendar(identifier: .gregorian).isDate(firstDate, equalTo: lastDate, toGranularity: .month)
        else {
            return Self.monthFormatter.string(from: firstDate)
        }

        return "\(Self.monthFormatter.string(from: firstDate)) - \(Self.monthFormatter.string(from: lastDate))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.ink)
                    Text("Цветная метка — город, серые дни — план пока не заполнен")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDayCell(
                            dayNumber: day.dayOfMonth,
                            tripDay: day,
                            isSelected: day.id == selectedDayID,
                            occupancyPercent: store.occupancyPercent(for: day.id)
                        ) { selectedDay in
                            selectedDayID = selectedDay.id
                        }
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

private struct CalendarDayCell: View {
    let dayNumber: Int
    let tripDay: TripDay?
    let isSelected: Bool
    let occupancyPercent: Int?
    let action: (TripDay) -> Void

    var body: some View {
        Button {
            if let tripDay {
                action(tripDay)
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.subheadline.weight(.bold))
                if tripDay != nil {
                    Text("\(occupancyPercent ?? 0)%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(markerColor)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(tripDay == nil)
    }

    private var backgroundColor: Color {
        if let tripDay {
            return tripDay.hasPlan ? Color.white : AppColors.placeholder
        }
        return Color.clear
    }

    private var foregroundColor: Color {
        if isSelected {
            return AppColors.ink
        }
        if tripDay != nil {
            return AppColors.ink
        }
        return AppColors.faint
    }

    private var markerColor: Color {
        guard let tripDay else {
            return .clear
        }
        return tripDay.color
    }

    private var borderColor: Color {
        guard let tripDay else {
            return Color.clear
        }
        if isSelected {
            return AppColors.accent
        }
        return tripDay.hasPlan ? tripDay.color.opacity(0.42) : Color.black.opacity(0.06)
    }
}

private struct TimelineView: View {
    let day: TripDay
    @ObservedObject var store: TripStore
    let cities: [String]
    @State private var editorRequest: PlanEditorRequest?

    var body: some View {
        let items = store.items(for: day.id)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(day.date)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.ink)

                    Menu {
                        ForEach(cities, id: \.self) { city in
                            Button {
                                store.updateDayCity(dayID: day.id, city: city)
                            } label: {
                                Label(city, systemImage: city == day.city ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(CityColors.color(for: day.city))
                                .frame(width: 8, height: 8)

                            Text(day.city)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.muted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.itemBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("Часовая сетка дня")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.muted)
                }

                Spacer()

                Button {
                    editorRequest = PlanEditorRequest(dayID: day.id, item: nil, defaultCity: day.city, defaultDate: day.date, cities: cities, dates: store.days.map(\.date))
                } label: {
                    Text("Добавить")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            DayTimelineGrid(
                day: day,
                items: items,
                store: store,
                onEdit: { item in
                    editorRequest = PlanEditorRequest(dayID: day.id, item: item, defaultCity: day.city, defaultDate: day.date, cities: cities, dates: store.days.map(\.date))
                },
                onDelete: { item in
                    store.deleteItem(dayID: day.id, itemID: item.id)
                }
            )
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .sheet(item: $editorRequest) { request in
            PlanItemEditorView(request: request) { draft in
                if let item = request.item {
                    store.updateItem(dayID: request.dayID, itemID: item.id, draft: draft)
                } else {
                    store.addItem(dayID: request.dayID, draft: draft)
                }
            }
        }
    }

}

private struct DayTimelineGrid: View {
    private let hourHeight: CGFloat = 64
    private let topInset: CGFloat = 6
    private let cardGap: CGFloat = 4
    private let timelineHours = Array(0...23)

    let day: TripDay
    let items: [PlanItem]
    @ObservedObject var store: TripStore
    let onEdit: (PlanItem) -> Void
    let onDelete: (PlanItem) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(timelineHours, id: \.self) { hour in
                        HourTimelineRow(hour: hour, dayID: day.id, store: store)
                            .frame(height: hourHeight)
                    }
                }

                ForEach(scheduledItems) { item in
                    TimelinePlanCard(
                        item: item,
                        mode: .hour,
                        height: cardHeight(for: item),
                        onEdit: { onEdit(item) },
                        onDelete: { onDelete(item) }
                    )
                    .padding(.leading, 82)
                    .offset(y: topOffset(for: item))
                    .zIndex(1)
                }
            }
            .padding(.top, topInset)
            .frame(height: topInset + totalTimelineHeight, alignment: .top)
            .clipped()
        }
    }

    private var scheduledItems: [PlanItem] {
        items.filter { item in
            guard TripStore.hour(from: item.startTime) != nil else {
                return false
            }

            return visibleSegment(for: item) != nil
        }
    }

    private var totalTimelineHeight: CGFloat {
        baseTimelineHeight
    }

    private func topOffset(for item: PlanItem) -> CGFloat {
        CGFloat(visibleSegment(for: item)?.top ?? 0)
    }

    private func cardHeight(for item: PlanItem) -> CGFloat {
        guard let segment = visibleSegment(for: item) else {
            return hourHeight
        }

        return max(44, CGFloat(segment.height) - cardGap)
    }

    private func visibleSegment(for item: PlanItem) -> TimelineSegment? {
        store.visibleSegment(for: item, on: day.date, hourHeight: Double(hourHeight))
    }

    private var baseTimelineHeight: CGFloat {
        CGFloat(timelineHours.count) * hourHeight
    }
}

private struct HourTimelineRow: View {
    private let hourHeight: CGFloat = 64

    let hour: Int
    let dayID: Int
    @ObservedObject var store: TripStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d:00", hour))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)
                .frame(width: 58, alignment: .trailing)
                .padding(.top, 4)

            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.faint)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(AppColors.faint.opacity(0.35))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 2)

            Rectangle()
                .fill(Color.clear)
                .frame(height: hourHeight)
                .frame(maxWidth: .infinity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let itemID = draggedID(from: values) else {
                return false
            }

            store.scheduleItem(dayID: dayID, itemID: itemID, hour: hour)
            return true
        }
    }

    private func draggedID(from values: [String]) -> UUID? {
        values.compactMap { UUID(uuidString: $0) }.first
    }

}

private enum TimelineCardMode {
    case hour
    case period
    case unscheduled
}

private struct TimelinePlanCard: View {
    let item: PlanItem
    let mode: TimelineCardMode
    var height: CGFloat? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var horizontalOffset: CGFloat = 0

    private let deleteRevealWidth: CGFloat = 62

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: deleteRevealWidth)
                    .frame(maxHeight: .infinity)
                    .background(AppColors.danger)
            }
            .accessibilityLabel("Удалить")

            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(CityColors.color(for: item.city))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: item.category.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 16)
                            .accessibilityLabel(item.category.title)

                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .lineSpacing(2)
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        TicketStatusIcon(item: item)
                    }

                    if item.hasExactTime || !item.startDate.isEmpty || !item.endDate.isEmpty {
                        Text(item.timeLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.callout.weight(.heavy))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AppColors.accent)
                .accessibilityLabel("Изменить")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height, alignment: .leading)
            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .offset(x: horizontalOffset)
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else {
                            return
                        }

                        let proposedOffset = min(0, value.translation.width)
                        horizontalOffset = max(-deleteRevealWidth, proposedOffset)
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            let isHorizontalSwipe = abs(value.translation.width) > abs(value.translation.height) * 1.4
                            horizontalOffset = isHorizontalSwipe && value.translation.width < -32 ? -deleteRevealWidth : 0
                        }
                    }
            )
        }
        .frame(height: height, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct TicketStatusIcon: View {
    let item: PlanItem

    var body: some View {
        if item.needsTicket {
            Image(systemName: item.ticketBought ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(item.ticketBought ? AppColors.success : AppColors.danger)
                .accessibilityLabel(item.ticketBought ? "Билет куплен" : "Билет не куплен")
        }
    }
}

private struct UnscheduledTimelineSection: View {
    let items: [PlanItem]
    let dayID: Int
    @ObservedObject var store: TripStore
    let onEdit: (PlanItem) -> Void
    let onDelete: (PlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Без времени")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppColors.muted)
                    .frame(width: 58, alignment: .trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Circle()
                    .fill(AppColors.faint)
                    .frame(width: 8, height: 8)

                Text("сюда попадают пункты без периода и часов")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    Text("Пока пусто")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.faint)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.placeholder, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(items) { item in
                        TimelinePlanCard(item: item, mode: .unscheduled, onEdit: { onEdit(item) }, onDelete: { onDelete(item) })
                    }
                }
            }
            .padding(.leading, 82)
        }
        .padding(.top, 10)
        .dropDestination(for: String.self) { values, _ in
            guard let itemID = values.compactMap({ UUID(uuidString: $0) }).first else {
                return false
            }

            store.scheduleItem(dayID: dayID, itemID: itemID, hour: nil)
            return true
        }
    }
}

private struct PlanEditorRequest: Identifiable {
    let id = UUID()
    let dayID: Int
    let item: PlanItem?
    let defaultCity: String
    let defaultDate: String
    let cities: [String]
    let dates: [String]
}

private struct PlanItemEditorView: View {
    let request: PlanEditorRequest
    let onSave: (PlanItemDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCity: String
    @State private var selectedCategory: PlanCategory
    @State private var startDate: String
    @State private var startTime: Date
    @State private var endDate: String
    @State private var endTime: Date
    @State private var needsTicket: Bool
    @State private var ticketBought: Bool
    @State private var text: String
    @State private var timeValidationMessage: String?

    init(request: PlanEditorRequest, onSave: @escaping (PlanItemDraft) -> Void) {
        self.request = request
        self.onSave = onSave
        _selectedCity = State(initialValue: request.item?.city ?? request.defaultCity)
        _selectedCategory = State(initialValue: request.item?.category ?? .walk)
        _startDate = State(initialValue: request.item?.startDate ?? request.defaultDate)
        _startTime = State(initialValue: Self.timeDate(from: request.item?.startTime) ?? Self.timeDate(hour: 9, minute: 0))
        _endDate = State(initialValue: request.item?.endDate ?? request.item?.startDate ?? request.defaultDate)
        _endTime = State(initialValue: Self.timeDate(from: request.item?.endTime) ?? Self.timeDate(hour: 10, minute: 0))
        _needsTicket = State(initialValue: request.item?.needsTicket ?? false)
        _ticketBought = State(initialValue: request.item?.ticketBought ?? false)
        _text = State(initialValue: request.item?.title ?? "")
        _timeValidationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        CompactPlanPicker(title: "Город") {
                            Picker("Город", selection: $selectedCity) {
                                ForEach(request.cities, id: \.self) { city in
                                    Text(city).tag(city)
                                }
                            }
                        }

                        CategoryMenuField(selection: $selectedCategory)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Дата и время")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColors.ink)

                            VStack(spacing: 0) {
                                ScheduleEndpointRow(
                                    title: "Начало",
                                    dateSelection: $startDate,
                                    timeSelection: $startTime,
                                    dates: request.dates
                                )

                                Divider()
                                    .padding(.leading, 76)

                                ScheduleEndpointRow(
                                    title: "Конец",
                                    dateSelection: $endDate,
                                    timeSelection: $endTime,
                                    dates: request.dates
                                )
                            }
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if let timeValidationMessage {
                            Text(timeValidationMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Пункт плана")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        TextEditor(text: $text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 90)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .overlay(alignment: .topLeading) {
                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Например: Саграда Фамилия, ужин, перелет...")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.faint)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $needsTicket) {
                            Text("Нужен билет")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                        }
                        .tint(AppColors.accent)

                        Toggle(isOn: $ticketBought) {
                            Text("Билет куплен")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(needsTicket ? AppColors.ink : AppColors.faint)
                        }
                        .tint(AppColors.success)
                        .disabled(!needsTicket)
                        .onChange(of: needsTicket) { _, newValue in
                            if !newValue {
                                ticketBought = false
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Spacer(minLength: 8)
                }
                .padding(14)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(request.item == nil ? "Новый пункт" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.muted)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let draft = validatedDraft() else {
                            return
                        }

                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.accent)
                    .disabled(!canSave)
                }
            }
        }
        .onChange(of: startDate) { _, _ in
            validateTimes()
        }
        .onChange(of: endDate) { _, _ in
            validateTimes()
        }
        .onChange(of: startTime) { _, _ in
            validateTimes()
        }
        .onChange(of: endTime) { _, _ in
            validateTimes()
        }
        .preferredColorScheme(.light)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && currentTimeValidationMessage == nil
    }

    private var currentTimeValidationMessage: String? {
        let start = dateIndex(for: startDate) * TimelineLayout.minutesPerDay + minutes(from: startTime)
        let end = dateIndex(for: endDate) * TimelineLayout.minutesPerDay + minutes(from: endTime)

        return start < end ? nil : "Начало должно быть раньше конца"
    }

    private func dateIndex(for date: String) -> Int {
        request.dates.firstIndex(of: date) ?? 0
    }

    private func validateTimes() {
        timeValidationMessage = currentTimeValidationMessage
    }

    private func validatedDraft() -> PlanItemDraft? {
        validateTimes()

        guard currentTimeValidationMessage == nil else {
            return nil
        }

        let normalizedStartTime = timeString(from: startTime)
        let normalizedEndTime = timeString(from: endTime)

        return PlanItemDraft(
            title: text,
            city: selectedCity,
            category: selectedCategory,
            startDate: startDate,
            startTime: normalizedStartTime,
            endDate: endDate,
            endTime: normalizedEndTime,
            needsTicket: needsTicket,
            ticketBought: needsTicket && ticketBought
        )
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func timeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func timeDate(from value: String?) -> Date? {
        guard
            let value,
            let minutes = TripStore.minutes(from: value)
        else {
            return nil
        }

        return timeDate(hour: minutes / 60, minute: minutes % 60)
    }

    private static func timeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }
}

private struct CategoryMenuField: View {
    @Binding var selection: PlanCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Тип")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)

            Menu {
                Picker("Тип", selection: $selection) {
                    ForEach(PlanCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage)
                            .tag(category)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 20)

                    Text(compactTitle(for: selection))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func compactTitle(for category: PlanCategory) -> String {
        switch category {
        case .sight:
            return "Место"
        case .transfer:
            return "Трансфер"
        default:
            return category.title
        }
    }
}

private struct CompactPlanPicker<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)

            content()
                .pickerStyle(.menu)
                .tint(AppColors.accent)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct ScheduleEndpointRow: View {
    let title: String
    @Binding var dateSelection: String
    @Binding var timeSelection: Date
    let dates: [String]

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)
                .frame(width: 56, alignment: .leading)

            DateField(selection: $dateSelection, dates: dates)
            TimePickerField(selection: $timeSelection)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 48)
    }
}

private struct TimePickerField: View {
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)

            DatePicker("Время", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct DateField: View {
    @Binding var selection: String
    let dates: [String]

    var body: some View {
        Menu {
            Picker("Дата", selection: $selection) {
                ForEach(dates, id: \.self) { date in
                    Text(date).tag(date)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 20)

                Text(selection)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TripsView: View {
    @ObservedObject var store: TripCatalogStore
    @ObservedObject var expenseStore: ExpenseStore
    @Binding var selectedTripID: UUID?
    @State private var editorTrip: TravelTrip?
    @State private var isCreatingTrip = false
    @State private var pendingDeleteTrip: TravelTrip?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(store.trips) { trip in
                        TripCardView(
                            trip: trip,
                            totalInRubles: expenseStore.totalInRubles(for: trip.id),
                            isSelected: trip.id == selectedTripID,
                            onSelect: {
                                selectedTripID = trip.id
                            },
                            onEdit: {
                                editorTrip = trip
                            },
                            onDelete: {
                                pendingDeleteTrip = trip
                            }
                        )
                    }

                    if store.trips.isEmpty {
                        Text("Пока нет поездок")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .background(TripBackground())
            .navigationTitle("Поездки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.accent)
                }
            }
            .sheet(isPresented: $isCreatingTrip) {
                TripEditorView(trip: nil) { trip in
                    store.add(trip)
                    selectedTripID = trip.id
                }
            }
            .sheet(item: $editorTrip) { trip in
                TripEditorView(trip: trip) { updatedTrip in
                    store.update(updatedTrip)
                }
            }
            .confirmationDialog(
                "Удалить поездку?",
                isPresented: Binding(
                    get: { pendingDeleteTrip != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeleteTrip = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let pendingDeleteTrip {
                        store.delete(pendingDeleteTrip)
                        if pendingDeleteTrip.id == selectedTripID {
                            selectedTripID = nil
                        }
                    }
                    pendingDeleteTrip = nil
                }

                Button("Отмена", role: .cancel) {
                    pendingDeleteTrip = nil
                }
            } message: {
                if let pendingDeleteTrip {
                    Text("Это удалит поездку «\(pendingDeleteTrip.title)».")
                }
            }
        }
    }
}

private struct TripCardView: View {
    let trip: TravelTrip
    let totalInRubles: Double?
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColors.success)
                        }

                        Text(trip.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(2)
                    }

                    Text(tripDateRangeString(start: trip.startDate, end: trip.endDate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.muted)

                    Text(totalInRubles.map { rubleString($0) } ?? "Курс недоступен")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if !trip.participants.isEmpty {
                        Text(trip.participants.joined(separator: ", "))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 34, height: 34)
                            .background(AppColors.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.danger)
                            .frame(width: 34, height: 34)
                            .background(AppColors.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Города")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppColors.muted)

                VStack(spacing: 0) {
                    ForEach(Array(trip.cities.enumerated()), id: \.offset) { index, city in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.muted)
                                .frame(width: 24, height: 24)
                                .background(Color.white, in: Circle())

                            Text(city)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)

                        if index < trip.cities.count - 1 {
                            Divider()
                                .padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? AppColors.accent : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onSelect()
        }
    }
}

private struct TripEditorView: View {
    let trip: TravelTrip?
    let onSave: (TravelTrip) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var citySearch = CitySearchStore()
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedCities: [String]
    @State private var cityQuery = ""
    @State private var participants: [String]
    @State private var participantName = ""

    init(trip: TravelTrip?, onSave: @escaping (TravelTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _title = State(initialValue: trip?.title ?? "")
        _startDate = State(initialValue: trip?.startDate ?? Date())
        _endDate = State(initialValue: trip?.endDate ?? Date())
        _selectedCities = State(initialValue: trip?.cities ?? [])
        _participants = State(initialValue: trip?.participants ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        TextField("Летняя поездка", text: $title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                            .padding(12)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Даты")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        DatePicker("Начало", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(AppColors.accent)

                        DatePicker("Конец", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(AppColors.accent)

                        if endDate < startDate {
                            Text("Дата конца не может быть раньше начала")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                    .padding(14)
                    .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Участники")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        HStack(spacing: 8) {
                            TextField("Имя", text: $participantName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                                .padding(12)
                                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .onSubmit(addParticipant)

                            Button {
                                addParticipant()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(cleanParticipantName.isEmpty)
                        }

                        if !participants.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(participants.enumerated()), id: \.offset) { index, participant in
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppColors.accent)
                                            .frame(width: 24, height: 24)
                                            .background(Color.white, in: Circle())

                                        Text(participant)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppColors.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button {
                                            participants.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(AppColors.faint)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Удалить участника")
                                    }
                                    .padding(.vertical, 9)

                                    if index < participants.count - 1 {
                                        Divider()
                                            .padding(.leading, 34)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Города")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        if selectedCities.isEmpty {
                            Text("Добавьте города маршрута")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.muted)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedCities.enumerated()), id: \.offset) { index, city in
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppColors.muted)
                                            .frame(width: 24, height: 24)
                                            .background(Color.white, in: Circle())

                                        Text(city)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppColors.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button {
                                            selectedCities.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(AppColors.faint)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Удалить город")
                                    }
                                    .padding(.vertical, 10)

                                    if index < selectedCities.count - 1 {
                                        Divider()
                                            .padding(.leading, 34)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        TextField("Найти город", text: $cityQuery)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                            .padding(12)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: cityQuery) { _, newValue in
                                citySearch.search(newValue)
                            }

                        if citySearch.isSearching {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.top, 4)
                        }

                        if !citySearch.suggestions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(citySearch.suggestions) { suggestion in
                                    Button {
                                        addCity(suggestion.name)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppColors.accent)
                                                .frame(width: 24)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(suggestion.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppColors.ink)
                                                    .frame(maxWidth: .infinity, alignment: .leading)

                                                if !suggestion.subtitle.isEmpty {
                                                    Text(suggestion.subtitle)
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(AppColors.muted)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if suggestion.id != citySearch.suggestions.last?.id {
                                        Divider()
                                            .padding(.leading, 34)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(trip == nil ? "Новая поездка" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.muted)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(
                            TravelTrip(
                                id: trip?.id ?? UUID(),
                                title: cleanTitle,
                                startDate: startDate,
                                endDate: endDate,
                                cities: selectedCities,
                                participants: cleanParticipants
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.accent)
                    .disabled(!canSave)
                }
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanParticipantName: String {
        participantName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanParticipants: [String] {
        participants
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !cleanTitle.isEmpty && !selectedCities.isEmpty && startDate <= endDate
    }

    private func addParticipant() {
        let name = cleanParticipantName
        guard !name.isEmpty else {
            return
        }

        if !participants.contains(name) {
            participants.append(name)
        }

        participantName = ""
    }

    private func addCity(_ city: String) {
        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCity.isEmpty else {
            return
        }

        if !selectedCities.contains(cleanCity) {
            selectedCities.append(cleanCity)
        }

        cityQuery = ""
        citySearch.search("")
    }
}

private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ExpensesView: View {
    @ObservedObject var store: ExpenseStore
    let trip: TravelTrip
    @State private var title = ""
    @State private var amount = ""
    @State private var currency: ExpenseCurrency = .eur
    @State private var selectedParticipant = ""
    @State private var selectedFilterParticipant = ""
    @FocusState private var focusedField: ExpenseInputField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ExpenseEntryView(
                    title: $title,
                    amount: $amount,
                    currency: $currency,
                    selectedParticipant: $selectedParticipant,
                    participants: trip.participants,
                    focusedField: $focusedField,
                    canAdd: parsedAmount != nil
                ) {
                    addExpense()
                }

                ExpenseTotalsView(
                    store: store,
                    tripID: trip.id,
                    participantName: selectedFilterParticipant
                ) {
                    Task {
                        await store.refreshRates()
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Список")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.ink)

                        Spacer(minLength: 8)

                        if !trip.participants.isEmpty {
                            ExpenseParticipantFilter(
                                participants: trip.participants,
                                selectedParticipant: $selectedFilterParticipant
                            )
                            .frame(maxWidth: 230, alignment: .trailing)
                        }
                    }

                    let tripExpenses = store.expenses(for: trip.id, participantName: selectedFilterParticipant)
                    if tripExpenses.isEmpty {
                            Text("Пока пусто")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        ForEach(tripExpenses) { expense in
                            ExpenseRowView(expense: expense) {
                                store.deleteExpense(expense)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TripBackground())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Готово") {
                    dismissKeyboard()
                }
                .fontWeight(.bold)
            }
        }
        .task {
            if store.rates[.eur] == nil || store.rates[.usd] == nil {
                await store.refreshRates()
            }
        }
        .onChange(of: trip.participants) { _, participants in
            if !participants.contains(selectedParticipant) {
                selectedParticipant = ""
            }
            if !participants.contains(selectedFilterParticipant) {
                selectedFilterParticipant = ""
            }
        }
    }

    private var parsedAmount: Double? {
        let normalized = amount
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized), value > 0 else {
            return nil
        }

        return value
    }

    private func addExpense() {
        guard let parsedAmount else {
            return
        }

        store.addExpense(
            title: title,
            amount: parsedAmount,
            currency: currency,
            tripID: trip.id,
            participantName: trip.participants.contains(selectedParticipant) ? selectedParticipant : nil
        )
        title = ""
        amount = ""
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum ExpenseInputField: Hashable {
    case title
    case amount
}

private struct ExpenseParticipantFilter: View {
    let participants: [String]
    @Binding var selectedParticipant: String

    var body: some View {
        ParticipantChipSelector(
            participants: participants,
            selectedParticipant: $selectedParticipant,
            allTitle: "Все"
        )
    }
}

private struct ParticipantChipSelector: View {
    let participants: [String]
    @Binding var selectedParticipant: String
    let allTitle: String

    private var options: [String] {
        [""] + participants
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedParticipant = option
                    } label: {
                        Text(option.isEmpty ? allTitle : option)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedParticipant == option ? Color.white : AppColors.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                selectedParticipant == option ? AppColors.accent : AppColors.itemBackground,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ExpenseEntryView: View {
    @Binding var title: String
    @Binding var amount: String
    @Binding var currency: ExpenseCurrency
    @Binding var selectedParticipant: String
    let participants: [String]
    var focusedField: FocusState<ExpenseInputField?>.Binding
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Новая трата")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.ink)

                Spacer()

                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(canAdd ? Color.white : AppColors.faint)
                        .frame(width: 34, height: 34)
                        .background(canAdd ? AppColors.accent : AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }

            TextField("Что купили", text: $title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused(focusedField, equals: .title)

            HStack(spacing: 8) {
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(width: 112)
                    .focused(focusedField, equals: .amount)

                Picker("Валюта", selection: $currency) {
                    ForEach(ExpenseCurrency.allCases) { currency in
                        Text(currency.symbol).tag(currency)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Участник")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)

                    ParticipantChipSelector(
                        participants: participants,
                        selectedParticipant: $selectedParticipant,
                        allTitle: "Общее"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ExpenseTotalsView: View {
    @ObservedObject var store: ExpenseStore
    let tripID: UUID
    let participantName: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(participantName.isEmpty ? "Итоги" : "Итоги: \(participantName)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.ink)

                Spacer()

                if store.isLoadingRates {
                    ProgressView()
                        .controlSize(.small)
                } else if let ratesDate = store.ratesDate {
                    Text("ЦБ \(ratesDate)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                }

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 28, height: 28)
                        .background(AppColors.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(store.isLoadingRates)
            }

            HStack(spacing: 6) {
                ForEach(ExpenseCurrency.allCases) { currency in
                    ExpenseTotalPill(
                        currency: currency,
                        amount: store.totalsByCurrency(for: tripID, participantName: participantName)[currency] ?? 0
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Всего в рублях")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.muted)

                Text(store.totalInRubles(for: tripID, participantName: participantName).map { rubleString($0) } ?? "Курс недоступен")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let ratesError = store.ratesError {
                    Text(ratesError)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ExpenseTotalPill: View {
    let currency: ExpenseCurrency
    let amount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(currency.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)

            Text(moneyString(amount, currency: currency))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ExpenseRowView: View {
    let expense: ExpenseItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)

                Text(expense.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.muted)

                if let participantName = expense.participantName, !participantName.isEmpty {
                    Text(participantName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                }
            }

            Spacer()

            Text(moneyString(expense.amount, currency: expense.currency))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.danger)
                    .frame(width: 28, height: 28)
                    .background(AppColors.accentSoft, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private func moneyString(_ value: Double, currency: ExpenseCurrency) -> String {
    let formatted = value.formatted(
        .number
            .precision(.fractionLength(0...2))
            .grouping(.automatic)
    )

    return "\(formatted) \(currency.symbol)"
}

private func rubleString(_ value: Double) -> String {
    let formatted = value.formatted(
        .number
            .precision(.fractionLength(0...2))
            .grouping(.automatic)
    )

    return "\(formatted) RUB"
}

private func tripDateRangeString(start: Date, end: Date) -> String {
    let startText = start.formatted(.dateTime.day().month(.wide).year())
    let endText = end.formatted(.dateTime.day().month(.wide).year())
    return "\(startText) - \(endText)"
}

private struct CitySuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
}

@MainActor
private final class CitySearchStore: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [CitySuggestion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }

        isSearching = true
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.prefix(8).map { result in
            let title = result.title
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? result.title
            let subtitle = result.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

            return CitySuggestion(
                id: "\(result.title)-\(result.subtitle)",
                name: title,
                subtitle: subtitle
            )
        }

        Task { @MainActor in
            self.suggestions = Array(
                Dictionary(grouping: results, by: \.name)
                    .compactMap { $0.value.first }
                    .prefix(6)
            )
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}

private struct TripBackground: View {
    var body: some View {
        Color.white.ignoresSafeArea()
    }
}

private enum AppColors {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.18)
    static let muted = Color(red: 0.38, green: 0.40, blue: 0.46)
    static let faint = Color(red: 0.68, green: 0.70, blue: 0.74)
    static let accent = Color(red: 0.86, green: 0.20, blue: 0.25)
    static let accentSoft = Color(red: 0.99, green: 0.90, blue: 0.91)
    static let success = Color(red: 0.10, green: 0.58, blue: 0.30)
    static let danger = Color(red: 0.86, green: 0.16, blue: 0.20)
    static let warning = Color(red: 0.78, green: 0.28, blue: 0.12)
    static let itemBackground = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let placeholder = Color(red: 0.94, green: 0.94, blue: 0.95)
}
