import SwiftUI

struct TripBackground: View {
    var body: some View {
        Color.white.ignoresSafeArea()
    }
}

enum AppColors {
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

func moneyString(_ value: Double, currency: ExpenseCurrency) -> String {
    let formatted = value.formatted(
        .number
            .precision(.fractionLength(0...2))
            .grouping(.automatic)
    )

    return "\(formatted) \(currency.symbol)"
}

func rubleString(_ value: Double) -> String {
    let formatted = value.formatted(
        .number
            .precision(.fractionLength(0...2))
            .grouping(.automatic)
    )

    return "\(formatted) RUB"
}

func tripDateRangeString(start: Date, end: Date) -> String {
    let startText = start.formatted(.dateTime.day().month(.wide).year())
    let endText = end.formatted(.dateTime.day().month(.wide).year())
    return "\(startText) - \(endText)"
}

struct TripProgress: Equatable {
    let elapsedDays: Int
    let totalDays: Int

    var fraction: Double {
        guard totalDays > 0, elapsedDays > 0 else {
            return 0
        }

        return min(Double(elapsedDays) / Double(totalDays), 1)
    }

    var label: String {
        "\(elapsedDays) из \(totalDays) дн."
    }

    static func make(start: Date, end: Date, today: Date = Date(), calendar: Calendar = .current) -> TripProgress {
        let startOfTrip = calendar.startOfDay(for: start)
        let endOfTrip = calendar.startOfDay(for: end)
        let currentDay = calendar.startOfDay(for: today)
        let normalizedEnd = max(startOfTrip, endOfTrip)
        let totalDays = (calendar.dateComponents([.day], from: startOfTrip, to: normalizedEnd).day ?? 0) + 1

        guard currentDay >= startOfTrip else {
            return TripProgress(elapsedDays: 0, totalDays: totalDays)
        }

        let cappedCurrentDay = min(currentDay, normalizedEnd)
        let elapsedDays = (calendar.dateComponents([.day], from: startOfTrip, to: cappedCurrentDay).day ?? 0) + 1
        return TripProgress(elapsedDays: min(max(elapsedDays, 0), totalDays), totalDays: totalDays)
    }
}

struct TripProgressBar: View {
    let trip: TravelTrip

    private var progress: TripProgress {
        TripProgress.make(start: trip.startDate, end: trip.endDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Spacer(minLength: 8)

                Text(progress.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress.elapsedDays == 0 ? AppColors.faint : AppColors.accent)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.placeholder)

                    if progress.fraction > 0 {
                        Capsule()
                            .fill(AppColors.accent)
                            .frame(width: max(proxy.size.width * progress.fraction, 6))
                    }
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Прогресс поездки: \(progress.label)")
    }
}
