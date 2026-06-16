import SwiftUI

struct ReservationsView: View {
    @EnvironmentObject var auth: GoogleAuth
    @Environment(\.verticalSizeClass) private var vSizeClass

    enum CalMode: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day: return "Dzień"
            case .week: return "Tydzień"
            case .month: return "Miesiąc"
            }
        }
    }

    enum ActiveSheet: Identifiable {
        case edit(Reservation)
        case create(Date)
        var id: String {
            switch self {
            case .edit(let r): return "edit-\(r.id)"
            case .create(let d): return "create-\(d.timeIntervalSince1970)"
            }
        }
    }

    @State private var mode: CalMode = .day
    @State private var anchor = Date()
    @State private var reservations: [Reservation] = []
    @State private var loading = false
    @State private var activeSheet: ActiveSheet?
    @State private var errorMessage: String?

    private var service: CalendarService { CalendarService(auth: auth) }

    /// iPhone w poziomie → niska wysokość. Wtedy pokazujemy pełny tydzień.
    private var isLandscape: Bool { vSizeClass == .compact }

    /// Tryb faktycznie wyświetlany (poziomo wymuszamy tydzień, chyba że miesiąc).
    private var effectiveMode: CalMode {
        if mode == .month { return .month }
        return isLandscape ? .week : mode
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(CalMode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 4)

                periodHeader
                Divider()
                calendarContent
            }
            .navigationTitle("Rezerwacje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LogoutMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .create(defaultCreateDate()) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task(id: rangeKey) { await load() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit(let res):
                ReservationEditView(existing: res, defaultDate: res.start) { await load() }
                    .environmentObject(auth)
            case .create(let day):
                ReservationEditView(existing: nil, defaultDate: day) { await load() }
                    .environmentObject(auth)
            }
        }
        .alert("Błąd", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Nagłówek okresu

    private var periodHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").padding(8) }
            Spacer()
            VStack(spacing: 1) {
                Text(periodLabel).font(.subheadline.weight(.semibold))
                Button("Dziś") { anchor = Date() }.font(.caption)
            }
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").padding(8) }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Treść kalendarza

    @ViewBuilder
    private var calendarContent: some View {
        Group {
            switch effectiveMode {
            case .month:
                MonthGridView(monthAnchor: anchor, reservations: reservations) { day in
                    anchor = day
                    mode = .day
                }
            case .day:
                DayAgendaView(
                    day: periodStart,
                    reservations: reservations,
                    onTapReservation: { activeSheet = .edit($0) },
                    onCreate: { activeSheet = .create($0) }
                )
            case .week:
                TimeGridView(
                    days: visibleDays,
                    reservations: reservations,
                    onTapReservation: { activeSheet = .edit($0) },
                    onCreate: { activeSheet = .create($0) }
                )
            }
        }
        .overlay { if loading { ProgressView() } }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > 80 && abs(dx) > abs(dy) * 1.5 {
                        shift(dx < 0 ? 1 : -1)
                    }
                }
        )
    }

    // MARK: - Zakres / nawigacja

    private var periodStart: Date {
        switch effectiveMode {
        case .day: return anchor.startOfDay()
        case .week: return anchor.startOfWeek()
        case .month: return monthGridDays(anchor).first ?? anchor.startOfWeek()
        }
    }

    private var periodDayCount: Int {
        switch effectiveMode {
        case .day: return 1
        case .week: return 7
        case .month: return 42
        }
    }

    private var visibleDays: [Date] {
        (0..<periodDayCount).map { periodStart.adding(days: $0) }
    }

    private var rangeKey: String {
        "\(effectiveMode.rawValue)-\(Fmt.dayKey.string(from: periodStart))"
    }

    private var periodLabel: String {
        switch effectiveMode {
        case .day: return Fmt.fullDayHeader(periodStart)
        case .week: return Fmt.rangeHeader(start: periodStart, dayCount: periodDayCount)
        case .month: return Fmt.monthHeader(anchor)
        }
    }

    private func shift(_ dir: Int) {
        switch effectiveMode {
        case .day: anchor = anchor.adding(days: dir)
        case .week: anchor = anchor.adding(days: 7 * dir)
        case .month: anchor = PL.calendar.date(byAdding: .month, value: dir, to: anchor) ?? anchor
        }
    }

    private func defaultCreateDate() -> Date {
        let cal = PL.calendar
        let base = (effectiveMode == .month) ? Date() : periodStart
        return cal.date(bySettingHour: 8, minute: 0, second: 0, of: base) ?? base
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let start = periodStart
            let end = start.adding(days: periodDayCount)
            reservations = try await service.fetchRange(from: start, to: end)
        } catch is CancellationError {
            // Zmiana dnia/tygodnia anulowała poprzednie żądanie — ignoruj.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // To samo, ale z URLSession.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
