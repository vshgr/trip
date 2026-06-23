import SwiftUI

enum ItineraryData {
    static let tripTitle = "Europe Trip"
    static let tripDates = "3-21 июля"
    static let subtitle = "Барселона, Ибица, Ницца, Париж, Брюссель, Амстердам"

    static let stops: [TripStop] = [
        TripStop(city: "Барселона", status: .planned),
        TripStop(city: "Ибица", status: .upcoming),
        TripStop(city: "Ницца", status: .upcoming),
        TripStop(city: "Париж", status: .upcoming),
        TripStop(city: "Брюссель", status: .upcoming),
        TripStop(city: "Амстердам", status: .upcoming)
    ]

    static let days: [TripDay] = [
        TripDay(id: 0, date: "3 июля", dateKey: "2026-07-03", city: "Барселона", weekday: "пт", dayOfMonth: 3, items: [
            PlanItem(
                title: "Перелет в Барселону",
                city: "Барселона",
                category: .transfer,
                period: nil,
                startDate: "3 июля",
                startTime: "17:00",
                endDate: "4 июля",
                endTime: "07:00",
                sortIndex: 0
            )
        ]),
        TripDay(id: 1, date: "4 июля", dateKey: "2026-07-04", city: "Барселона", weekday: "сб", dayOfMonth: 4, items: [
            PlanItem(title: "Пробуем договориться с отелем и оставить у них вещи", city: "Барселона", category: .rest, period: "Утро", startDate: "4 июля", startTime: "", endDate: "4 июля", endTime: "", sortIndex: 0),
            PlanItem(title: "Passeig de Gracia, площадь Каталонии, Рамбла, Готический квартал", city: "Барселона", category: .walk, period: "День", startDate: "4 июля", startTime: "", endDate: "4 июля", endTime: "", sortIndex: 1),
            PlanItem(title: "Casa Batllo вечером, если будут силы", city: "Барселона", category: .sight, period: "Вечер", startDate: "4 июля", startTime: "", endDate: "4 июля", endTime: "", sortIndex: 2, needsTicket: true),
            PlanItem(title: "Ужин тапасами или ресторан, который хотела Уля", city: "Барселона", category: .food, period: "Вечер", startDate: "4 июля", startTime: "", endDate: "4 июля", endTime: "", sortIndex: 3)
        ]),
        TripDay(id: 2, date: "5 июля", dateKey: "2026-07-05", city: "Барселона", weekday: "вс", dayOfMonth: 5, items: [
            PlanItem(title: "Госпиталь Сан-Пау", city: "Барселона", category: .sight, period: "Утро", startDate: "5 июля", startTime: "", endDate: "5 июля", endTime: "", sortIndex: 0, needsTicket: true),
            PlanItem(title: "Саграда Фамилия", city: "Барселона", category: .sight, period: "День", startDate: "5 июля", startTime: "", endDate: "5 июля", endTime: "", sortIndex: 1, needsTicket: true),
            PlanItem(title: "Тибидабо: катаемся, чиллим и, возможно, встречаем закат", city: "Барселона", category: .sight, period: "Вечер", startDate: "5 июля", startTime: "", endDate: "5 июля", endTime: "", sortIndex: 2),
            PlanItem(title: "По силам: пошататься по Готике или посидеть в баре", city: "Барселона", category: .walk, period: "Вечер", startDate: "5 июля", startTime: "", endDate: "5 июля", endTime: "", sortIndex: 3)
        ]),
        TripDay(id: 3, date: "6 июля", dateKey: "2026-07-06", city: "Барселона", weekday: "пн", dayOfMonth: 6, items: [
            PlanItem(title: "Поездка в Блейнс", city: "Барселона", category: .transfer, period: "День", startDate: "6 июля", startTime: "", endDate: "6 июля", endTime: "", sortIndex: 0),
            PlanItem(title: "Встреча с друзьями, если получится по расписанию", city: "Барселона", category: .rest, period: "День", startDate: "6 июля", startTime: "", endDate: "6 июля", endTime: "", sortIndex: 1),
            PlanItem(title: "Шоппинг или прогулка на Монжуик", city: "Барселона", category: .shopping, period: "Вечер", startDate: "6 июля", startTime: "", endDate: "6 июля", endTime: "", sortIndex: 2)
        ]),
        TripDay(id: 4, date: "7 июля", dateKey: "2026-07-07", city: "Ибица", weekday: "вт", dayOfMonth: 7, items: []),
        TripDay(id: 5, date: "8 июля", dateKey: "2026-07-08", city: "Ибица", weekday: "ср", dayOfMonth: 8, items: []),
        TripDay(id: 6, date: "9 июля", dateKey: "2026-07-09", city: "Ибица", weekday: "чт", dayOfMonth: 9, items: []),
        TripDay(id: 7, date: "10 июля", dateKey: "2026-07-10", city: "Ницца", weekday: "пт", dayOfMonth: 10, items: []),
        TripDay(id: 8, date: "11 июля", dateKey: "2026-07-11", city: "Ницца", weekday: "сб", dayOfMonth: 11, items: []),
        TripDay(id: 9, date: "12 июля", dateKey: "2026-07-12", city: "Ницца", weekday: "вс", dayOfMonth: 12, items: []),
        TripDay(id: 10, date: "13 июля", dateKey: "2026-07-13", city: "Париж", weekday: "пн", dayOfMonth: 13, items: []),
        TripDay(id: 11, date: "14 июля", dateKey: "2026-07-14", city: "Париж", weekday: "вт", dayOfMonth: 14, items: []),
        TripDay(id: 12, date: "15 июля", dateKey: "2026-07-15", city: "Париж", weekday: "ср", dayOfMonth: 15, items: []),
        TripDay(id: 13, date: "16 июля", dateKey: "2026-07-16", city: "Париж", weekday: "чт", dayOfMonth: 16, items: []),
        TripDay(id: 14, date: "17 июля", dateKey: "2026-07-17", city: "Брюссель", weekday: "пт", dayOfMonth: 17, items: []),
        TripDay(id: 15, date: "18 июля", dateKey: "2026-07-18", city: "Брюссель", weekday: "сб", dayOfMonth: 18, items: []),
        TripDay(id: 16, date: "19 июля", dateKey: "2026-07-19", city: "Амстердам", weekday: "вс", dayOfMonth: 19, items: []),
        TripDay(id: 17, date: "20 июля", dateKey: "2026-07-20", city: "Амстердам", weekday: "пн", dayOfMonth: 20, items: []),
        TripDay(id: 18, date: "21 июля", dateKey: "2026-07-21", city: "Амстердам", weekday: "вт", dayOfMonth: 21, items: [])
    ]

}

enum CityColors {
    static let barcelona = Color(red: 0.95, green: 0.36, blue: 0.30)
    static let ibiza = Color(red: 0.12, green: 0.62, blue: 0.76)
    static let nice = Color(red: 0.18, green: 0.61, blue: 0.45)
    static let paris = Color(red: 0.43, green: 0.36, blue: 0.72)
    static let brussels = Color(red: 0.78, green: 0.53, blue: 0.20)
    static let amsterdam = Color(red: 0.82, green: 0.30, blue: 0.24)

    static func color(for city: String) -> Color {
        switch city {
        case "Барселона":
            return barcelona
        case "Ибица":
            return ibiza
        case "Ницца":
            return nice
        case "Париж":
            return paris
        case "Брюссель":
            return brussels
        case "Амстердам":
            return amsterdam
        default:
            return Color(red: 0.50, green: 0.52, blue: 0.58)
        }
    }
}
