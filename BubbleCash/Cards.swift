import SwiftUI

struct CardView: View {
    let index: Int
    let name: String
    let balance: Int
    let frozen: Bool

    private let bubbles: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.84, 0.22, 0.24), (0.66, 0.74, 0.12), (0.93, 0.84, 0.09), (0.46, 0.14, 0.05), (0.74, 0.46, 0.05)
    ]

    private var isDarkText: Bool { index == 1 || index == 3 }

    @ViewBuilder private var background: some View {
        switch index {
        case 0:
            RadialGradient(colors: [Color(white: 0.17), Color(white: 0.04), .black],
                           center: .topLeading, startRadius: 0, endRadius: 420)
        case 1:
            LinearGradient(colors: Theme.bubble, startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            LinearGradient(colors: [Color(red: 0.04, green: 0.16, blue: 0.42),
                                    Color(red: 0.09, green: 0.47, blue: 0.85),
                                    Color(red: 0.31, green: 0.84, blue: 0.93)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            LinearGradient(colors: [Color(red: 1, green: 0.48, blue: 0.64),
                                    Color(red: 1, green: 0.70, blue: 0.54)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack(alignment: .topLeading) {
            background
            GeometryReader { geo in
                ForEach(0..<bubbles.count, id: \.self) { i in
                    let b = bubbles[i]
                    let d = b.r * geo.size.width
                    Circle()
                        .fill(.white.opacity(index == 0 ? 0.04 : 0.18))
                        .overlay(Circle().stroke(.white.opacity(index == 0 ? 0.18 : 0.6), lineWidth: 1.5))
                        .overlay(
                            Circle().fill(.white.opacity(index == 0 ? 0.35 : 0.75))
                                .frame(width: d * 0.16, height: d * 0.16)
                                .offset(x: -d * 0.22, y: -d * 0.22)
                        )
                        .frame(width: d, height: d)
                        .position(x: b.x * geo.size.width, y: b.y * geo.size.height)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                EmptyView()
                Text(name).font(.title2.weight(.bold))
                Spacer()
                Text("BALANCE").font(.caption2.weight(.semibold)).opacity(0.7)
                HStack(spacing: 6) {
                    BubbleSymbol(size: 20)
                    Text(fmt(balance))
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(isDarkText ? Color.black.opacity(0.85) : .white)
            .padding(.horizontal, 22).padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if frozen {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Text("FROZEN").font(.headline.weight(.heavy)).tracking(4).foregroundStyle(.white)
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(index == 0 ? 0.12 : 0), lineWidth: 1))
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), balance \(fmt(balance))\(frozen ? ", frozen" : "")")
    }
}

/// Stacked cards: drag the top card left/right to flip to the next one, tap it for settings.
struct CardStack: View {
    @EnvironmentObject var wallet: Wallet
    var onTap: (() -> Void)? = nil
    @State private var drag: CGSize = .zero

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                ForEach(wallet.cards.indices, id: \.self) { i in
                    let n = wallet.cards.count
                    let k = (i - wallet.selected + n) % n
                    CardView(index: i, name: wallet.cards[i].name, balance: wallet.balance, frozen: wallet.cards[i].frozen)
                        .scaleEffect(1 - CGFloat(k) * 0.055, anchor: .bottom)
                        .offset(y: CGFloat(k) * 13)
                        .brightness(-Double(k) * 0.12)
                        .opacity(k > 2 ? 0 : 1)
                        .offset(k == 0 ? drag : .zero)
                        .rotationEffect(.degrees(k == 0 ? Double(drag.width / 22) : 0))
                        .zIndex(Double(n - k))
                        .allowsHitTesting(k == 0)
                        .onTapGesture { onTap?() }
                        .gesture(dragGesture)
                }
            }
            .padding(.bottom, 26)
            .animation(Theme.spring, value: wallet.selected)

            HStack(spacing: 7) {
                ForEach(wallet.cards.indices, id: \.self) { i in
                    Button {
                        withAnimation(Theme.spring) { wallet.selected = i }
                    } label: {
                        Capsule()
                            .fill(i == wallet.selected ? Color.white : Color(white: 0.23))
                            .frame(width: i == wallet.selected ? 20 : 7, height: 7)
                    }
                    .accessibilityLabel(wallet.cards[i].name)
                }
            }
            .animation(Theme.spring, value: wallet.selected)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                drag = CGSize(width: v.translation.width, height: v.translation.height * 0.15)
            }
            .onEnded { v in
                let w = v.translation.width
                guard abs(w) > 70 else {
                    withAnimation(Theme.spring) { drag = .zero }
                    return
                }
                withAnimation(.easeIn(duration: 0.18)) {
                    drag = CGSize(width: w < 0 ? -520 : 520, height: 20)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    drag = .zero
                    withAnimation(Theme.spring) { wallet.step(w < 0 ? 1 : -1) }
                }
            }
    }
}
