import SwiftUI
import UIKit

struct ExpensesView: View {
    @ObservedObject var store: ExpenseStore
    let trip: TravelTrip
    @State private var section: ExpenseSection = .expenses
    @State private var title = ""
    @State private var amount = ""
    @State private var currency: ExpenseCurrency = .eur
    @State private var selectedParticipant = ""
    @State private var selectedInvolvedParticipants: Set<String> = []
    @State private var selectedFilterParticipant = ""
    @FocusState private var focusedField: ExpenseInputField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ExpenseSectionPicker(selection: $section)

                switch section {
                case .expenses:
                    expensesSection
                case .history:
                    historySection
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
            syncSelectedParticipant(with: trip.participants)
            syncInvolvedParticipants(with: trip.participants)
            await store.refreshRatesIfNeeded()
        }
        .onChange(of: trip.participants) { _, participants in
            syncSelectedParticipant(with: participants)
            if !participants.contains(selectedFilterParticipant) {
                selectedFilterParticipant = ""
            }
            syncInvolvedParticipants(with: participants)
        }
        .onChange(of: trip.id) { _, _ in
            selectedParticipant = trip.participants.first ?? ""
            selectedFilterParticipant = ""
            selectedInvolvedParticipants = Set(trip.participants)
        }
    }

    private var canAddExpense: Bool {
        parsedAmount != nil && trip.participants.contains(selectedParticipant) && !selectedInvolvedParticipants.isEmpty
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

    private var newExpenseSection: some View {
        ExpenseEntryView(
            title: $title,
            amount: $amount,
            currency: $currency,
            selectedParticipant: $selectedParticipant,
            selectedInvolvedParticipants: $selectedInvolvedParticipants,
            participants: trip.participants,
            focusedField: $focusedField,
            canAdd: canAddExpense
        ) {
            addExpense()
        }
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            newExpenseSection
            balanceSection
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExpenseTotalsView(
                store: store,
                tripID: trip.id,
                participantName: selectedFilterParticipant
            ) {
                Task {
                    await store.refreshRates()
                }
            }

            ExpenseSplitView(summary: store.splitSummary(for: trip), participantCount: trip.participants.count)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Text("История")
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
                    ExpenseRowView(expense: expense, tripParticipants: trip.participants) {
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

    private func addExpense() {
        guard let parsedAmount else {
            return
        }

        store.addExpense(
            title: title,
            amount: parsedAmount,
            currency: currency,
            tripID: trip.id,
            participantName: selectedParticipant,
            involvedParticipantNames: involvedParticipantNames
        )
        title = ""
        amount = ""
        selectedInvolvedParticipants = Set(trip.participants)
        dismissKeyboard()
    }

    private var involvedParticipantNames: [String]? {
        guard !trip.participants.isEmpty else {
            return nil
        }

        return trip.participants.filter { selectedInvolvedParticipants.contains($0) }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func syncInvolvedParticipants(with participants: [String]) {
        let participantSet = Set(participants)
        selectedInvolvedParticipants = selectedInvolvedParticipants.intersection(participantSet)
        if selectedInvolvedParticipants.isEmpty {
            selectedInvolvedParticipants = participantSet
        }
    }

    private func syncSelectedParticipant(with participants: [String]) {
        guard !participants.contains(selectedParticipant) else {
            return
        }

        selectedParticipant = participants.first ?? ""
    }
}

enum ExpenseSection: String, CaseIterable, Identifiable {
    case expenses
    case history

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .expenses:
            return "Обзор"
        case .history:
            return "История"
        }
    }
}

enum ExpenseInputField: Hashable {
    case title
    case amount
}

struct ExpenseSectionPicker: View {
    @Binding var selection: ExpenseSection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ExpenseSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selection == section ? Color.white : AppColors.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selection == section ? AppColors.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ExpenseParticipantFilter: View {
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

struct ParticipantChipSelector: View {
    let participants: [String]
    @Binding var selectedParticipant: String
    let allTitle: String?

    private var options: [String] {
        allTitle == nil ? participants : [""] + participants
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedParticipant = option
                    } label: {
                        Text(option.isEmpty ? (allTitle ?? "") : option)
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

struct MultiParticipantChipSelector: View {
    let participants: [String]
    @Binding var selectedParticipants: Set<String>
    let allTitle: String

    private var isAllSelected: Bool {
        !participants.isEmpty && selectedParticipants.isSuperset(of: participants)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    toggleAll()
                } label: {
                    Text(allTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isAllSelected ? Color.white : AppColors.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            isAllSelected ? AppColors.accent : AppColors.itemBackground,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)

                ForEach(participants, id: \.self) { participant in
                    let isSelected = selectedParticipants.contains(participant)
                    Button {
                        toggle(participant)
                    } label: {
                        Text(participant)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.white : AppColors.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? AppColors.accent : AppColors.itemBackground,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ participant: String) {
        if selectedParticipants.contains(participant) {
            selectedParticipants.remove(participant)
        } else {
            selectedParticipants.insert(participant)
        }
    }

    private func toggleAll() {
        if isAllSelected {
            selectedParticipants.removeAll()
        } else {
            selectedParticipants = Set(participants)
        }
    }
}

struct ExpenseEntryView: View {
    @Binding var title: String
    @Binding var amount: String
    @Binding var currency: ExpenseCurrency
    @Binding var selectedParticipant: String
    @Binding var selectedInvolvedParticipants: Set<String>
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
                    Text("Кто платил")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)

                    ParticipantChipSelector(
                        participants: participants,
                        selectedParticipant: $selectedParticipant,
                        allTitle: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Кто участвует")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)

                    MultiParticipantChipSelector(
                        participants: participants,
                        selectedParticipants: $selectedInvolvedParticipants,
                        allTitle: "Все"
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

struct ExpenseTotalsView: View {
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

struct ExpenseSplitView: View {
    let summary: ExpenseSplitSummary
    let participantCount: Int

    private var balancesByCurrency: [ExpenseBalanceCurrencyGroup] {
        ExpenseCurrency.allCases.compactMap { currency in
            let balances = summary.balances.filter { $0.currency == currency }
            return balances.isEmpty ? nil : ExpenseBalanceCurrencyGroup(currency: currency, balances: balances)
        }
    }

    private var settlementsByCurrency: [ExpenseSettlementCurrencyGroup] {
        ExpenseCurrency.allCases.compactMap { currency in
            let settlements = summary.settlements.filter { $0.currency == currency }
            return settlements.isEmpty ? nil : ExpenseSettlementCurrencyGroup(currency: currency, settlements: settlements)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Расчет между участниками")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.ink)

                Spacer()

                if participantCount > 0 {
                    Text("\(participantCount) чел.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                }
            }

            if participantCount < 2 {
                EmptyExpenseSplitMessage(text: "Добавьте хотя бы двух участников в поездку, чтобы посчитать кто кому должен.")
            } else if !summary.hasParticipants {
                EmptyExpenseSplitMessage(text: "Добавьте траты с плательщиком и участниками: сумма будет делиться поровну между выбранными людьми.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Кто кому переводит")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppColors.muted)

                    if settlementsByCurrency.isEmpty {
                        EmptyExpenseSplitMessage(text: "Все уже в балансе.")
                    } else {
                        ForEach(settlementsByCurrency) { group in
                            VStack(spacing: 6) {
                                ForEach(group.settlements) { settlement in
                                    ExpenseSettlementRow(settlement: settlement)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Баланс")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppColors.muted)

                    ForEach(balancesByCurrency) { group in
                        VStack(spacing: 6) {
                            HStack {
                                Text(group.currency.symbol)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(AppColors.muted)
                                Spacer()
                            }

                            ForEach(group.balances) { balance in
                                ExpenseBalanceRow(balance: balance)
                            }
                        }
                    }
                }

                if summary.ignoredExpenseCount > 0 {
                    Text("Старых трат без плательщика не учтено: \(summary.ignoredExpenseCount)")
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

struct ExpenseBalanceCurrencyGroup: Identifiable {
    var id: ExpenseCurrency {
        currency
    }

    let currency: ExpenseCurrency
    let balances: [ExpenseBalance]
}

struct ExpenseSettlementCurrencyGroup: Identifiable {
    var id: ExpenseCurrency {
        currency
    }

    let currency: ExpenseCurrency
    let settlements: [ExpenseSettlement]
}

struct EmptyExpenseSplitMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ExpenseSettlementRow: View {
    let settlement: ExpenseSettlement

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, height: 28)
                .background(AppColors.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(settlement.from) -> \(settlement.to)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("перевод")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
            }

            Spacer(minLength: 8)

            Text(moneyString(settlement.amount, currency: settlement.currency))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ExpenseBalanceRow: View {
    let balance: ExpenseBalance

    private var balanceText: String {
        if abs(balance.balance) < 0.005 {
            return "ровно"
        }

        return balance.balance > 0 ? "получит" : "должен"
    }

    private var balanceColor: Color {
        if abs(balance.balance) < 0.005 {
            return AppColors.muted
        }

        return balance.balance > 0 ? AppColors.success : AppColors.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(balance.participantName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text("\(balanceText) \(moneyString(abs(balance.balance), currency: balance.currency))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(balanceColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                ExpenseBalanceMetric(title: "Оплатил", value: moneyString(balance.paid, currency: balance.currency))
                ExpenseBalanceMetric(title: "Доля", value: moneyString(balance.share, currency: balance.currency))
            }
        }
        .padding(10)
        .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ExpenseBalanceMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.muted)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ExpenseTotalPill: View {
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

struct ExpenseRowView: View {
    let expense: ExpenseItem
    let tripParticipants: [String]
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

                Text(involvedParticipantsText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(2)
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

    private var involvedParticipantsText: String {
        let involvedParticipants = expense.involvedParticipants(from: tripParticipants)
        guard !involvedParticipants.isEmpty else {
            return "Участники не выбраны"
        }

        if involvedParticipants.count == tripParticipants.count {
            return "Участвуют все"
        }

        return "Участвуют: \(involvedParticipants.joined(separator: ", "))"
    }
}
