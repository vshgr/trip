import SwiftUI
import WidgetKit

struct TripWidgetEntry: TimelineEntry {
    let date: Date
    let status: WidgetTripStatus
}

struct TripWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TripWidgetEntry {
        TripWidgetEntry(date: Date(), status: WidgetTripStatus(days: widgetDays))
    }

    func getSnapshot(in context: Context, completion: @escaping (TripWidgetEntry) -> Void) {
        completion(TripWidgetEntry(date: Date(), status: WidgetTripStatus(days: widgetDays)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripWidgetEntry>) -> Void) {
        let now = Date()
        let entry = TripWidgetEntry(date: now, status: WidgetTripStatus(days: widgetDays, today: now))
        let nextRefresh = Calendar(identifier: .gregorian).date(byAdding: .hour, value: 6, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private var widgetDays: [TripDay] {
        SharedTripDefaults.loadEuropeDays() ?? ItineraryData.days
    }
}

struct TripWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TripWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .containerBackground(.white, for: .widget)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                markerIcon

                Text("Следующий город")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                daysPill
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.status.nextCityTitle)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)

                Text(entry.status.nextCityDetail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)
            }

            progressBar

            Divider()
                .padding(.vertical, 1)

            nextPlanBlock

            Spacer(minLength: 0)
        }
        .padding(13)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                markerIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.status.nextCityTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .layoutPriority(1)

                    Text(entry.status.nextCityDetail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetColors.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                daysPill
            }

            progressBar

            Divider()

            nextPlanBlock
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
    }

    private var markerIcon: some View {
        Image(systemName: "location.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(WidgetColors.accent, in: Circle())
    }

    private var daysPill: some View {
        Text(entry.status.daysUntilNextCityText)
            .font(.caption.weight(.heavy))
            .foregroundStyle(WidgetColors.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(WidgetColors.accentSoft, in: Capsule())
    }

    private var nextPlanBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: entry.status.nextPlanSystemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetColors.accent)

                Text(entry.status.nextPlanDayTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
            }

            Text(entry.status.nextPlanDetail)
                .font((family == .systemMedium ? Font.caption : Font.caption2).weight(.semibold))
                .foregroundStyle(WidgetColors.muted)
                .lineLimit(family == .systemMedium ? 2 : 3)
                .minimumScaleFactor(0.82)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(entry.status.routeProgressText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(entry.status.tripDatesText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WidgetColors.line)

                    Capsule()
                        .fill(WidgetColors.accent)
                        .frame(width: max(8, proxy.size.width * entry.status.routeProgressFraction))
                }
            }
            .frame(height: 5)
        }
    }

    private var routeFooter: some View {
        HStack(spacing: 5) {
            Image(systemName: "map")
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetColors.accent)

            Text(entry.status.routeSummary)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetColors.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

}

struct TripWidget: Widget {
    let kind = "TripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripWidgetProvider()) { entry in
            TripWidgetView(entry: entry)
        }
        .configurationDisplayName("Europe Trip")
        .description("Дни до следующего города и ближайший план поездки.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct TripWidgetBundle: WidgetBundle {
    var body: some Widget {
        TripWidget()
    }
}

struct WidgetTripStatus {
    let days: [TripDay]
    let today: Date
    private let calendar = Calendar(identifier: .gregorian)

    init(days: [TripDay], today: Date = Date()) {
        self.days = days
        self.today = Calendar(identifier: .gregorian).startOfDay(for: today)
    }

    var nextCityTitle: String {
        nextCity?.day.city ?? "Маршрут завершён"
    }

    var daysUntilNextCityText: String {
        guard let nextCity else {
            return "0 дней"
        }

        return dayCountText(daysUntil(nextCity.date))
    }

    var nextCityDetail: String {
        guard let nextCity else {
            return "Новых городов больше нет"
        }

        return "\(nextCity.day.date), \(nextCity.day.weekday)"
    }

    var nextPlanDayTitle: String {
        nextPlan?.day.date ?? "Нет планов"
    }

    var nextPlanDetail: String {
        guard let nextPlan else {
            return "В ближайших днях пока пусто"
        }

        return "\(nextPlan.item.timeLabel): \(nextPlan.item.title)"
    }

    var nextPlanSystemImage: String {
        nextPlan?.item.category.systemImage ?? "list.bullet"
    }

    var routeProgressText: String {
        guard !datedDays.isEmpty else {
            return "Маршрут"
        }

        return "\(completedDayCount)/\(datedDays.count) дней"
    }

    var routeProgressFraction: Double {
        guard !datedDays.isEmpty else {
            return 0
        }

        return min(1, max(0, Double(completedDayCount) / Double(datedDays.count)))
    }

    var tripDatesText: String {
        guard let first = datedDays.first?.day.date, let last = datedDays.last?.day.date else {
            return "Даты"
        }

        return "\(first)-\(last)"
    }

    var routeSummary: String {
        let cities = uniqueCities
        guard let first = cities.first, let last = cities.last, first != last else {
            return cities.first ?? "Маршрут"
        }

        return "\(first) -> \(last)"
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

    private var completedDayCount: Int {
        datedDays.filter { $0.date < today }.count
    }

    private var uniqueCities: [String] {
        days.map(\.city).reduce(into: [String]()) { result, city in
            if result.last != city {
                result.append(city)
            }
        }
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

private enum WidgetColors {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.18)
    static let muted = Color(red: 0.38, green: 0.40, blue: 0.46)
    static let accent = Color(red: 0.86, green: 0.20, blue: 0.25)
    static let accentSoft = Color(red: 0.99, green: 0.90, blue: 0.91)
    static let line = Color(red: 0.91, green: 0.92, blue: 0.94)
}
