import SwiftUI

struct TripsView: View {
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

struct TripCardView: View {
    let trip: TravelTrip
    let totalInRubles: Double?
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
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

                TripProgressBar(trip: trip)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Города поездки")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.ink)

                Text(trip.cities.isEmpty ? "Маршрут не задан" : trip.cities.joined(separator: " → "))
                    .font(.subheadline)
                    .foregroundStyle(trip.cities.isEmpty ? AppColors.muted : AppColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
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

struct TripEditorView: View {
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
                            List {
                                ForEach(selectedCities, id: \.self) { city in
                                    HStack(spacing: 10) {
                                        Text("\((selectedCities.firstIndex(of: city) ?? 0) + 1)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppColors.muted)
                                            .frame(width: 24, height: 24)
                                            .background(Color.white, in: Circle())

                                        Text(city)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppColors.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button {
                                            selectedCities.removeAll { $0 == city }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(AppColors.faint)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Удалить город")
                                    }
                                    .padding(.vertical, 4)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
                                    .listRowBackground(AppColors.itemBackground)
                                }
                                .onMove { source, destination in
                                    selectedCities.move(fromOffsets: source, toOffset: destination)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(true)
                            .environment(\.editMode, .constant(.active))
                            .frame(height: CGFloat(selectedCities.count) * 58)
                            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .padding(.bottom, 24)
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

struct FlowLayout<Item: Hashable, Content: View>: View {
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
