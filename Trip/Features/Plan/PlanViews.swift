import SwiftUI
import WidgetKit

struct PlanTabView: View {
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

struct EuropeTripStatusWidget: View {
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

struct WidgetMetricBlock: View {
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

struct EuropeTripStatus {
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

struct HeaderView: View {
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

struct MonthCalendarView: View {
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

struct CalendarDayCell: View {
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

struct TimelineView: View {
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

struct DayTimelineGrid: View {
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

struct HourTimelineRow: View {
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

enum TimelineCardMode {
    case hour
    case period
    case unscheduled
}

struct TimelinePlanCard: View {
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
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height, alignment: .leading)
            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                onEdit()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Открыть редактирование")
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

struct TicketStatusIcon: View {
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

struct PlanEditorRequest: Identifiable {
    let id = UUID()
    let dayID: Int
    let item: PlanItem?
    let defaultCity: String
    let defaultDate: String
    let cities: [String]
    let dates: [String]
}

struct PlanItemEditorView: View {
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
                VStack(spacing: 22) {
                    CalendarFormSection {
                        TextField("Например: Саграда Фамилия", text: $text, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1...3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    CalendarFormSection {
                        CityMenuField(selection: $selectedCity, cities: request.cities)

                        CalendarDivider()

                        CategoryMenuField(selection: $selectedCategory)
                    }

                    CalendarFormSection {
                        VStack(spacing: 0) {
                            ScheduleEndpointRow(
                                title: "Начало",
                                dateSelection: $startDate,
                                timeSelection: $startTime,
                                dates: request.dates
                            )

                            CalendarDivider()

                            ScheduleEndpointRow(
                                title: "Конец",
                                dateSelection: $endDate,
                                timeSelection: $endTime,
                                dates: request.dates
                            )
                        }
                    }

                    if let timeValidationMessage {
                        Text(timeValidationMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    CalendarFormSection {
                        Toggle(isOn: $needsTicket) {
                            Text("Нужен билет")
                                .font(.body)
                                .foregroundStyle(AppColors.ink)
                        }
                        .tint(AppColors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        if needsTicket {
                            CalendarDivider()

                            Toggle(isOn: $ticketBought) {
                                Text("Билет куплен")
                                    .font(.body)
                                    .foregroundStyle(AppColors.ink)
                            }
                            .tint(AppColors.success)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: needsTicket)

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(AppColors.placeholder.ignoresSafeArea())
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
                    Button {
                        guard let draft = validatedDraft() else {
                            return
                        }

                        onSave(draft)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(canSave ? AppColors.accent : AppColors.faint)
                    .disabled(!canSave)
                    .accessibilityLabel("Сохранить")
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
        .onChange(of: needsTicket) { _, newValue in
            if !newValue {
                ticketBought = false
            }
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

struct CalendarFormSection<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CalendarDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}

struct CategoryMenuField: View {
    @Binding var selection: PlanCategory

    var body: some View {
        Menu {
            Picker("Тип", selection: $selection) {
                ForEach(PlanCategory.allCases) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .tag(category)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Тип")
                    .font(.body)
                    .foregroundStyle(AppColors.ink)

                Spacer(minLength: 12)

                Image(systemName: selection.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 24)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct CityMenuField: View {
    @Binding var selection: String
    let cities: [String]

    var body: some View {
        Menu {
            Picker("Город", selection: $selection) {
                ForEach(cities, id: \.self) { city in
                    Text(city).tag(city)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Город")
                    .font(.body)
                    .foregroundStyle(AppColors.ink)

                Spacer(minLength: 12)

                Text(selection)
                    .font(.body)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct ScheduleEndpointRow: View {
    let title: String
    @Binding var dateSelection: String
    @Binding var timeSelection: Date
    let dates: [String]

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(AppColors.ink)
                .frame(width: 72, alignment: .leading)

            DateField(selection: $dateSelection, dates: dates)

            Spacer(minLength: 8)

            TimePickerField(selection: $timeSelection)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
    }
}

struct TimePickerField: View {
    @Binding var selection: Date

    var body: some View {
        HStack {
            DatePicker("Время", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.accent)
        }
        .frame(minHeight: 34, alignment: .trailing)
    }
}

struct DateField: View {
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
            HStack(spacing: 5) {
                Text(selection)
                    .font(.body)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.faint)
            }
            .frame(minHeight: 34, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
