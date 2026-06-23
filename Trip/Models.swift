import Foundation
import SwiftUI

struct TripDay: Identifiable, Codable, Equatable {
    var id: Int
    var date: String
    var dateKey: String?
    var city: String
    var weekday: String
    var dayOfMonth: Int
    var items: [PlanItem]

    var hasPlan: Bool {
        !items.isEmpty
    }

    var color: Color {
        CityColors.color(for: city)
    }
}

struct PlanItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var city: String
    var category: PlanCategory
    var period: String?
    var startDate: String
    var startTime: String
    var endDate: String
    var endTime: String
    var sortIndex: Int
    var needsTicket: Bool
    var ticketBought: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case city
        case category
        case period
        case startDate
        case startTime
        case endDate
        case endTime
        case sortIndex
        case needsTicket
        case ticketBought
    }

    init(
        id: UUID = UUID(),
        title: String,
        city: String,
        category: PlanCategory = .walk,
        period: String?,
        startDate: String = "",
        startTime: String,
        endDate: String = "",
        endTime: String,
        sortIndex: Int,
        needsTicket: Bool = false,
        ticketBought: Bool = false
    ) {
        self.id = id
        self.title = title
        self.city = city
        self.category = category
        self.period = period
        self.startDate = startDate
        self.startTime = startTime
        self.endDate = endDate
        self.endTime = endTime
        self.sortIndex = sortIndex
        self.needsTicket = needsTicket
        self.ticketBought = needsTicket && ticketBought
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        city = try container.decode(String.self, forKey: .city)
        category = try container.decodeIfPresent(PlanCategory.self, forKey: .category) ?? .walk
        period = try container.decodeIfPresent(String.self, forKey: .period)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        startTime = try container.decode(String.self, forKey: .startTime)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate) ?? startDate
        endTime = try container.decode(String.self, forKey: .endTime)
        sortIndex = try container.decode(Int.self, forKey: .sortIndex)
        needsTicket = try container.decodeIfPresent(Bool.self, forKey: .needsTicket) ?? false
        let decodedTicketBought = try container.decodeIfPresent(Bool.self, forKey: .ticketBought) ?? false
        ticketBought = needsTicket && decodedTicketBought
    }

    var hasExactTime: Bool {
        !startTime.isEmpty || !endTime.isEmpty
    }

    var hasSchedule: Bool {
        hasExactTime || period != nil
    }

    var timeLabel: String {
        if !startTime.isEmpty, !endTime.isEmpty {
            if !startDate.isEmpty, !endDate.isEmpty, startDate != endDate {
                return "\(startDate) \(startTime)-\(endDate) \(endTime)"
            }
            return "\(startTime)-\(endTime)"
        }
        if !startTime.isEmpty {
            return startTime
        }
        if !endTime.isEmpty {
            return "до \(endTime)"
        }
        return period ?? "Без времени"
    }
}

enum PlanCategory: String, Codable, CaseIterable, Identifiable {
    case transfer
    case rest
    case walk
    case sight
    case food
    case shopping

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .transfer:
            return "Перемещение"
        case .rest:
            return "Отдых"
        case .walk:
            return "Прогулка"
        case .sight:
            return "Достопримечательность"
        case .food:
            return "Еда"
        case .shopping:
            return "Шоппинг"
        }
    }

    var systemImage: String {
        switch self {
        case .transfer:
            return "airplane"
        case .rest:
            return "sparkles"
        case .walk:
            return "figure.walk"
        case .sight:
            return "camera"
        case .food:
            return "fork.knife"
        case .shopping:
            return "bag"
        }
    }
}

struct TripStop: Identifiable {
    let id = UUID()
    let city: String
    let status: StopStatus
}

enum StopStatus {
    case planned
    case upcoming
}

struct TimelineSegment: Equatable {
    let top: Double
    let height: Double
}

enum TimelineLayout {
    static let minutesPerDay = 24 * 60
    static let activeDayStartHour = 8
    static let activeDayMinutes = 15 * 60

    static func dayStartMinutes(for date: String) -> Int? {
        dateIndex(for: date) * minutesPerDay
    }

    static func dayEndMinutes(for date: String) -> Int? {
        dayStartMinutes(for: date).map { $0 + minutesPerDay }
    }

    static func activeDayStartMinutes(for date: String) -> Int? {
        dayStartMinutes(for: date).map { $0 + activeDayStartHour * 60 }
    }

    static func activeDayEndMinutes(for date: String) -> Int? {
        activeDayStartMinutes(for: date).map { $0 + activeDayMinutes }
    }

    static func visibleSegment(for item: PlanItem, on dayDate: String, hourHeight: Double) -> TimelineSegment? {
        guard
            let itemStart = absoluteMinutes(date: item.startDate, time: item.startTime),
            let itemEnd = normalizedEndMinutes(for: item),
            let dayStart = dayStartMinutes(for: dayDate),
            let dayEnd = dayEndMinutes(for: dayDate)
        else {
            return nil
        }

        guard itemEnd > dayStart, itemStart < dayEnd else {
            return nil
        }

        let visibleStart = max(itemStart, dayStart)
        let visibleEnd = min(itemEnd, dayEnd)
        let top = Double(visibleStart - dayStart) / 60 * hourHeight
        let height = Double(visibleEnd - visibleStart) / 60 * hourHeight

        return TimelineSegment(top: top, height: max(44, height))
    }

    private static func dateIndex(for date: String) -> Int {
        ItineraryData.days.firstIndex { $0.date == date || $0.dateKey == date } ?? 0
    }

    private static func absoluteMinutes(date: String, time: String) -> Int? {
        guard let minutes = TripStore.minutes(from: time) else {
            return nil
        }

        return dateIndex(for: date) * minutesPerDay + minutes
    }

    private static func normalizedEndMinutes(for item: PlanItem) -> Int? {
        guard let start = absoluteMinutes(date: item.startDate, time: item.startTime) else {
            return nil
        }

        guard let endTimeMinutes = TripStore.minutes(from: item.endTime) else {
            return start + 60
        }

        let rawEndDate = item.endDate.isEmpty ? item.startDate : item.endDate
        var end = dateIndex(for: rawEndDate) * minutesPerDay + endTimeMinutes
        if end <= start {
            end += minutesPerDay
        }

        return end
    }
}

enum SharedTripDefaults {
    static let appGroupID = "group.com.alisa.trip"
    static let europeDaysKey = "trip.days.shared.europe"

    static func saveEuropeDays(_ days: [TripDay]) {
        guard
            let data = try? JSONEncoder().encode(days),
            let defaults = UserDefaults(suiteName: appGroupID)
        else {
            return
        }

        defaults.set(data, forKey: europeDaysKey)
    }

    static func loadEuropeDays() -> [TripDay]? {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: europeDaysKey),
            let decoded = try? JSONDecoder().decode([TripDay].self, from: data)
        else {
            return nil
        }

        return decoded
    }
}

@MainActor
final class TripStore: ObservableObject {
    @Published var days: [TripDay] {
        didSet {
            save()
        }
    }

    nonisolated static let periods = ["Утро", "День", "Вечер", "Ночь"]
    nonisolated static let cities = ["Барселона", "Ибица", "Ницца", "Париж", "Брюссель", "Амстердам"]
    nonisolated static let tripDates = ItineraryData.days.map(\.date)

    private let storageKeyPrefix = "trip.days.editable.v6"
    private let legacyStorageKey = "trip.days.editable.v4"
    private var activeTripID = TripCatalogStore.defaultTripID
    private var activeTrip = TripCatalogStore.defaultTrip

    private var storageKey: String {
        "\(storageKeyPrefix).\(activeTripID.uuidString)"
    }

    init() {
        activeTripID = activeTrip.id
        days = Self.loadDays(
            storageKey: "\(storageKeyPrefix).\(activeTrip.id.uuidString)",
            legacyStorageKey: legacyStorageKey,
            allowsLegacyMigration: true,
            fallbackDays: ItineraryData.days
        )
        restoreLegacyDaysIfNeeded()
        if days.contains(where: { $0.dateKey == nil }) {
            syncDays(with: ItineraryData.days)
        } else {
            SharedTripDefaults.saveEuropeDays(days)
        }
        save()
    }

    func setActiveTrip(_ trip: TravelTrip) {
        let didChangeTrip = activeTripID != trip.id
        let didChangeShape = activeTrip.startDate != trip.startDate || activeTrip.endDate != trip.endDate || activeTrip.cities != trip.cities
        let needsDateSync = days.contains { $0.dateKey == nil }
        guard didChangeTrip || didChangeShape || needsDateSync else {
            return
        }

        activeTripID = trip.id
        activeTrip = trip
        let fallbackDays = Self.days(for: trip)
        days = Self.loadDays(
            storageKey: storageKey,
            legacyStorageKey: legacyStorageKey,
            allowsLegacyMigration: trip.id == TripCatalogStore.defaultTripID,
            fallbackDays: fallbackDays
        )
        syncDays(with: fallbackDays)
    }

    private static func loadDays(
        storageKey: String,
        legacyStorageKey: String,
        allowsLegacyMigration: Bool,
        fallbackDays: [TripDay]
    ) -> [TripDay] {
        let legacyDays: [TripDay]? = {
            guard
                allowsLegacyMigration,
                let data = UserDefaults.standard.data(forKey: legacyStorageKey),
                let decoded = try? JSONDecoder().decode([TripDay].self, from: data),
                !shouldIgnoreStoredDays(decoded, fallbackDays: fallbackDays, allowsLegacyMigration: allowsLegacyMigration)
            else {
                return nil
            }

            return decoded
        }()

        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([TripDay].self, from: data)
        {
            if shouldIgnoreStoredDays(decoded, fallbackDays: fallbackDays, allowsLegacyMigration: allowsLegacyMigration) {
                if let legacyDays {
                    saveDays(legacyDays, forKey: storageKey)
                    return legacyDays
                }

                return fallbackDays
            }

            if let legacyDays, itemCount(in: legacyDays) > itemCount(in: decoded) {
                saveDays(legacyDays, forKey: storageKey)
                return legacyDays
            }

            return decoded
        }

        if let legacyDays {
            saveDays(legacyDays, forKey: storageKey)
            return legacyDays
        }

        return fallbackDays
    }

    private func restoreLegacyDaysIfNeeded() {
        guard
            activeTripID == TripCatalogStore.defaultTripID,
            let legacyDays = Self.loadLegacyDays(forKey: legacyStorageKey),
            Self.itemCount(in: legacyDays) > Self.itemCount(in: days)
        else {
            return
        }

        days = legacyDays
    }

    private static func loadLegacyDays(forKey key: String) -> [TripDay]? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([TripDay].self, from: data)
        else {
            return nil
        }

        return decoded
    }

    private static func saveDays(_ days: [TripDay], forKey key: String) {
        guard let data = try? JSONEncoder().encode(days) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    private static func itemCount(in days: [TripDay]) -> Int {
        days.reduce(0) { $0 + $1.items.count }
    }

    private static func shouldIgnoreStoredDays(_ days: [TripDay], fallbackDays: [TripDay], allowsLegacyMigration: Bool) -> Bool {
        let storedDates = days.map(\.date)
        let fallbackDates = fallbackDays.map(\.date)
        let defaultDates = ItineraryData.days.map(\.date)
        let storedIsEmpty = days.allSatisfy { $0.items.isEmpty }
        let fallbackHasItems = fallbackDays.contains { !$0.items.isEmpty }

        if allowsLegacyMigration, storedDates == fallbackDates, storedIsEmpty, fallbackHasItems {
            return true
        }

        return storedDates == defaultDates && storedDates != fallbackDates
    }

    func items(for dayID: Int) -> [PlanItem] {
        guard let day = days.first(where: { $0.id == dayID }) else {
            return []
        }

        let visibleStart = dayStartMinutes(for: day.date) ?? 0
        let visibleEnd = dayEndMinutes(for: day.date) ?? (visibleStart + TimelineLayout.minutesPerDay)

        let collectedItems = days.flatMap { sourceDay in
            sourceDay.items.filter { item in
                if item.startDate.isEmpty {
                    return sourceDay.id == dayID
                }

                return self.item(item, intersectsFrom: visibleStart, to: visibleEnd)
            }
        }

        return collectedItems.sorted { first, second in
            if first.hasSchedule != second.hasSchedule {
                return first.hasSchedule
            }
            let firstMinutes = Self.minutes(from: first.startTime)
            let secondMinutes = Self.minutes(from: second.startTime)
            if firstMinutes != secondMinutes {
                return (firstMinutes ?? 10_000) < (secondMinutes ?? 10_000)
            }
            return first.sortIndex < second.sortIndex
        }
    }

    func updateDayCity(dayID: Int, city: String) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else {
            return
        }

        days[dayIndex].city = city
    }

    func occupancyPercent(for dayID: Int) -> Int {
        guard let day = days.first(where: { $0.id == dayID }) else {
            return 0
        }

        let visibleStart = activeDayStartMinutes(for: day.date) ?? 0
        let visibleEnd = activeDayEndMinutes(for: day.date) ?? (visibleStart + TimelineLayout.activeDayMinutes)
        let occupiedMinutes = days
            .flatMap(\.items)
            .compactMap { item -> Int? in
                guard
                    let itemStart = absoluteMinutes(date: item.startDate, time: item.startTime),
                    let itemEnd = normalizedEndMinutes(for: item),
                    itemEnd > visibleStart,
                    itemStart < visibleEnd
                else {
                    return nil
                }

                return min(itemEnd, visibleEnd) - max(itemStart, visibleStart)
            }
            .reduce(0, +)

        let percent = Double(occupiedMinutes) / Double(TimelineLayout.activeDayMinutes) * 100
        return min(100, max(0, Int(percent.rounded())))
    }

    func addItem(dayID: Int, draft: PlanItemDraft) {
        guard let dayIndex = targetDayIndex(defaultDayID: dayID, date: draft.startDate) else {
            return
        }

        let cleanText = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return
        }

        let nextIndex = (days[dayIndex].items.map(\.sortIndex).max() ?? -1) + 1
        days[dayIndex].items.append(
            PlanItem(
                title: cleanText,
                city: draft.city,
                category: draft.category,
                period: Self.period(from: draft.startTime),
                startDate: draft.startDate,
                startTime: draft.startTime,
                endDate: draft.endDate,
                endTime: draft.endTime,
                sortIndex: nextIndex,
                needsTicket: draft.needsTicket,
                ticketBought: draft.ticketBought
            )
        )
        normalizeOrder(dayIndex: dayIndex)
    }

    func updateItem(dayID: Int, itemID: UUID, draft: PlanItemDraft) {
        let cleanText = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !cleanText.isEmpty,
            let dayIndex = dayIndex(containing: itemID),
            let itemIndex = days[dayIndex].items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }

        var item = days[dayIndex].items[itemIndex]
        item.title = cleanText
        item.city = draft.city
        item.category = draft.category
        item.period = Self.period(from: draft.startTime)
        item.startDate = draft.startDate
        item.startTime = draft.startTime
        item.endDate = draft.endDate
        item.endTime = draft.endTime
        item.needsTicket = draft.needsTicket
        item.ticketBought = draft.needsTicket && draft.ticketBought

        let targetIndex = targetDayIndex(defaultDayID: dayID, date: draft.startDate) ?? dayIndex
        if targetIndex == dayIndex {
            days[dayIndex].items[itemIndex] = item
        } else {
            days[dayIndex].items.remove(at: itemIndex)
            days[targetIndex].items.append(item)
            normalizeOrder(dayIndex: targetIndex)
        }
        normalizeOrder(dayIndex: dayIndex)
    }

    func deleteItem(dayID: Int, itemID: UUID) {
        guard let dayIndex = dayIndex(containing: itemID) else {
            return
        }

        days[dayIndex].items.removeAll { $0.id == itemID }
        normalizeOrder(dayIndex: dayIndex)
    }

    func moveItem(dayID: Int, draggedID: UUID, targetID: UUID) {
        guard
            let dayIndex = days.firstIndex(where: { $0.id == dayID }),
            let draggedIndex = days[dayIndex].items.firstIndex(where: { $0.id == draggedID }),
            let targetIndex = days[dayIndex].items.firstIndex(where: { $0.id == targetID }),
            draggedIndex != targetIndex
        else {
            return
        }

        let item = days[dayIndex].items.remove(at: draggedIndex)
        let adjustedTarget = draggedIndex < targetIndex ? targetIndex - 1 : targetIndex
        days[dayIndex].items.insert(item, at: adjustedTarget)
        normalizeOrder(dayIndex: dayIndex)
    }

    func scheduleItem(dayID: Int, itemID: UUID, hour: Int?) {
        guard
            let dayIndex = days.firstIndex(where: { $0.id == dayID }),
            let itemIndex = days[dayIndex].items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }

        if let hour {
            let date = dateForTimelineHour(dayID: dayID, hour: hour)
            days[dayIndex].items[itemIndex].startDate = date
            days[dayIndex].items[itemIndex].startTime = String(format: "%02d:00", hour)
            days[dayIndex].items[itemIndex].endDate = date
            days[dayIndex].items[itemIndex].endTime = ""
            days[dayIndex].items[itemIndex].period = Self.period(for: hour)
        } else {
            days[dayIndex].items[itemIndex].startTime = ""
            days[dayIndex].items[itemIndex].endTime = ""
            days[dayIndex].items[itemIndex].period = nil
        }
    }

    func scheduleItem(dayID: Int, itemID: UUID, period: String) {
        guard
            let dayIndex = days.firstIndex(where: { $0.id == dayID }),
            let itemIndex = days[dayIndex].items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }

        days[dayIndex].items[itemIndex].startTime = ""
        days[dayIndex].items[itemIndex].endTime = ""
        days[dayIndex].items[itemIndex].period = period
    }

    func dayDate(for dayID: Int) -> String {
        days.first { $0.id == dayID }?.date ?? ""
    }

    func defaultDate(for dayID: Int) -> String {
        days.first { $0.id == dayID }?.date ?? (days.first?.date ?? "")
    }

    func nextDayDate(after dayID: Int) -> String? {
        guard let index = days.firstIndex(where: { $0.id == dayID }) else {
            return nil
        }

        return days.indices.contains(index + 1) ? days[index + 1].date : nil
    }

    func dateForTimelineHour(dayID: Int, hour: Int) -> String {
        return dayDate(for: dayID)
    }

    func visibleSegment(for item: PlanItem, on dayDate: String, hourHeight: Double) -> TimelineSegment? {
        guard
            let itemStart = absoluteMinutes(date: item.startDate, time: item.startTime),
            let itemEnd = normalizedEndMinutes(for: item),
            let dayStart = dayStartMinutes(for: dayDate),
            let dayEnd = dayEndMinutes(for: dayDate)
        else {
            return nil
        }

        guard itemEnd > dayStart, itemStart < dayEnd else {
            return nil
        }

        let visibleStart = max(itemStart, dayStart)
        let visibleEnd = min(itemEnd, dayEnd)
        let top = Double(visibleStart - dayStart) / 60 * hourHeight
        let height = Double(visibleEnd - visibleStart) / 60 * hourHeight

        return TimelineSegment(top: top, height: max(44, height))
    }

    private func dayIndex(containing itemID: UUID) -> Int? {
        days.firstIndex { day in
            day.items.contains { $0.id == itemID }
        }
    }

    private func targetDayIndex(defaultDayID: Int, date: String) -> Int? {
        if !date.isEmpty, let index = days.firstIndex(where: { $0.date == date }) {
            return index
        }

        return days.firstIndex(where: { $0.id == defaultDayID })
    }

    private func normalizeOrder(dayIndex: Int) {
        for index in days[dayIndex].items.indices {
            days[dayIndex].items[index].sortIndex = index
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(days) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)

        if activeTripID == TripCatalogStore.defaultTripID {
            SharedTripDefaults.saveEuropeDays(days)
        }
    }

    private func syncDays(with fallbackDays: [TripDay]) {
        guard !days.isEmpty else {
            days = fallbackDays
            return
        }

        var savedByKey: [String: TripDay] = [:]
        for day in days {
            savedByKey[day.date] = day
            if let dateKey = day.dateKey {
                savedByKey[dateKey] = day
            }
        }
        let synced = fallbackDays.map { fallbackDay in
            let key = fallbackDay.dateKey ?? fallbackDay.date
            var day = savedByKey[key] ?? fallbackDay
            day.id = fallbackDay.id
            day.date = fallbackDay.date
            day.dateKey = fallbackDay.dateKey
            day.weekday = fallbackDay.weekday
            day.dayOfMonth = fallbackDay.dayOfMonth
            if day.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                day.city = fallbackDay.city
            }
            return day
        }

        if synced != days {
            days = synced
        }
    }

    nonisolated static func hour(from value: String) -> Int? {
        guard let minutes = minutes(from: value) else {
            return nil
        }

        return minutes / 60
    }

    nonisolated static func minuteInHour(from value: String) -> Int {
        guard let minutes = minutes(from: value) else {
            return 0
        }

        return minutes % 60
    }

    func durationMinutes(for item: PlanItem) -> Int {
        guard let startMinutes = TripStore.minutes(from: item.startTime) else {
            return 60
        }

        guard let endMinutes = TripStore.minutes(from: item.endTime) else {
            return 60
        }

        let startDateIndex = dateIndex(for: item.startDate)
        let endDateIndex = dateIndex(for: item.endDate.isEmpty ? item.startDate : item.endDate)
        let dayDelta = max(0, endDateIndex - startDateIndex)
        let duration = dayDelta * 24 * 60 + endMinutes - startMinutes

        if duration > 0 {
            return duration
        }

        return 60
    }

    func dateIndex(for date: String) -> Int {
        days.firstIndex { day in
            day.date == date || day.dateKey == date
        } ?? 0
    }

    func absoluteMinutes(date: String, time: String) -> Int? {
        guard let minutes = TripStore.minutes(from: time) else {
            return nil
        }

        return dateIndex(for: date) * 24 * 60 + minutes
    }

    func normalizedEndMinutes(for item: PlanItem) -> Int? {
        guard let start = absoluteMinutes(date: item.startDate, time: item.startTime) else {
            return nil
        }

        guard let endTimeMinutes = TripStore.minutes(from: item.endTime) else {
            return start + 60
        }

        let rawEndDate = item.endDate.isEmpty ? item.startDate : item.endDate
        var end = dateIndex(for: rawEndDate) * 24 * 60 + endTimeMinutes
        if end <= start {
            end += 24 * 60
        }

        return end
    }

    func item(_ item: PlanItem, intersectsFrom visibleStart: Int, to visibleEnd: Int) -> Bool {
        guard let start = absoluteMinutes(date: item.startDate, time: item.startTime) else {
            return false
        }

        let end = normalizedEndMinutes(for: item) ?? (start + 60)
        return end > visibleStart && start < visibleEnd
    }

    private func dayStartMinutes(for date: String) -> Int? {
        dateIndex(for: date) * TimelineLayout.minutesPerDay
    }

    private func dayEndMinutes(for date: String) -> Int? {
        dayStartMinutes(for: date).map { $0 + TimelineLayout.minutesPerDay }
    }

    private func activeDayStartMinutes(for date: String) -> Int? {
        dayStartMinutes(for: date).map { $0 + TimelineLayout.activeDayStartHour * 60 }
    }

    private func activeDayEndMinutes(for date: String) -> Int? {
        activeDayStartMinutes(for: date).map { $0 + TimelineLayout.activeDayMinutes }
    }

    nonisolated static func days(for trip: TravelTrip) -> [TripDay] {
        if trip.id == TripCatalogStore.defaultTripID {
            return ItineraryData.days
        }

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: min(trip.startDate, trip.endDate))
        let end = calendar.startOfDay(for: max(trip.startDate, trip.endDate))
        let dayCount = min(370, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ru_RU")
        displayFormatter.dateFormat = "d MMMM"
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "ru_RU")
        weekdayFormatter.dateFormat = "EE"
        let keyFormatter = DateFormatter()
        keyFormatter.calendar = calendar
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let cities = trip.cities.isEmpty ? ["Город"] : trip.cities

        return (0..<max(1, dayCount)).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: start) else {
                return nil
            }

            let cityIndex = min(cities.count - 1, index * cities.count / max(1, dayCount))
            return TripDay(
                id: index,
                date: displayFormatter.string(from: date),
                dateKey: keyFormatter.string(from: date),
                city: cities[cityIndex],
                weekday: weekdayFormatter.string(from: date),
                dayOfMonth: calendar.component(.day, from: date),
                items: []
            )
        }
    }

    nonisolated static func period(for hour: Int) -> String {
        switch hour {
        case 6..<12:
            return "Утро"
        case 12..<17:
            return "День"
        case 17..<22:
            return "Вечер"
        default:
            return "Ночь"
        }
    }

    nonisolated static func period(from time: String) -> String? {
        guard let hour = hour(from: time) else {
            return nil
        }

        return period(for: hour)
    }

    nonisolated static func minutes(from value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard
            parts.count == 2,
            let hours = Int(parts[0]),
            let minutes = Int(parts[1]),
            (0...23).contains(hours),
            (0...59).contains(minutes)
        else {
            return nil
        }

        return hours * 60 + minutes
    }

    nonisolated static func normalizedTimeInput(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard
            (1...2).contains(parts.count),
            let hours = Int(parts[0]),
            (0...23).contains(hours)
        else {
            return nil
        }

        let minutes: Int
        if parts.count == 2 {
            guard
                let parsedMinutes = Int(parts[1]),
                (0...59).contains(parsedMinutes)
            else {
                return nil
            }
            minutes = parsedMinutes
        } else {
            minutes = 0
        }

        return String(format: "%02d:%02d", hours, minutes)
    }
}

struct PlanItemDraft {
    var title: String
    var city: String
    var category: PlanCategory
    var startDate: String
    var startTime: String
    var endDate: String
    var endTime: String
    var needsTicket: Bool
    var ticketBought: Bool
}

struct TravelTrip: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var cities: [String]
    var participants: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case cities
        case participants
    }

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        cities: [String],
        participants: [String] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.cities = cities
        self.participants = participants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        cities = try container.decode([String].self, forKey: .cities)
        participants = try container.decodeIfPresent([String].self, forKey: .participants) ?? []
    }
}

@MainActor
final class TripCatalogStore: ObservableObject {
    @Published var trips: [TravelTrip] {
        didSet {
            save()
        }
    }

    private let storageKey = "trip.catalog.v2"
    nonisolated static let defaultTripID = UUID(uuidString: "7A835DF2-A238-4C4B-9F36-5DA11A42B40E")!

    init() {
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([TravelTrip].self, from: data)
        {
            trips = Self.normalizedTrips(decoded)
            if trips != decoded {
                save()
            }
        } else {
            trips = [Self.defaultTrip]
        }
    }

    func add(_ trip: TravelTrip) {
        trips.insert(trip, at: 0)
    }

    func update(_ trip: TravelTrip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else {
            return
        }

        trips[index] = trip
    }

    func delete(_ trip: TravelTrip) {
        trips.removeAll { $0.id == trip.id }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(trips) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private nonisolated static func normalizedTrips(_ trips: [TravelTrip]) -> [TravelTrip] {
        var normalized = trips
        guard let defaultIndex = normalized.firstIndex(where: { trip in
            trip.title == ItineraryData.tripTitle && trip.cities == TripStore.cities
        }) else {
            return normalized
        }

        normalized[defaultIndex].id = defaultTripID
        return normalized
    }

    nonisolated static var defaultTrip: TravelTrip {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3)) ?? Date()
        let end = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21)) ?? start

        return TravelTrip(
            id: defaultTripID,
            title: ItineraryData.tripTitle,
            startDate: start,
            endDate: end,
            cities: TripStore.cities,
            participants: ["Алиса", "Яна", "Уля", "Маша"]
        )
    }
}

enum ExpenseCurrency: String, Codable, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case rub = "RUB"
    case kzt = "KZT"
    case jpy = "JPY"

    var id: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .eur:
            return "EUR"
        case .usd:
            return "USD"
        case .rub:
            return "RUB"
        case .kzt:
            return "KZT"
        case .jpy:
            return "JPY"
        }
    }
}

struct ExpenseItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var tripID: UUID?
    var participantName: String?
    var involvedParticipantNames: [String]?
    var title: String
    var amount: Double
    var currency: ExpenseCurrency
    var createdAt: Date = Date()

    func involvedParticipants(from tripParticipants: [String]) -> [String] {
        let participantSet = Set(tripParticipants)
        let rawParticipants = involvedParticipantNames ?? tripParticipants
        var seenParticipants = Set<String>()

        return rawParticipants
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && participantSet.contains($0) }
            .filter { seenParticipants.insert($0).inserted }
    }
}

struct ExpenseBalance: Identifiable, Equatable {
    var id: String {
        "\(participantName)-\(currency.rawValue)"
    }

    let participantName: String
    let currency: ExpenseCurrency
    let paid: Double
    let share: Double
    let balance: Double
}

struct ExpenseSettlement: Identifiable, Equatable {
    var id: String {
        "\(from)-\(to)-\(currency.rawValue)-\(amount)"
    }

    let from: String
    let to: String
    let amount: Double
    let currency: ExpenseCurrency
}

struct ExpenseSplitSummary: Equatable {
    let balances: [ExpenseBalance]
    let settlements: [ExpenseSettlement]
    let ignoredExpenseCount: Int

    var hasParticipants: Bool {
        !balances.isEmpty
    }

    var hasSettlements: Bool {
        !settlements.isEmpty
    }
}

@MainActor
final class ExpenseStore: ObservableObject {
    @Published var expenses: [ExpenseItem] {
        didSet {
            saveExpenses()
        }
    }
    @Published var rates: [ExpenseCurrency: Double] = [.rub: 1]
    @Published var ratesDate: String?
    @Published var isLoadingRates = false
    @Published var ratesError: String?

    private let expensesKey = "trip.expenses.v2"
    private let ratesKey = "trip.expense.rates.v1"
    private let ratesDateKey = "trip.expense.rates.date.v1"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: expensesKey),
            let decoded = try? JSONDecoder().decode([ExpenseItem].self, from: data)
        {
            expenses = decoded.isEmpty ? Self.demoExpenses : decoded
        } else {
            expenses = Self.demoExpenses
        }

        loadCachedRates()
    }

    private nonisolated static var demoExpenses: [ExpenseItem] {
        [
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Алиса",
                involvedParticipantNames: ["Алиса", "Яна", "Уля", "Маша"],
                title: "Апартаменты в Барселоне",
                amount: 620,
                currency: .eur,
                createdAt: demoDate(day: 4, hour: 12)
            ),
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Яна",
                involvedParticipantNames: ["Алиса", "Яна", "Уля", "Маша"],
                title: "Билеты в Саграду",
                amount: 104,
                currency: .eur,
                createdAt: demoDate(day: 5, hour: 13)
            ),
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Уля",
                involvedParticipantNames: ["Алиса", "Уля", "Маша"],
                title: "Такси из аэропорта",
                amount: 48,
                currency: .eur,
                createdAt: demoDate(day: 7, hour: 11)
            ),
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Маша",
                involvedParticipantNames: ["Алиса", "Яна", "Уля", "Маша"],
                title: "Ужин тапасами",
                amount: 156,
                currency: .eur,
                createdAt: demoDate(day: 4, hour: 21)
            ),
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Алиса",
                involvedParticipantNames: ["Алиса", "Яна"],
                title: "Кофе и завтраки",
                amount: 38,
                currency: .eur,
                createdAt: demoDate(day: 8, hour: 10)
            ),
            ExpenseItem(
                tripID: TripCatalogStore.defaultTripID,
                participantName: "Яна",
                involvedParticipantNames: ["Алиса", "Яна", "Уля", "Маша"],
                title: "Страховка",
                amount: 7200,
                currency: .rub,
                createdAt: demoDate(day: 3, hour: 16)
            )
        ]
    }

    private nonisolated static func demoDate(day: Int, hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour)) ?? Date()
    }

    func expenses(for tripID: UUID) -> [ExpenseItem] {
        expenses.filter { $0.tripID == tripID || ($0.tripID == nil && tripID == TripCatalogStore.defaultTripID) }
    }

    func expenses(for tripID: UUID, participantName: String?) -> [ExpenseItem] {
        let participant = participantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tripExpenses = expenses(for: tripID)

        guard let participant, !participant.isEmpty else {
            return tripExpenses
        }

        return tripExpenses.filter { $0.participantName == participant }
    }

    func totalsByCurrency(for tripID: UUID, participantName: String? = nil) -> [ExpenseCurrency: Double] {
        Dictionary(grouping: expenses(for: tripID, participantName: participantName), by: \.currency)
            .mapValues { items in
                items.reduce(0) { $0 + $1.amount }
            }
    }

    func totalInRubles(for tripID: UUID, participantName: String? = nil) -> Double? {
        expenses(for: tripID, participantName: participantName).reduce(Double?.some(0)) { partialTotal, item in
            guard
                let partialTotal,
                let rate = rates[item.currency]
            else {
                return nil
            }

            return partialTotal + item.amount * rate
        }
    }

    func splitSummary(for trip: TravelTrip) -> ExpenseSplitSummary {
        var seenParticipants = Set<String>()
        let participants = trip.participants
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seenParticipants.insert($0).inserted }

        guard !participants.isEmpty else {
            return ExpenseSplitSummary(balances: [], settlements: [], ignoredExpenseCount: 0)
        }

        let participantSet = Set(participants)
        let tripExpenses = expenses(for: trip.id)
        let sharedExpenses = tripExpenses.filter { expense in
            guard let payer = expense.participantName else {
                return false
            }

            return participantSet.contains(payer) && !expense.involvedParticipants(from: participants).isEmpty
        }
        let ignoredExpenseCount = tripExpenses.count - sharedExpenses.count

        var balancesByCurrency: [ExpenseCurrency: [String: ExpenseBalanceDraft]] = [:]
        for currency in ExpenseCurrency.allCases {
            balancesByCurrency[currency] = Dictionary(
                uniqueKeysWithValues: participants.map { participant in
                    (participant, ExpenseBalanceDraft(paid: 0, share: 0))
                }
            )
        }

        for expense in sharedExpenses {
            guard var currencyBalances = balancesByCurrency[expense.currency] else {
                continue
            }

            let involvedParticipants = expense.involvedParticipants(from: participants)
            let share = expense.amount / Double(involvedParticipants.count)
            for participant in involvedParticipants {
                currencyBalances[participant, default: ExpenseBalanceDraft(paid: 0, share: 0)].share += share
            }

            if let payer = expense.participantName {
                currencyBalances[payer, default: ExpenseBalanceDraft(paid: 0, share: 0)].paid += expense.amount
            }

            balancesByCurrency[expense.currency] = currencyBalances
        }

        let balances = ExpenseCurrency.allCases.flatMap { currency in
            participants.compactMap { participant -> ExpenseBalance? in
                guard let draft = balancesByCurrency[currency]?[participant] else {
                    return nil
                }

                let balance = draft.paid - draft.share
                guard draft.paid > 0 || draft.share > 0 || abs(balance) >= 0.005 else {
                    return nil
                }

                return ExpenseBalance(
                    participantName: participant,
                    currency: currency,
                    paid: draft.paid,
                    share: draft.share,
                    balance: balance
                )
            }
        }

        let settlements = ExpenseCurrency.allCases.flatMap { currency in
            settlementsForCurrency(
                currency,
                balances: participants.compactMap { participant in
                    guard let draft = balancesByCurrency[currency]?[participant] else {
                        return nil
                    }

                    return (participant, draft.paid - draft.share)
                }
            )
        }

        return ExpenseSplitSummary(
            balances: balances,
            settlements: settlements,
            ignoredExpenseCount: ignoredExpenseCount
        )
    }

    func addExpense(
        title: String,
        amount: Double,
        currency: ExpenseCurrency,
        tripID: UUID,
        participantName: String,
        involvedParticipantNames: [String]?
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanParticipant = participantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanParticipant.isEmpty else {
            return
        }

        let cleanInvolvedParticipants = involvedParticipantNames?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        expenses.insert(
            ExpenseItem(
                tripID: tripID,
                participantName: cleanParticipant,
                involvedParticipantNames: cleanInvolvedParticipants?.isEmpty == false ? cleanInvolvedParticipants : nil,
                title: cleanTitle.isEmpty ? "Трата" : cleanTitle,
                amount: amount,
                currency: currency
            ),
            at: 0
        )
    }

    func deleteExpense(_ expense: ExpenseItem) {
        expenses.removeAll { $0.id == expense.id }
    }

    func refreshRates() async {
        isLoadingRates = true
        ratesError = nil

        defer {
            isLoadingRates = false
        }

        guard let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp") else {
            ratesError = "Не удалось открыть адрес ЦБ"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsed = try CBRRatesParser.parse(data: data)
            rates = parsed.rates
            ratesDate = parsed.date
            saveRates()
        } catch {
            ratesError = "Не удалось обновить курс"
        }
    }

    private func saveExpenses() {
        guard let data = try? JSONEncoder().encode(expenses) else {
            return
        }

        UserDefaults.standard.set(data, forKey: expensesKey)
    }

    private func loadCachedRates() {
        rates[.rub] = 1
        rates[.eur] = 100
        rates[.usd] = 92
        rates[.gbp] = 118
        rates[.turkishLira] = 2.8
        if
            let data = UserDefaults.standard.data(forKey: ratesKey),
            let decoded = try? JSONDecoder().decode([ExpenseCurrency: Double].self, from: data)
        {
            rates.merge(decoded) { _, cached in cached }
        }

        ratesDate = UserDefaults.standard.string(forKey: ratesDateKey)
    }

    private func saveRates() {
        guard let data = try? JSONEncoder().encode(rates) else {
            return
        }

        UserDefaults.standard.set(data, forKey: ratesKey)
        UserDefaults.standard.set(ratesDate, forKey: ratesDateKey)
    }

    private func settlementsForCurrency(_ currency: ExpenseCurrency, balances: [(name: String, balance: Double)]) -> [ExpenseSettlement] {
        var debtors = balances
            .filter { $0.balance < -0.005 }
            .map { (name: $0.name, amount: -$0.balance) }
            .sorted { $0.amount > $1.amount }
        var creditors = balances
            .filter { $0.balance > 0.005 }
            .map { (name: $0.name, amount: $0.balance) }
            .sorted { $0.amount > $1.amount }
        var settlements: [ExpenseSettlement] = []
        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(debtors[debtorIndex].amount, creditors[creditorIndex].amount)
            if amount >= 0.005 {
                settlements.append(
                    ExpenseSettlement(
                        from: debtors[debtorIndex].name,
                        to: creditors[creditorIndex].name,
                        amount: amount,
                        currency: currency
                    )
                )
            }

            debtors[debtorIndex].amount -= amount
            creditors[creditorIndex].amount -= amount

            if debtors[debtorIndex].amount < 0.005 {
                debtorIndex += 1
            }
            if creditors[creditorIndex].amount < 0.005 {
                creditorIndex += 1
            }
        }

        return settlements
    }
}

private struct ExpenseBalanceDraft {
    var paid: Double
    var share: Double
}

private struct ParsedCBRRates {
    let rates: [ExpenseCurrency: Double]
    let date: String?
}

private final class CBRRatesParser: NSObject, XMLParserDelegate {
    private var rates: [ExpenseCurrency: Double] = [.rub: 1]
    private var date: String?
    private var currentCode: String?
    private var currentNominal: Double = 1
    private var currentElement = ""
    private var currentValue = ""

    static func parse(data: Data) throws -> ParsedCBRRates {
        let delegate = CBRRatesParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "CBRRatesParser", code: 1)
        }

        return ParsedCBRRates(rates: delegate.rates, date: delegate.date)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""

        if elementName == "ValCurs" {
            date = attributeDict["Date"]
        }

        if elementName == "Valute" {
            currentCode = nil
            currentNominal = 1
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "CharCode":
            currentCode = trimmed
        case "Nominal":
            currentNominal = Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 1
        case "Value":
            guard
                let currentCode,
                let currency = ExpenseCurrency(rawValue: currentCode),
                currency != .rub,
                let value = Double(trimmed.replacingOccurrences(of: ",", with: "."))
            else {
                break
            }

            rates[currency] = value / max(currentNominal, 1)
        default:
            break
        }

        currentValue = ""
    }
}
