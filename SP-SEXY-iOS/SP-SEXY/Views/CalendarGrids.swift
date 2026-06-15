import SwiftUI

// MARK: - Siatka godzinowa (4 dni / tydzień)

struct TimeGridView: View {
    let days: [Date]
    let reservations: [Reservation]
    let onTapReservation: (Reservation) -> Void
    let onCreate: (Date) -> Void

    private let startHour = Config.calendarStartHour
    private let endHour = Config.calendarEndHour
    private let hourHeight: CGFloat = 52
    private let gutterWidth: CGFloat = 38

    private var hours: [Int] { Array(startHour..<endHour) }

    var body: some View {
        GeometryReader { geo in
            let colWidth = max(38, (geo.size.width - gutterWidth) / CGFloat(max(1, days.count)))
            VStack(spacing: 0) {
                header(colWidth: colWidth)
                Divider()
                allDayRow(colWidth: colWidth)
                Divider()
                ScrollView(.vertical, showsIndicators: true) {
                    grid(colWidth: colWidth)
                }
            }
        }
    }

    // MARK: Nagłówek dni

    private func header(colWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: 46)
            ForEach(days, id: \.self) { day in
                let today = day.isSameDay(as: Date())
                VStack(spacing: 2) {
                    Text(PL.dniKrotkie[day.weekdayIndex])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(day.dayNumber)")
                        .font(.callout.weight(.semibold))
                        .frame(width: 26, height: 26)
                        .background(today ? Config.pilots[0].color : .clear, in: Circle())
                        .foregroundStyle(today ? .white : .primary)
                }
                .frame(width: colWidth, height: 46)
            }
        }
    }

    // MARK: Wiersz "cały dzień"

    private func allDayRow(colWidth: CGFloat) -> some View {
        let maxCount = days.map { allDayEvents(on: $0).count }.max() ?? 0
        let rowHeight = max(24, CGFloat(maxCount) * 20 + 6)
        return HStack(spacing: 0) {
            Text("cały\ndzień")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: gutterWidth, height: rowHeight)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    ForEach(allDayEvents(on: day)) { res in
                        allDayChip(res)
                            .onTapGesture { onTapReservation(res) }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: colWidth, height: rowHeight, alignment: .top)
                .padding(.horizontal, 1)
                .overlay(alignment: .leading) { Divider() }
            }
        }
        .frame(height: rowHeight)
    }

    private func allDayChip(_ res: Reservation) -> some View {
        let color = res.pilot?.color ?? .gray
        return Text(shortLabel(res))
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(res.isVacation ? 0.35 : 0.9), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(res.isVacation ? Color.primary : .white)
    }

    // MARK: Siatka godzin + wydarzenia

    private func grid(colWidth: CGFloat) -> some View {
        let totalHeight = CGFloat(hours.count) * hourHeight
        return HStack(alignment: .top, spacing: 0) {
            // gutter godzin
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { h in
                    Text(String(format: "%02d", h))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: gutterWidth, height: hourHeight, alignment: .topTrailing)
                        .padding(.trailing, 3)
                }
            }
            // kolumny dni
            ForEach(days, id: \.self) { day in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { h in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: hourHeight)
                                .overlay(alignment: .top) {
                                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onCreate(slot(day: day, hour: h)) }
                        }
                    }
                    ForEach(layout(day: day, colWidth: colWidth)) { item in
                        eventBlock(item.res, width: item.width)
                            .frame(width: item.width, height: item.height)
                            .offset(x: item.x, y: item.y)
                            .onTapGesture { onTapReservation(item.res) }
                    }
                }
                .frame(width: colWidth, height: totalHeight, alignment: .topLeading)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(.separator)).frame(width: 0.5)
                }
            }
        }
    }

    private func eventBlock(_ res: Reservation, width: CGFloat) -> some View {
        let color = res.pilot?.color ?? .gray
        return RoundedRectangle(cornerRadius: 5)
            .fill(color.opacity(0.92))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortLabel(res))
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Text(Fmt.time.string(from: res.start))
                            .font(.system(size: 9))
                        if res.isOps { miniTag("OPS") }
                        if res.isJoint { miniTag("WSP") }
                    }
                    .lineLimit(1)
                }
                .padding(3)
                .foregroundStyle(.white)
            }
            .padding(.trailing, 1)
    }

    private func miniTag(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 7, weight: .bold))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(.white.opacity(0.3), in: Capsule())
    }

    // MARK: Pomocnicze

    private func allDayEvents(on day: Date) -> [Reservation] {
        reservations
            .filter { $0.isAllDay && day >= $0.start.startOfDay() && day <= $0.end.startOfDay() }
            .sorted { ($0.pilotId ?? "") < ($1.pilotId ?? "") }
    }

    private func slot(day: Date, hour: Int) -> Date {
        let cal = PL.calendar
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func shortLabel(_ res: Reservation) -> String {
        if res.isVacation { return "Urlop" }
        let name = res.pilot?.name ?? res.title
        // tylko imię, by zmieścić w wąskiej kolumnie
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    // Pozycjonowanie wydarzeń godzinowych z prostym podziałem na tory przy nakładaniu.
    private struct Positioned: Identifiable {
        let id: String
        let res: Reservation
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private func layout(day: Date, colWidth: CGFloat) -> [Positioned] {
        let events = reservations
            .filter { !$0.isAllDay && $0.start.isSameDay(as: day) }
            .sorted { $0.start < $1.start }
        guard !events.isEmpty else { return [] }

        // przydział torów (greedy)
        var laneEnd: [Date] = []
        var laneOf: [String: Int] = [:]
        for ev in events {
            var placed = false
            for i in laneEnd.indices where ev.start >= laneEnd[i] {
                laneOf[ev.id] = i
                laneEnd[i] = ev.end
                placed = true
                break
            }
            if !placed {
                laneOf[ev.id] = laneEnd.count
                laneEnd.append(ev.end)
            }
        }
        let lanes = max(1, laneEnd.count)
        let laneWidth = colWidth / CGFloat(lanes)

        return events.map { ev in
            let lane = laneOf[ev.id] ?? 0
            let (y, h) = yAndHeight(ev)
            return Positioned(
                id: ev.id, res: ev,
                x: laneWidth * CGFloat(lane),
                y: y,
                width: max(18, laneWidth),
                height: h
            )
        }
    }

    private func yAndHeight(_ ev: Reservation) -> (CGFloat, CGFloat) {
        let cal = PL.calendar
        let sH = Double(cal.component(.hour, from: ev.start)) + Double(cal.component(.minute, from: ev.start)) / 60.0
        let eH = Double(cal.component(.hour, from: ev.end)) + Double(cal.component(.minute, from: ev.end)) / 60.0
        let startClamped = max(Double(startHour), sH)
        let endClamped = min(Double(endHour), max(eH, startClamped + 0.25))
        let y = CGFloat(startClamped - Double(startHour)) * hourHeight
        let h = max(20, CGFloat(endClamped - startClamped) * hourHeight - 1)
        return (y, h)
    }
}

// MARK: - Siatka miesiąca

struct MonthGridView: View {
    let monthAnchor: Date
    let reservations: [Reservation]
    let onSelectDay: (Date) -> Void

    private var days: [Date] { monthGridDays(monthAnchor) }
    private var currentMonth: Int { PL.calendar.component(.month, from: monthAnchor) }

    // kolejność od poniedziałku
    private let headerOrder = [1, 2, 3, 4, 5, 6, 0]

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(headerOrder, id: \.self) { idx in
                    Text(PL.dniKrotkie[idx])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            GeometryReader { geo in
                let cw = geo.size.width / 7
                let rh = geo.size.height / 6
                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                let day = days[row * 7 + col]
                                dayCell(day, inMonth: PL.calendar.component(.month, from: day) == currentMonth)
                                    .frame(width: cw, height: rh)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onSelectDay(day) }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func dayCell(_ day: Date, inMonth: Bool) -> some View {
        let today = day.isSameDay(as: Date())
        let dayRes = reservations.filter { res in
            if res.isAllDay {
                return day >= res.start.startOfDay() && day <= res.end.startOfDay()
            }
            return res.start.isSameDay(as: day)
        }
        return VStack(spacing: 2) {
            Text("\(day.dayNumber)")
                .font(.caption2.weight(today ? .bold : .regular))
                .foregroundStyle(today ? Color.white : (inMonth ? Color.primary : Color(.tertiaryLabel)))
                .frame(width: 20, height: 20)
                .background(today ? Config.pilots[0].color : .clear, in: Circle())
                .padding(.top, 3)

            VStack(spacing: 1.5) {
                ForEach(dayRes.prefix(4)) { res in
                    Capsule()
                        .fill((res.pilot?.color ?? .gray).opacity(res.isVacation ? 0.45 : 1))
                        .frame(height: 3.5)
                        .padding(.horizontal, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            Rectangle().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
        }
    }
}
