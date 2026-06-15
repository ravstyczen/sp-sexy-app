import SwiftUI

struct ReservationEditView: View {
    enum ResType: String, CaseIterable, Identifiable {
        case hours, allday, multiday, vacation
        var id: String { rawValue }
        var label: String {
            switch self {
            case .hours: return "Godziny"
            case .allday: return "Cały dzień"
            case .multiday: return "Wiele dni"
            case .vacation: return "Urlop"
            }
        }
    }

    @EnvironmentObject var auth: GoogleAuth
    @Environment(\.dismiss) private var dismiss

    let existing: Reservation?
    let onSaved: () async -> Void

    @State private var pilotId: String
    @State private var type: ResType
    @State private var date: Date
    @State private var dateFrom: Date
    @State private var dateTo: Date
    @State private var timeFrom: Date
    @State private var timeTo: Date
    @State private var route: String
    @State private var isOps: Bool
    @State private var isJoint: Bool

    @State private var saving = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    private var service: CalendarService { CalendarService(auth: auth) }
    private var isEdit: Bool { existing != nil }

    init(existing: Reservation?, defaultDate: Date, onSaved: @escaping () async -> Void) {
        self.existing = existing
        self.onSaved = onSaved

        let cal = PL.calendar
        let baseDay = (existing?.start ?? defaultDate).startOfDay()

        // Typ początkowy (jak w modal'u wersji web).
        let initialType: ResType
        if let e = existing {
            if e.isVacation {
                initialType = .vacation
            } else if e.isAllDay && !e.start.isSameDay(as: e.end) {
                initialType = .multiday
            } else if e.isAllDay {
                initialType = .allday
            } else {
                initialType = .hours
            }
        } else {
            initialType = .hours
        }

        _pilotId = State(initialValue: existing?.pilotId ?? Config.pilots[0].id)
        _type = State(initialValue: initialType)
        _date = State(initialValue: baseDay)
        _dateFrom = State(initialValue: (existing?.start ?? defaultDate).startOfDay())
        _dateTo = State(initialValue: (existing?.end ?? defaultDate).startOfDay())

        if let e = existing, !e.isAllDay {
            _timeFrom = State(initialValue: e.start)
            _timeTo = State(initialValue: e.end)
        } else {
            _timeFrom = State(initialValue: cal.date(bySettingHour: 8, minute: 0, second: 0, of: baseDay) ?? baseDay)
            _timeTo = State(initialValue: cal.date(bySettingHour: 10, minute: 0, second: 0, of: baseDay) ?? baseDay)
        }

        _route = State(initialValue: existing?.route ?? "")
        _isOps = State(initialValue: existing?.isOps ?? false)
        _isJoint = State(initialValue: existing?.isJoint ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pilot", selection: $pilotId) {
                        ForEach(Config.pilots) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                }

                Section("Typ rezerwacji") {
                    Picker("Typ", selection: $type) {
                        ForEach(ResType.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Pola zależne od typu
                switch type {
                case .hours:
                    Section {
                        DatePicker("Data", selection: $date, displayedComponents: .date)
                        DatePicker("Od", selection: $timeFrom, displayedComponents: .hourAndMinute)
                        DatePicker("Do", selection: $timeTo, displayedComponents: .hourAndMinute)
                    }
                case .allday:
                    Section {
                        DatePicker("Data", selection: $date, displayedComponents: .date)
                    }
                case .multiday, .vacation:
                    Section {
                        DatePicker("Od", selection: $dateFrom, displayedComponents: .date)
                        DatePicker("Do", selection: $dateTo, in: dateFrom..., displayedComponents: .date)
                    }
                }

                if type != .vacation {
                    Section {
                        TextField("Trasa (np. EPKA-EPPO)", text: $route)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Toggle("Lot OPS", isOn: $isOps)
                        Toggle("Lot wspólny", isOn: $isJoint)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }

                if isEdit {
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Usuń rezerwację", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEdit ? "Edycja rezerwacji" : "Nowa rezerwacja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { Task { await save() } }
                        .disabled(saving)
                }
            }
            .overlay {
                if saving {
                    Color.black.opacity(0.05).ignoresSafeArea()
                    ProgressView()
                }
            }
            .confirmationDialog("Usunąć tę rezerwację?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Usuń", role: .destructive) { Task { await performDelete() } }
                Button("Anuluj", role: .cancel) {}
            }
        }
    }

    // MARK: - Zapis

    private func save() async {
        guard let pilot = Config.pilot(id: pilotId) else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }

        let cal = PL.calendar
        var start = Date()
        var end = Date()
        var allDay = false
        var vacation = false

        switch type {
        case .hours:
            let s = combine(day: date, time: timeFrom, cal: cal)
            let e = combine(day: date, time: timeTo, cal: cal)
            guard e > s else {
                errorMessage = "Godzina „Do” musi być po „Od”."
                return
            }
            start = s; end = e; allDay = false

        case .allday:
            start = cal.startOfDay(for: date)
            end = endOfDay(date, cal: cal)
            allDay = true

        case .multiday, .vacation:
            guard dateTo >= dateFrom else {
                errorMessage = "Data „Do” musi być po „Od”."
                return
            }
            start = cal.startOfDay(for: dateFrom)
            end = endOfDay(dateTo, cal: cal)
            allDay = true
            vacation = (type == .vacation)
        }

        let useRoute = vacation ? "" : route.trimmingCharacters(in: .whitespaces)
        let useOps = vacation ? false : isOps
        let useJoint = vacation ? false : isJoint

        do {
            if let existing {
                try await service.update(id: existing.id, pilot: pilot, start: start, end: end,
                                         isAllDay: allDay, route: useRoute, isOps: useOps,
                                         isVacation: vacation, isJoint: useJoint)
            } else {
                try await service.create(pilot: pilot, start: start, end: end,
                                         isAllDay: allDay, route: useRoute, isOps: useOps,
                                         isVacation: vacation, isJoint: useJoint)
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        guard let existing else { return }
        saving = true
        defer { saving = false }
        do {
            try await service.delete(id: existing.id)
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pomocnicze

    private func combine(day: Date, time: Date, cal: Calendar) -> Date {
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var comps = DateComponents()
        comps.year = d.year; comps.month = d.month; comps.day = d.day
        comps.hour = t.hour; comps.minute = t.minute
        return cal.date(from: comps) ?? day
    }

    private func endOfDay(_ day: Date, cal: Calendar) -> Date {
        cal.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day
    }
}
