import SwiftUI
import UIKit

struct PayView: View {
    @EnvironmentObject var wallet: Wallet
    @Environment(\.dismiss) private var dismiss

    @State private var amount = "50"
    @State private var item = ""
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var stage: Stage = .ready
    @State private var message: String?
    @State private var timer: Timer?

    enum Stage { case ready, verifying, done }
    private let holdSeconds: CGFloat = 1.1

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                CardStack()
                    .padding(.horizontal, 20)
                    .disabled(stage != .ready)

                VStack(spacing: 4) {
                    TextField("What's it for?", text: $item)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                    HStack(spacing: 8) {
                        BubbleSymbol(size: 28).foregroundStyle(Theme.accent)
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 48, weight: .bold))
                            .monospacedDigit()
                            .fixedSize()
                            .onChange(of: amount) { _, new in
                                let f = commaFormat(new)
                                if f != new { amount = f }
                            }
                    }
                }
                .disabled(stage != .ready)

                Spacer(minLength: 10)

                ring

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(message != nil && stage == .ready ? Color.red : .white)
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.muted)
                }
                .animation(.easeOut(duration: 0.2), value: stage)
            }
            .padding(.vertical, 12)
            .background(Color(white: 0.07).ignoresSafeArea())
            .navigationTitle("Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stage == .done ? "Done" : "Cancel") { dismiss() }
                }
            }
            .onDisappear { timer?.invalidate() }
        }
    }

    private var title: String {
        switch stage {
        case .ready: message ?? "Hold to Pay"
        case .verifying: "Confirm with Face ID"
        case .done: "Paid \(amount)"
        }
    }

    private var subtitle: String {
        switch stage {
        case .ready: "Keep holding until the ring fills"
        case .verifying: " "
        case .done: "with \(wallet.currentCard.name)"
        }
    }

    private var ring: some View {
        ZStack {
            Circle().fill(Theme.group)
            Circle().stroke(Theme.raised, lineWidth: 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: Theme.bubble + [Theme.bubble[0]], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Group {
                switch stage {
                case .ready:
                    Image(systemName: "circle.circle")
                        .font(.system(size: 46, weight: .medium))
                        .scaleEffect(1 + progress * 0.12)
                case .verifying:
                    ProgressView().controlSize(.large)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: 150, height: 150)
        .scaleEffect(holding ? 0.94 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: holding)
        .animation(Theme.spring, value: stage)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in endHold() }
        )
        .accessibilityLabel("Hold to pay")
        .accessibilityAddTraits(.isButton)
    }

    private func startHold() {
        guard timer == nil, stage == .ready else { return }
        if wallet.currentCard.frozen {
            message = "\(wallet.currentCard.name) is frozen"
            haptic(.error)
            return
        }
        message = nil
        holding = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let step: CGFloat = 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: Double(step), repeats: true) { t in
            MainActor.assumeIsolated {
                progress = min(1, progress + step / holdSeconds)
                if progress >= 1 {
                    t.invalidate()
                    timer = nil
                    holding = false
                    complete()
                }
            }
        }
    }

    private func endHold() {
        holding = false
        timer?.invalidate()
        timer = nil
        if stage == .ready {
            withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
        }
    }

    private func complete() {
        let v = amountValue(amount)
        guard v > 0 else { fail("Enter an amount"); return }
        guard v <= wallet.balance else { fail("Not enough balance"); return }
        stage = .verifying
        Task {
            let ok = await Auth.confirm("Confirm your payment")
            await MainActor.run {
                guard ok else { stage = .ready; fail("Face ID didn't match"); return }
                let what = item.trimmingCharacters(in: .whitespaces)
                withAnimation(Theme.spring) { _ = wallet.spend(v, title: what.isEmpty ? "Payment" : what) }
                stage = .done
                haptic()
            }
        }
    }

    private func fail(_ text: String) {
        message = text
        haptic(.error)
        withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
    }
}
