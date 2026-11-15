import SwiftUI

enum SheetKind: Identifiable {
    case pay, add, send, request, card, newGoal, goal(UUID)
    var id: String {
        switch self {
        case .pay: "pay"
        case .add: "add"
        case .send: "send"
        case .request: "request"
        case .card: "card"
        case .newGoal: "newGoal"
        case .goal(let g): "goal-\(g)"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var wallet: Wallet
    @State private var sheet: SheetKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    CardStack(onTap: { sheet = .card })

                    HStack(spacing: 10) {
                        ActionButton(title: "Pay", icon: "circle.circle") { sheet = .pay }
                        ActionButton(title: "Add", icon: "plus") { sheet = .add }
                        ActionButton(title: "Send", icon: "arrow.up.right") { sheet = .send }
                        ActionButton(title: "Request", icon: "arrow.down.left") { sheet = .request }
                    }

                    if !wallet.requests.isEmpty {
                        HomeSection(title: "Requests") {
                            ForEach(wallet.requests) { r in
                                RequestRow(request: r)
                                if r.id != wallet.requests.last?.id { Divider().padding(.leading, 66) }
                            }
                        }
                    }

                    HomeSection(title: "Goals", trailing: AnyView(Button("New") { sheet = .newGoal })) {
                        if wallet.goals.isEmpty {
                            Text("No goals yet. Tap New to start one.")
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity).padding(20)
                        }
                        ForEach(wallet.goals) { g in
                            Button { sheet = .goal(g.id) } label: { GoalRow(goal: g) }
                                .buttonStyle(.plain)
                            if g.id != wallet.goals.last?.id { Divider().padding(.leading, 16) }
                        }
                    }

                    HomeSection(title: "Recent", trailing: AnyView(NavigationLink("See All", destination: ActivityView()))) {
                        ForEach(Array(wallet.history.prefix(4))) { e in
                            EntryRow(entry: e)
                            if e.id != wallet.history.prefix(4).last?.id { Divider().padding(.leading, 66) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Bubble Cash")
            .sheet(item: $sheet) { kind in
                Group {
                    switch kind {
                    case .pay: PayView()
                    case .add: TransferView(mode: .add)
                    case .send: TransferView(mode: .send)
                    case .request: RequestView()
                    case .card: CardSettingsView()
                    case .newGoal: NewGoalView()
                    case .goal(let id): GoalView(goalID: id)
                    }
                }
                .environmentObject(wallet)
                .preferredColorScheme(.dark)
            }
        }
    }
}

struct HomeSection<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.weight(.bold))
                Spacer()
                trailing
            }
            VStack(spacing: 0) { content }
                .background(Theme.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(title).font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(Theme.group, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .foregroundStyle(.white)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct EntryRow: View {
    @EnvironmentObject var wallet: Wallet
    let entry: Entry

    var body: some View {
        let pos = entry.amount >= 0
        HStack(spacing: 12) {
            Image(systemName: pos ? "arrow.down.left" : "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(pos ? Theme.green : .white)
                .frame(width: 38, height: 38)
                .background(Theme.raised, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).lineLimit(1)
                Text("\(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(wallet.cards[safe: entry.card]?.name ?? "")")
                    .font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Text((pos ? "+" : "−") + fmt(abs(entry.amount)))
                .fontWeight(.semibold).monospacedDigit()
                .foregroundStyle(pos ? Theme.green : .white)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

struct RequestRow: View {
    @EnvironmentObject var wallet: Wallet
    let request: MoneyRequest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.raised, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(request.phone)
                Text("Requested \(fmt(request.amount))").font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Paid") { withAnimation { wallet.markPaid(request) }; haptic() }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).frame(height: 30)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(.black)
            Button { withAnimation { wallet.cancel(request) } } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold))
                    .frame(width: 30, height: 30)
                    .background(Theme.raised, in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("Cancel request")
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

struct GoalRow: View {
    let goal: Goal
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.name)
                Spacer()
                Text("\(fmt(goal.saved)) / \(fmt(goal.target))")
                    .font(.subheadline).monospacedDigit().foregroundStyle(Theme.muted)
            }
            ProgressBar(value: Double(goal.saved) / Double(max(goal.target, 1)))
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.raised)
                Capsule()
                    .fill(LinearGradient(colors: Theme.bubble, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 6)
        .animation(Theme.spring, value: value)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
