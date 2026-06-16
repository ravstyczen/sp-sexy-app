import SwiftUI

struct FlightLogView: View {
    @EnvironmentObject var auth: GoogleAuth
    @State private var tab = 0
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Nowy wpis").tag(0)
                    Text("Historia").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == 0 {
                    NewFlightLogForm {
                        reloadToken += 1
                        tab = 1
                    }
                } else {
                    FlightLogHistory(reloadToken: reloadToken)
                }
            }
            .navigationTitle("Dziennik lotów")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LogoutMenu() }
            }
        }
    }
}

// MARK: - Nowy wpis

struct NewFlightLogForm: View {
    @EnvironmentObject var auth: GoogleAuth
    let onSaved: () -> Void

    @State private var date = Date()
    @State private var hoursBefore = ""
    @State private var hoursAfter = ""
    @State private var fuelAdded = "0"
    @State private var oilAdded = "0"
    @State private var fuelCost = "0"
    @State private var fuelLevel = ""
    @State private var remarks = ""
    @State private var isOps = false
    @State private var isJoint = false

    @State private var saving = false
    @State private var loadingLast = false
    @State private var errorMessage: String?

    private var service: SheetsService { SheetsService(auth: auth) }

    var body: some View {
        Form {
            Section {
                DatePicker("Data", selection: $date, displayedComponents: .date)
                LabeledContent("Pilot", value: auth.pilot?.name ?? "")
            }

            Section("Motogodziny") {
                numField("Przed lotem", $hoursBefore, placeholder: "np. 145.3")
                numField("Po locie", $hoursAfter, placeholder: "np. 146.8")
            }

            Section("Paliwo i olej") {
                numField("Paliwo dolane (L)", $fuelAdded)
                numField("Olej dolany (L)", $oilAdded)
                numField("Koszt paliwa (PLN)", $fuelCost)
                numField("Stan paliwa (L)", $fuelLevel, placeholder: "np. 60")
            }

            Section {
                Toggle("Lot OPS", isOn: $isOps)
                Toggle("Lot wspólny", isOn: $isJoint)
            }

            Section("Uwagi") {
                TextField("Uwagi dotyczące lotu i stanu samolotu…", text: $remarks, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red).font(.callout) }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if saving { ProgressView() } else { Text("Zapisz wpis").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled(saving)
            }
        }
        .overlay(alignment: .top) {
            if loadingLast { ProgressView().padding(.top, 8) }
        }
        .task { await prefillLast() }
    }

    private func numField(_ label: String, _ binding: Binding<String>, placeholder: String = "0") -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }

    private func prefillLast() async {
        loadingLast = true
        defer { loadingLast = false }
        if let last = try? await service.getLastEntry(), !last.hoursAfter.isEmpty {
            hoursBefore = last.hoursAfter
        }
    }

    private func save() async {
        errorMessage = nil
        guard !hoursAfter.isEmpty else {
            errorMessage = "Podaj motogodziny po locie."
            return
        }
        if let before = Double(hoursBefore.replacingOccurrences(of: ",", with: ".")),
           let after = Double(hoursAfter.replacingOccurrences(of: ",", with: ".")),
           !hoursBefore.isEmpty, after <= before {
            errorMessage = "Motogodziny po locie muszą być większe niż przed."
            return
        }

        saving = true
        defer { saving = false }

        let entry = FlightLogEntry(
            date: Fmt.dayKey.string(from: date),
            pilot: auth.pilot?.name ?? "",
            hoursBefore: hoursBefore,
            hoursAfter: hoursAfter,
            fuelAdded: fuelAdded,
            oilAdded: oilAdded,
            fuelCost: fuelCost,
            fuelLevel: fuelLevel,
            remarks: remarks,
            isOps: isOps ? "TAK" : "",
            isJoint: isJoint ? "TAK" : ""
        )

        do {
            try await service.append(entry)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Historia

struct FlightLogHistory: View {
    @EnvironmentObject var auth: GoogleAuth
    let reloadToken: Int

    @State private var entries: [FlightLogEntry] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private var service: SheetsService { SheetsService(auth: auth) }

    var body: some View {
        Group {
            if entries.isEmpty && !loading {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Brak wpisów")
                        .font(.headline)
                    Text(errorMessage ?? "Dodaj pierwszy wpis po locie.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries.reversed()) { entry in
                        FlightLogRow(entry: entry)
                            .listRowBackground((Config.pilot(name: entry.pilot)?.color ?? .gray).opacity(0.16))
                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(Color.primary.opacity(0.35))
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 8)
            }
        }
        .overlay { if loading { ProgressView() } }
        .task(id: reloadToken) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await service.getFlightLog()
            errorMessage = nil
        } catch is CancellationError {
            // ignoruj anulowanie
        } catch let urlError as URLError where urlError.code == .cancelled {
            // ignoruj anulowanie
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FlightLogRow: View {
    let entry: FlightLogEntry

    /// Nalot jako hh:mm (z dziesiętnej różnicy motogodzin).
    private var delta: String {
        guard let b = Double(entry.hoursBefore.replacingOccurrences(of: ",", with: ".")),
              let a = Double(entry.hoursAfter.replacingOccurrences(of: ",", with: ".")),
              a >= b else { return "" }
        let totalMinutes = Int(((a - b) * 60.0).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    private var hasFuelInfo: Bool {
        (!entry.fuelAdded.isEmpty && entry.fuelAdded != "0")
            || (!entry.fuelCost.isEmpty && entry.fuelCost != "0")
            || !entry.fuelLevel.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(entry.date).font(.subheadline.weight(.semibold))
                Text("· \(entry.pilot)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if entry.isOps == "TAK" { tag("OPS", .orange) }
                if entry.isJoint == "TAK" { tag("WSP", .teal) }
            }

            HStack(spacing: 14) {
                stat("Motogodz.", "\(entry.hoursBefore) → \(entry.hoursAfter)")
                if !delta.isEmpty { stat("Nalot", delta) }
                Spacer(minLength: 0)
            }

            if hasFuelInfo {
                HStack(spacing: 14) {
                    if !entry.fuelAdded.isEmpty && entry.fuelAdded != "0" { stat("Paliwo", "\(entry.fuelAdded) L") }
                    if !entry.fuelCost.isEmpty && entry.fuelCost != "0" { stat("Koszt", "\(entry.fuelCost) PLN") }
                    if !entry.fuelLevel.isEmpty { stat("Stan", "\(entry.fuelLevel) L") }
                    Spacer(minLength: 0)
                }
            }

            if !entry.remarks.isEmpty {
                Text(entry.remarks)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 9)).foregroundStyle(.tertiary)
            Text(value).font(.caption.weight(.medium))
        }
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
