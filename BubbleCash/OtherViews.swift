import SwiftUI

// MARK: - Request

struct RequestView: View {
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var amount = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("From") { PhoneField(text: $phone) }
                LabeledContent("Amount") { AmountField(text: $amount) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Request Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Request", action: submit) }
            }
        }
    }

    private func submit() {
        guard phone.filter(\.isNumber).count == 10 else { error = "Enter a 10-digit number"; return }
        let v = amountValue(amount)
        guard v > 0 else { error = "Enter an amount"; return }
        wallet.requests.insert(MoneyRequest(phone: phone, amount: v, date: Date()), at: 0)
        haptic()
        dismiss()
    }
}

// MARK: - Card settings

struct CardSettingsView: View {
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var frozen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardView(index: wallet.selected, name: name.isEmpty ? " " : name,
                             balance: wallet.balance, frozen: frozen)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    LabeledContent("Name") {
                        TextField("Card name", text: $name).multilineTextAlignment(.trailing)
                    }
                    Toggle("Freeze card", isOn: $frozen.animation(Theme.spring))
                } footer: {
                    Text("A frozen card can't pay or send until you unfreeze it.")
                }
            }
            .navigationTitle("Card Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        wallet.cards[wallet.selected].name = n.isEmpty ? wallet.currentCard.name : String(n.prefix(20))
                        wallet.cards[wallet.selected].frozen = frozen
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = wallet.currentCard.name
                frozen = wallet.currentCard.frozen
            }
        }
    }
}

// MARK: - Goals

struct NewGoalView: View {
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Name") {
                    TextField("New shoes", text: $name).multilineTextAlignment(.trailing)
                }
                LabeledContent("Target") { AmountField(text: $target) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { error = "Enter a name"; return }
                        let t = amountValue(target)
                        guard t > 0 else { error = "Enter a target"; return }
                        wallet.goals.append(Goal(name: String(n.prefix(24)), target: t))
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GoalView: View {
    let goalID: UUID
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            if let goal = wallet.goals.first(where: { $0.id == goalID }) {
                Form {
                    Section {
                        VStack(spacing: 6) {
                            Text(fmt(goal.saved)).font(.system(size: 44, weight: .bold)).monospacedDigit()
                                .contentTransition(.numericText())
                            Text("saved of \(fmt(goal.target))").foregroundStyle(Theme.muted)
                            ProgressBar(value: Double(goal.saved) / Double(max(goal.target, 1)))
                                .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    Section {
                        LabeledContent("Add") { AmountField(text: $amount) }
                        Button("Add to Goal") {
                            let v = amountValue(amount)
                            guard v > 0 else { error = "Enter an amount"; return }
                            withAnimation(Theme.spring) {
                                if wallet.fund(goalID, v) { amount = ""; error = nil; haptic() }
                                else { error = "Not enough Bubble Cash" }
                            }
                        }
                        if let error { Text(error).foregroundStyle(.red) }
                    }
                    Section {
                        Button("Delete Goal", role: .destructive) {
                            wallet.deleteGoal(goalID)
                            dismiss()
                        }
                    }
                }
                .navigationTitle(goal.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
    }
}

// MARK: - Activity with weekly chart

struct ActivityView: View {
    @EnvironmentObject var wallet: Wallet

    private struct Day: Identifiable {
        let id: Int
        let label: String
        var inn = 0
        var out = 0
    }

    private var days: [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result = (0..<7).map { k -> Day in
            let d = cal.date(byAdding: .day, value: k - 6, to: today)!
            return Day(id: k, label: String(d.formatted(.dateTime.weekday(.narrow))))
        }
        for e in wallet.history {
            let diff = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: e.date)).day ?? -99
            let k = diff + 6
            guard (0..<7).contains(k) else { continue }
            if e.amount >= 0 { result[k].inn += e.amount } else { result[k].out -= e.amount }
        }
        return result
    }

    var body: some View {
        let d = days
        let maxV = max(1, d.map { max($0.inn, $0.out) }.max() ?? 1)
        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 28) {
                        stat("In · 7 days", "+" + fmt(d.reduce(0) { $0 + $1.inn }), Theme.green)
                        stat("Out · 7 days", "−" + fmt(d.reduce(0) { $0 + $1.out }), .white)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(d) { day in
                            VStack(spacing: 6) {
                                HStack(alignment: .bottom, spacing: 3) {
                                    bar(day.inn, maxV, Theme.green)
                                    bar(day.out, maxV, .white)
                                }
                                .frame(height: 100, alignment: .bottom)
                                Text(day.label).font(.caption2).foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Money in and out over the last 7 days")
                }
                .padding(16)
                .background(Theme.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(wallet.history) { e in
                        EntryRow(entry: e)
                        if e.id != wallet.history.last?.id { Divider().padding(.leading, 66) }
                    }
                }
                .background(Theme.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Activity")
    }

    private func stat(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.footnote).foregroundStyle(Theme.muted)
            Text(v).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(c)
        }
    }

    private func bar(_ v: Int, _ maxV: Int, _ c: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(c)
            .frame(width: 8, height: max(2, 100 * CGFloat(v) / CGFloat(maxV)))
    }
}
