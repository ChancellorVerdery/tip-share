import SwiftUI
import TipShareCore

struct ContentView: View {
    @Bindable var store: Store
    @FocusState private var focusedName: PersonEntry.ID?

    private var bills: Bool { store.mode == .bills }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $store.mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if bills { billsSection } else { totalSection }
                peopleSection
                splitSection
            }
            .navigationTitle("Tip Share")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: store.summary()) { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Clear Times", systemImage: "clock.arrow.circlepath") { store.clearTimes() }
                        Button(bills ? "Clear Bills" : "Clear Total", systemImage: "dollarsign.circle") { store.clearTips() }
                    } label: {
                        Image(systemName: "eraser")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
        }
    }

    // MARK: Tips

    private var totalSection: some View {
        Section {
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("0", text: $store.totalText)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
            }
        } header: {
            Text("Total Tips")
        } footer: {
            if let dollars = store.totalDollars, store.totalText.contains(".") {
                Text("Rounded to $\(dollars).")
            }
        }
    }

    private var billsSection: some View {
        Section {
            ForEach(denominations, id: \.self) { d in
                BillRow(value: d, count: Binding(
                    get: { store.bills[d] ?? 0 },
                    set: { store.bills[d] = max(0, $0) }
                ))
            }
        } header: {
            Text("Bills")
        } footer: {
            Text("Total: $\(store.billsTotal)").font(.headline).foregroundStyle(.primary)
        }
    }

    // MARK: People

    private var peopleSection: some View {
        Section {
            ForEach($store.people) { $person in
                HStack(spacing: 12) {
                    TextField("Name", text: $person.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedName, equals: person.id)
                    TimeField(text: $person.time)
                        .frame(width: 64)
                    if bills {
                        Button {
                            person.envelope.toggle()
                        } label: {
                            Image(systemName: person.envelope ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(person.envelope ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 84)
                        .accessibilityLabel("Envelope")
                        .accessibilityValue(person.envelope ? "On" : "Off")
                    }
                }
            }
            .onDelete { store.people.remove(atOffsets: $0) }

            Button {
                let person = PersonEntry()
                store.people.append(person)
                focusedName = person.id
            } label: {
                Label("Add Person", systemImage: "person.badge.plus")
            }
        } header: {
            HStack(spacing: 12) {
                Text("Name")
                Spacer()
                Text("Time").frame(width: 64)
                if bills { Text("Envelope").lineLimit(1).fixedSize().frame(width: 84) }
            }
        } footer: {
            Text("Time is h:mm. Swipe left on a name to remove it.")
        }
    }

    // MARK: Split

    @ViewBuilder
    private var splitSection: some View {
        let split = store.split
        let minutes = store.totalMinutes
        Section {
            if minutes == 0 || split.total == 0 {
                Text(minutes == 0 ? "Enter each person's time to split the tips." : "Enter the tips to split.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(zip(store.people, split.shares).enumerated()), id: \.offset) { _, pair in
                    ShareRow(person: pair.0, share: pair.1, showsBills: bills)
                }
                if !split.leftover.isEmpty {
                    Label {
                        Text("Couldn't split \(TipSplitter.describe(split.leftover)). Break into smaller bills and update the counts.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Split")
        } footer: {
            if minutes > 0, split.total > 0 {
                Text("$\(split.total) over \(ShiftTime.format(minutes)) · "
                     + String(format: "$%.2f/hr", Double(split.total) * 60 / Double(minutes)))
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct BillRow: View {
    let value: Int
    @Binding var count: Int

    var body: some View {
        HStack {
            Text("$\(value)")
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(width: 52, alignment: .leading)
            Text("$\(value * count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            TextField("0", value: $count, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .frame(width: 52)
            Stepper("Count", value: $count, in: 0...9999)
                .labelsHidden()
        }
    }
}

/// h:mm entry. Normalises "630" or "6" to "6:30" / "6:00" when editing ends; red while it can't be read.
private struct TimeField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField("h:mm", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .font(.body.monospacedDigit())
            .foregroundStyle(text.isEmpty || ShiftTime.minutes(text) != nil ? Color.primary : Color.red)
            .focused($focused)
            .onChange(of: focused) { _, isFocused in
                if !isFocused, let m = ShiftTime.minutes(text) { text = ShiftTime.format(m) }
            }
            .onSubmit {
                if let m = ShiftTime.minutes(text) { text = ShiftTime.format(m) }
            }
    }
}

private struct ShareRow: View {
    let person: PersonEntry
    let share: Share
    let showsBills: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if showsBills && person.envelope {
                    Image(systemName: "envelope.fill").foregroundStyle(.secondary).font(.footnote)
                }
                Text(person.name.isEmpty ? "Unnamed" : person.name)
                Text(person.minutes.map(ShiftTime.format) ?? "no time")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(person.minutes == nil ? .red : .secondary)
                Spacer()
                Text("$\(share.amount)")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            if showsBills, !share.bills.isEmpty {
                Text(TipSplitter.describe(share.bills))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if share.amount < share.target {
                Text("Short $\(share.target - share.amount) of $\(share.target)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
