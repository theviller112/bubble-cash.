import SwiftUI

struct TransferView: View {
    enum Mode { case add, send }
    enum Stage { case form, review, verifying, processing, done }

    let mode: Mode
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss

    @State private var amount: String
    @State private var phone = ""
    @State private var error: String?
    @State private var stage: Stage = .form

    private let presets = [100, 1000, 5000, 15000]

    init(mode: Mode) {
        self.mode = mode
        _amount = State(initialValue: mode == .add ? "80,000" : "")
    }

    private var value: Int { amountValue(amount) }
    private var verb: String { mode == .add ? "Add" : "Send" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.07).ignoresSafeArea()
                if stage == .form { form.transition(.move(edge: .leading).combined(with: .opacity)) }
                else { review.transition(.move(edge: .trailing).combined(with: .opacity)) }
            }
            .animation(Theme.spring, value: stage == .form)
            .navigationTitle(stage == .form ? "\(verb) Cash" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(stage == .verifying || stage == .processing)
                }
            }
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 0) {
            Form {
                if mode == .send {
                    LabeledContent("To") { PhoneField(text: $phone) }
                }
                LabeledContent("Amount") { AmountField(text: $amount) }

                Section {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { p in
                            Button(fmt(p)) { amount = fmt(p) }
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(Theme.raised, in: Capsule())
                                .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if let error {
                    Text(error).foregroundStyle(.red).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)

            Button(action: goToReview) {
                Text("Review").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .foregroundStyle(.black)
            .padding(16)
        }
    }

    private func goToReview() {
        guard value > 0 else { error = "Enter an amount"; return }
        if mode == .send {
            guard phone.filter(\.isNumber).count == 10 else { error = "Enter a 10-digit number"; return }
            guard value <= wallet.balance else { error = "Not enough Bubble Cash"; return }
            guard !wallet.currentCard.frozen else { error = "\(wallet.currentCard.name) is frozen"; return }
        }
        error = nil
        stage = .review
    }

    // MARK: Review

    private var review: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    BubbleSymbol(size: 28)
                    Text(fmt(value)).font(.system(size: 52, weight: .bold)).monospacedDigit()
                }
                Text(mode == .add ? "Adding to your balance" : "Sending to \(phone)")
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 30)

            VStack(spacing: 0) {
                row(mode == .add ? "To card" : "From card", wallet.currentCard.name)
                if mode == .send { Divider().padding(.leading, 16); row("To", phone) }
                Divider().padding(.leading, 16)
                row("Fee", "Free")
                Divider().padding(.leading, 16)
                row("New balance", fmt(wallet.balance + (mode == .add ? value : -value)))
            }
            .background(Theme.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(16)

            Spacer()

            Group {
                switch stage {
                case .verifying:
                    Text("Confirm with Face ID").foregroundStyle(Theme.muted)
                case .processing:
                    VStack(spacing: 8) { ProgressView(); Text("Processing…").foregroundStyle(Theme.muted) }
                case .done:
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44)).foregroundStyle(Theme.green)
                            .transition(.scale.combined(with: .opacity))
                        Text(mode == .add ? "Added" : "Sent").font(.headline)
                    }
                default:
                    VStack(spacing: 6) {
                        Button(action: confirm) {
                            Text("Confirm & \(verb)").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .foregroundStyle(.black)
                        Button("Edit") { stage = .form }
                    }
                }
            }
            .frame(minHeight: 110)
            .padding(16)
            .animation(Theme.spring, value: stage)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(Theme.muted)
            Spacer()
            Text(v).fontWeight(.medium).monospacedDigit()
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
    }

    private func confirm() {
        stage = .verifying
        Task {
            let ok = await Auth.confirm(mode == .add ? "Confirm adding cash" : "Confirm sending cash")
            guard ok else {
                await MainActor.run { stage = .review; haptic(.error) }
                return
            }
            await MainActor.run { stage = .processing }
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                withAnimation(Theme.spring) {
                    if mode == .add { wallet.add(value, title: "Added Bubble Cash") }
                    else { _ = wallet.spend(value, title: "Sent to \(phone)") }
                }
                stage = .done
                haptic()
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run { dismiss() }
        }
    }
}
