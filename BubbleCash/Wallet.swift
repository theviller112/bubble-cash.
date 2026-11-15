import Foundation
import LocalAuthentication

struct Entry: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Int      // positive = in, negative = out
    var date: Date
    var card: Int
}

struct MoneyRequest: Identifiable, Codable {
    var id = UUID()
    var phone: String
    var amount: Int
    var date: Date
}

struct Goal: Identifiable, Codable {
    var id = UUID()
    var name: String
    var target: Int
    var saved: Int = 0
}

struct CardInfo: Codable {
    var name: String
    var frozen = false
}

final class Wallet: ObservableObject {
    @Published var balance: Int { didSet { save() } }
    @Published var history: [Entry] { didSet { save() } }
    @Published var cards: [CardInfo] { didSet { save() } }
    @Published var selected: Int { didSet { save() } }
    @Published var requests: [MoneyRequest] { didSet { save() } }
    @Published var goals: [Goal] { didSet { save() } }

    private let key = "bubblecash.wallet.v2"

    private struct Saved: Codable {
        var balance: Int
        var history: [Entry]
        var cards: [CardInfo]
        var selected: Int
        var requests: [MoneyRequest]
        var goals: [Goal]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Saved.self, from: data) {
            balance = s.balance; history = s.history; cards = s.cards
            selected = s.selected; requests = s.requests; goals = s.goals
        } else {
            balance = 1000
            history = [Entry(title: "Welcome bubbles", amount: 1000, date: Date(), card: 0)]
            cards = [CardInfo(name: "Black Card"), CardInfo(name: "Neon Card"),
                     CardInfo(name: "Blue Card"), CardInfo(name: "Pink Card")]
            selected = 0; requests = []; goals = []
        }
    }

    private func save() {
        let s = Saved(balance: balance, history: history, cards: cards,
                      selected: selected, requests: requests, goals: goals)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var currentCard: CardInfo { cards[selected] }

    func add(_ amount: Int, title: String) {
        guard amount > 0 else { return }
        balance += amount
        history.insert(Entry(title: title, amount: amount, date: Date(), card: selected), at: 0)
    }

    @discardableResult
    func spend(_ amount: Int, title: String) -> Bool {
        guard amount > 0, amount <= balance else { return false }
        balance -= amount
        history.insert(Entry(title: title, amount: -amount, date: Date(), card: selected), at: 0)
        return true
    }

    func step(_ dir: Int) {
        selected = (selected + dir + cards.count) % cards.count
    }

    // Requests
    func markPaid(_ r: MoneyRequest) {
        requests.removeAll { $0.id == r.id }
        add(r.amount, title: "Received from \(r.phone)")
    }
    func cancel(_ r: MoneyRequest) { requests.removeAll { $0.id == r.id } }

    // Goals
    func fund(_ goalID: UUID, _ amount: Int) -> Bool {
        guard let i = goals.firstIndex(where: { $0.id == goalID }), amount > 0, amount <= balance else { return false }
        goals[i].saved += amount
        spend(amount, title: "Saved to \(goals[i].name)")
        return true
    }
    func deleteGoal(_ goalID: UUID) {
        guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
        let g = goals.remove(at: i)
        if g.saved > 0 { add(g.saved, title: "Returned from \(g.name)") }
    }
}

enum Auth {
    /// Shows the iPhone's Face ID prompt (falls back to passcode).
    static func confirm(_ reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return true }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
