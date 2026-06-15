import SwiftUI

struct ReservationsView: View {
    @EnvironmentObject var auth: GoogleAuth

    @State private var weekStart = Date().startOfWeek()
    @State private var reservations: [Reservation] = []
    @State private var loading = false
    @State private var activeSheet: ActiveSheet?
    @State private var errorMessage: String?

    private var service: CalendarService { CalendarService(auth: auth) }

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekBar
                Divider()
                agenda
            }
            .navigationTitle("Rezerwacje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LogoutMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .create(weekStart)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task(id: weekStart) { await load() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit(let res):
                ReservationEditView(existing: res, defaultDate: res.start) {
                    await load()
                }
                .environmentObject(auth)
            case .create(let day):
                ReservationEditView(existing: nil, defaultDate: day) {
                    await load()
                }
                .environmentObject(auth)
            }
        }
        .alert("Błąd", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Pasek nawigacji tygodnia

    private var weekBar: some View {
        HStack {
            Button { weekStart = weekStart.adding(days: -7) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(Fmt.weekHeader(weekStart))
                    .font(.subheadline.weight(.semibold))
                Button("Dziś") { weekStart = Date().startOfWeek() }
                    .font(.caption)
            }
            Spacer()
            Button { weekStart = weekStart.adding(days: 7) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Agenda tygodnia

    private var agenda: some View {
        List {
            ForEach(weekDays, id: \.self) { day in
                Section {
                    let items = reservations(on: day)
                    if items.isEmpty {
                        Text("—")
                            .foregroundStyle(.tertiary)
                            .font(.subheadline)
                    } else {
                        ForEach(items) { res in
                            Button { activeSheet = .edit(res) } label: {
                                ReservationRow(reservation: res)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text(Fmt.dayHeader(day))
                        Spacer()
                        Button {
                            activeSheet = .create(day)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if loading { ProgressView() }
        }
        .refreshable { await load() }
    }

    // MARK: - Dane

    private var weekDays: [Date] {
        (0..<7).map { weekStart.adding(days: $0) }
    }

    private func reservations(on day: Date) -> [Reservation] {
        reservations
            .filter { res in
                if res.isAllDay {
                    return day >= res.start.startOfDay() && day <= res.end.startOfDay()
                }
                return res.start.isSameDay(as: day)
            }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay && !b.isAllDay }
                return a.start < b.start
            }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            reservations = try await service.fetchWeek(weekStart: weekStart)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Wiersz rezerwacji

struct ReservationRow: View {
    let reservation: Reservation

    private var color: Color {
        reservation.pilot?.color ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(reservation.isVacation
                      ? AnyShapeStyle(color.opacity(0.5))
                      : AnyShapeStyle(color))
                .frame(width: 5)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(reservation.isVacation ? .secondary : .primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if reservation.isOps { tag("OPS", .orange) }
                if reservation.isJoint { tag("WSP", .teal) }
            }
        }
        .padding(.vertical, 4)
    }

    private var pilotName: String {
        reservation.pilot?.name
            ?? reservation.title
                .replacingOccurrences(of: "[SP-SEXY] ", with: "")
                .replacingOccurrences(of: "[URLOP] ", with: "")
    }

    private var primaryLine: String {
        if reservation.isVacation {
            return "🏖️ Urlop — \(pilotName)"
        }
        if reservation.isAllDay {
            let multi = !reservation.start.isSameDay(as: reservation.end)
            return multi ? "📅 \(pilotName)" : pilotName
        }
        return "\(Fmt.time.string(from: reservation.start))–\(Fmt.time.string(from: reservation.end))  \(pilotName)"
    }

    private var subtitle: String {
        var parts: [String] = []
        if reservation.isAllDay && !reservation.isVacation
            && !reservation.start.isSameDay(as: reservation.end) {
            parts.append("\(Fmt.dayKey.string(from: reservation.start)) → \(Fmt.dayKey.string(from: reservation.end))")
        }
        if !reservation.route.isEmpty { parts.append(reservation.route) }
        return parts.joined(separator: "  ·  ")
    }

    private func tag(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}
