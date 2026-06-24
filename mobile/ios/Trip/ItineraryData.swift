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
            PlanItem(title: "Оставить вещи в отеле", city: "Барселона", category: .rest, period: nil, startDate: "4 июля", startTime: "09:00", endDate: "4 июля", endTime: "09:45", sortIndex: 0),
            PlanItem(title: "Passeig de Gracia, площадь Каталонии и Рамбла", city: "Барселона", category: .walk, period: nil, startDate: "4 июля", startTime: "11:00", endDate: "4 июля", endTime: "14:00", sortIndex: 1),
            PlanItem(title: "Casa Batllo", city: "Барселона", category: .sight, period: nil, startDate: "4 июля", startTime: "17:30", endDate: "4 июля", endTime: "19:00", sortIndex: 2, needsTicket: true, ticketBought: true),
            PlanItem(title: "Ужин тапасами", city: "Барселона", category: .food, period: nil, startDate: "4 июля", startTime: "20:30", endDate: "4 июля", endTime: "22:00", sortIndex: 3)
        ]),
        TripDay(id: 2, date: "5 июля", dateKey: "2026-07-05", city: "Барселона", weekday: "вс", dayOfMonth: 5, items: [
            PlanItem(title: "Госпиталь Сан-Пау", city: "Барселона", category: .sight, period: nil, startDate: "5 июля", startTime: "10:00", endDate: "5 июля", endTime: "11:30", sortIndex: 0, needsTicket: true),
            PlanItem(title: "Саграда Фамилия", city: "Барселона", category: .sight, period: nil, startDate: "5 июля", startTime: "13:00", endDate: "5 июля", endTime: "15:00", sortIndex: 1, needsTicket: true, ticketBought: true),
            PlanItem(title: "Тибидабо и закат", city: "Барселона", category: .sight, period: nil, startDate: "5 июля", startTime: "17:30", endDate: "5 июля", endTime: "21:30", sortIndex: 2)
        ]),
        TripDay(id: 3, date: "6 июля", dateKey: "2026-07-06", city: "Барселона", weekday: "пн", dayOfMonth: 6, items: [
            PlanItem(title: "Поездка в Блейнс", city: "Барселона", category: .transfer, period: nil, startDate: "6 июля", startTime: "10:30", endDate: "6 июля", endTime: "13:00", sortIndex: 0),
            PlanItem(title: "Встреча с друзьями", city: "Барселона", category: .rest, period: nil, startDate: "6 июля", startTime: "14:00", endDate: "6 июля", endTime: "16:30", sortIndex: 1),
            PlanItem(title: "Шоппинг и прогулка на Монжуик", city: "Барселона", category: .shopping, period: nil, startDate: "6 июля", startTime: "18:00", endDate: "6 июля", endTime: "20:00", sortIndex: 2)
        ]),
        TripDay(id: 4, date: "7 июля", dateKey: "2026-07-07", city: "Ибица", weekday: "вт", dayOfMonth: 7, items: [
            PlanItem(title: "Перелет на Ибицу", city: "Ибица", category: .transfer, period: nil, startDate: "7 июля", startTime: "09:30", endDate: "7 июля", endTime: "11:00", sortIndex: 0, needsTicket: true, ticketBought: true),
            PlanItem(title: "Пляж Cala Comte", city: "Ибица", category: .rest, period: nil, startDate: "7 июля", startTime: "15:00", endDate: "7 июля", endTime: "19:00", sortIndex: 1)
        ]),
        TripDay(id: 5, date: "8 июля", dateKey: "2026-07-08", city: "Ибица", weekday: "ср", dayOfMonth: 8, items: [
            PlanItem(title: "Завтрак у моря", city: "Ибица", category: .food, period: nil, startDate: "8 июля", startTime: "10:00", endDate: "8 июля", endTime: "11:00", sortIndex: 0),
            PlanItem(title: "Старый город Dalt Vila", city: "Ибица", category: .walk, period: nil, startDate: "8 июля", startTime: "17:00", endDate: "8 июля", endTime: "20:00", sortIndex: 1)
        ]),
        TripDay(id: 6, date: "9 июля", dateKey: "2026-07-09", city: "Ибица", weekday: "чт", dayOfMonth: 9, items: []),
        TripDay(id: 7, date: "10 июля", dateKey: "2026-07-10", city: "Ницца", weekday: "пт", dayOfMonth: 10, items: [
            PlanItem(title: "Перелет в Ниццу", city: "Ницца", category: .transfer, period: nil, startDate: "10 июля", startTime: "12:00", endDate: "10 июля", endTime: "14:00", sortIndex: 0, needsTicket: true),
            PlanItem(title: "Английская набережная", city: "Ницца", category: .walk, period: nil, startDate: "10 июля", startTime: "18:00", endDate: "10 июля", endTime: "20:00", sortIndex: 1)
        ]),
        TripDay(id: 8, date: "11 июля", dateKey: "2026-07-11", city: "Ницца", weekday: "сб", dayOfMonth: 11, items: [
            PlanItem(title: "Монако на полдня", city: "Ницца", category: .sight, period: nil, startDate: "11 июля", startTime: "10:00", endDate: "11 июля", endTime: "16:00", sortIndex: 0),
            PlanItem(title: "Ужин в старом городе", city: "Ницца", category: .food, period: nil, startDate: "11 июля", startTime: "20:00", endDate: "11 июля", endTime: "21:30", sortIndex: 1)
        ]),
        TripDay(id: 9, date: "12 июля", dateKey: "2026-07-12", city: "Ницца", weekday: "вс", dayOfMonth: 12, items: []),
        TripDay(id: 10, date: "13 июля", dateKey: "2026-07-13", city: "Париж", weekday: "пн", dayOfMonth: 13, items: [
            PlanItem(title: "Поезд в Париж", city: "Париж", category: .transfer, period: nil, startDate: "13 июля", startTime: "09:00", endDate: "13 июля", endTime: "14:30", sortIndex: 0, needsTicket: true, ticketBought: true),
            PlanItem(title: "Лувр", city: "Париж", category: .sight, period: nil, startDate: "13 июля", startTime: "16:30", endDate: "13 июля", endTime: "19:00", sortIndex: 1, needsTicket: true)
        ]),
        TripDay(id: 11, date: "14 июля", dateKey: "2026-07-14", city: "Париж", weekday: "вт", dayOfMonth: 14, items: [
            PlanItem(title: "Монмартр", city: "Париж", category: .walk, period: nil, startDate: "14 июля", startTime: "11:00", endDate: "14 июля", endTime: "14:00", sortIndex: 0),
            PlanItem(title: "Пикник у Эйфелевой башни", city: "Париж", category: .food, period: nil, startDate: "14 июля", startTime: "19:30", endDate: "14 июля", endTime: "22:00", sortIndex: 1)
        ]),
        TripDay(id: 12, date: "15 июля", dateKey: "2026-07-15", city: "Париж", weekday: "ср", dayOfMonth: 15, items: [
            PlanItem(title: "Версаль", city: "Париж", category: .sight, period: nil, startDate: "15 июля", startTime: "10:00", endDate: "15 июля", endTime: "17:00", sortIndex: 0, needsTicket: true)
        ]),
        TripDay(id: 13, date: "16 июля", dateKey: "2026-07-16", city: "Париж", weekday: "чт", dayOfMonth: 16, items: []),
        TripDay(id: 14, date: "17 июля", dateKey: "2026-07-17", city: "Брюссель", weekday: "пт", dayOfMonth: 17, items: [
            PlanItem(title: "Гранд-Плас и вафли", city: "Брюссель", category: .walk, period: nil, startDate: "17 июля", startTime: "12:00", endDate: "17 июля", endTime: "15:00", sortIndex: 0),
            PlanItem(title: "Музей Магритта", city: "Брюссель", category: .sight, period: nil, startDate: "17 июля", startTime: "16:00", endDate: "17 июля", endTime: "18:00", sortIndex: 1)
        ]),
        TripDay(id: 15, date: "18 июля", dateKey: "2026-07-18", city: "Брюссель", weekday: "сб", dayOfMonth: 18, items: [
            PlanItem(title: "Брюгге одним днем", city: "Брюссель", category: .transfer, period: nil, startDate: "18 июля", startTime: "09:30", endDate: "18 июля", endTime: "18:30", sortIndex: 0)
        ]),
        TripDay(id: 16, date: "19 июля", dateKey: "2026-07-19", city: "Амстердам", weekday: "вс", dayOfMonth: 19, items: [
            PlanItem(title: "Поезд в Амстердам", city: "Амстердам", category: .transfer, period: nil, startDate: "19 июля", startTime: "10:00", endDate: "19 июля", endTime: "13:00", sortIndex: 0, needsTicket: true),
            PlanItem(title: "Каналы и Jordaan", city: "Амстердам", category: .walk, period: nil, startDate: "19 июля", startTime: "16:00", endDate: "19 июля", endTime: "19:00", sortIndex: 1)
        ]),
        TripDay(id: 17, date: "20 июля", dateKey: "2026-07-20", city: "Амстердам", weekday: "пн", dayOfMonth: 20, items: [
            PlanItem(title: "Rijksmuseum", city: "Амстердам", category: .sight, period: nil, startDate: "20 июля", startTime: "11:00", endDate: "20 июля", endTime: "14:00", sortIndex: 0, needsTicket: true, ticketBought: true),
            PlanItem(title: "Прощальный ужин", city: "Амстердам", category: .food, period: nil, startDate: "20 июля", startTime: "20:00", endDate: "20 июля", endTime: "22:00", sortIndex: 1)
        ]),
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
