import SwiftUI
import UniformTypeIdentifiers

struct VerityDesktopView: View {
    @ObservedObject private var model = VerityModel.shared
    @StateObject private var conversation = VerityConversationModel()
    @State private var isDropTargeted = false
    @State private var isFloating = false
    @State private var isConversationOpen = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
                }

            if let file = model.currentFile {
                VerityFileInspectorView(file: file) { model.closeFile() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isConversationOpen {
                VerityConversationView(model: conversation) { isConversationOpen = false }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                characterHome.transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .frame(width: 380, height: 560)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: model.currentFile?.id)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isConversationOpen)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) { isFloating = true }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            FileDropHandler.handle(providers) { url in
                Task { @MainActor in
                    guard let url else {
                        model.setStatus("I couldn't open that. Try dropping a normal file.")
                        return
                    }
                    isConversationOpen = false
                    model.accept(fileURL: url)
                }
            }
        }
    }

    private var characterHome: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                    Text("VERITY")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { VerityPanelController.shared.hide() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 27, height: 27)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Hide Verity")
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(isDropTargeted ? 0.30 : 0.12))
                    .frame(width: 286, height: 286)
                    .blur(radius: 24)
                Circle()
                    .stroke(Color.orange.opacity(0.08), lineWidth: 1)
                    .frame(width: 274, height: 274)
                VerityFace(
                    size: 248,
                    mood: isDropTargeted ? .manic : (model.isEating ? .eating : model.mood)
                )
                .scaleEffect(model.isEating ? 0.90 : (isDropTargeted ? 1.07 : 1.0))
                .offset(y: isFloating && !model.isEating ? -6 : 5)
                .rotationEffect(.degrees(model.mood == .angry ? -3 : (model.mood == .manic ? 2 : 0)))
                .shadow(color: .orange.opacity(0.18), radius: 18, y: 12)
                .animation(.spring(response: 0.34, dampingFraction: 0.55), value: isDropTargeted)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: model.isEating)
                .animation(.spring(response: 0.4, dampingFraction: 0.58), value: model.mood)
            }
            .frame(height: 286)

            Text(homeCaption)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text(model.statusMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 30)

            Button {
                conversation.refreshVoiceStatus()
                isConversationOpen = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text("Talk with Verity")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 46)
                .background(Color(red: 0.13, green: 0.14, blue: 0.16), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Label("Or drop a file on me to read it", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(19)
        .frame(width: 380, height: 560)
        .contentShape(Rectangle())
    }

    private var homeCaption: String {
        if isDropTargeted { return "GIVE ME THE FILE." }
        switch model.mood {
        case .listening: return "I'm listening."
        case .thinking: return "Processing. Be patient."
        case .speaking: return "I HAVE THOUGHTS."
        case .shocked: return "EXCUSE ME?"
        case .suspicious: return "That seems suspicious."
        case .angry: return "I AM NOT AMUSED."
        case .manic, .excited: return "LET'S GOOOO."
        case .sleepy: return "five more minutes..."
        case .eating: return "NOM NOM NOM."
        case .happy: return "Hey. It's me. It's Verity."
        }
    }
}

enum VerityMood: Equatable {
    case happy
    case excited
    case eating
    case listening
    case thinking
    case speaking
    case sleepy
    case shocked
    case suspicious
    case angry
    case manic
}

/// Verity's deliberately simple, unsettling yellow sphere.
/// The talking and eating states alternate between two mouth frames.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy
    @State private var mouthOpen = false

    private var animatedMouth: Bool {
        mood == .speaking || mood == .eating
    }

    private var wideMouth: Bool {
        mood == .manic || mood == .excited
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.99, blue: 0.30),
                            Color(red: 1.0, green: 0.91, blue: 0.02),
                            Color(red: 0.88, green: 0.65, blue: 0.0)
                        ],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadius: size * 0.015,
                        endRadius: size * 0.82
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: max(1, size * 0.009)))
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.30))
                        .frame(width: size * 0.20, height: size * 0.075)
                        .blur(radius: size * 0.012)
                        .rotationEffect(.degrees(-30))
                        .offset(x: size * 0.19, y: size * 0.105)
                }

            HStack(spacing: size * 0.255) {
                eye(isLeft: true)
                eye(isLeft: false)
            }
            .offset(y: -size * 0.145)

            if mood == .angry || mood == .suspicious {
                HStack(spacing: size * 0.21) {
                    brow(isLeft: true)
                    brow(isLeft: false)
                }
                .offset(y: -size * 0.255)
            }

            mouth
                .offset(y: size * 0.185)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verity, a yellow smiley sphere with an exaggerated toothy grin")
        .task(id: mood) {
            guard animatedMouth else {
                mouthOpen = wideMouth || mood == .shocked
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.075)) {
                    mouthOpen.toggle()
                }
                try? await Task.sleep(nanoseconds: mood == .eating ? 145_000_000 : 175_000_000)
            }
        }
    }

    private func eye(isLeft: Bool) -> some View {
        let heightFactor: CGFloat = mood == .sleepy ? 0.045
            : (mood == .angry ? 0.105 : (mood == .shocked ? 0.175 : 0.145))
        let widthFactor: CGFloat = mood == .shocked ? 0.135 : 0.105
        let angle: Double = mood == .angry ? (isLeft ? 15 : -15)
            : (mood == .suspicious ? (isLeft ? -7 : 8) : 0)

        return Ellipse()
            .fill(Color(red: 0.018, green: 0.014, blue: 0.009))
            .frame(width: size * widthFactor, height: size * heightFactor)
            .overlay(alignment: .topTrailing) {
                if mood != .sleepy {
                    Circle()
                        .fill(.white.opacity(0.80))
                        .frame(width: size * 0.022, height: size * 0.022)
                        .offset(x: -size * 0.018, y: size * 0.018)
                }
            }
            .rotationEffect(.degrees(angle))
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: mood)
    }

    private func brow(isLeft: Bool) -> some View {
        Capsule()
            .fill(Color.black)
            .frame(width: size * 0.15, height: size * 0.023)
            .rotationEffect(.degrees(mood == .angry ? (isLeft ? 18 : -18) : (isLeft ? -12 : 10)))
            .offset(y: isLeft ? size * 0.008 : -size * 0.004)
    }

    @ViewBuilder
    private var mouth: some View {
        if mood == .shocked {
            Ellipse()
                .fill(Color.black)
                .frame(width: size * 0.22, height: size * 0.29)
                .overlay(alignment: .bottom) {
                    toothRow(count: 4, toothHeight: size * 0.045)
                        .padding(.bottom, size * 0.018)
                }
                .frame(width: size * 0.26, height: size * 0.32)
        } else if mouthOpen || wideMouth {
            openGrin
        } else {
            closedGrin
        }
    }

    private var closedGrin: some View {
        ZStack(alignment: .top) {
            VerityClosedGrinShape()
                .fill(Color.black)
            toothRow(count: 7, toothHeight: size * 0.065)
                .padding(.top, size * 0.035)
        }
        .frame(width: size * 0.64, height: size * 0.24)
    }

    private var openGrin: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
                .fill(Color.black)
                .frame(width: size * (wideMouth ? 0.48 : 0.39), height: size * (wideMouth ? 0.34 : 0.29))
            Ellipse()
                .fill(Color(red: 0.38, green: 0.035, blue: 0.025).opacity(0.95))
                .frame(width: size * 0.22, height: size * 0.09)
                .offset(y: size * 0.105)
            VStack(spacing: size * 0.075) {
                toothRow(count: wideMouth ? 8 : 7, toothHeight: size * 0.064)
                Spacer(minLength: size * 0.015)
                toothRow(count: wideMouth ? 7 : 5, toothHeight: size * 0.050)
            }
            .frame(width: size * (wideMouth ? 0.43 : 0.34), height: size * 0.25)
            .padding(.vertical, size * 0.015)
        }
        .frame(width: size * 0.53, height: size * 0.37)
    }

    private func toothRow(count: Int, toothHeight: CGFloat) -> some View {
        HStack(spacing: size * 0.006) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.012, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.94, blue: 0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.012, style: .continuous)
                            .stroke(Color.black.opacity(0.22), lineWidth: max(0.5, size * 0.003))
                    }
                    .frame(
                        width: size * (index == count / 2 ? 0.066 : 0.056),
                        height: toothHeight
                    )
            }
        }
    }
}

private struct VerityClosedGrinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.015, y: rect.minY + rect.height * 0.10))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.015, y: rect.minY + rect.height * 0.10),
            control1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY * 0.91),
            control2: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY * 0.91)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.38))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.38),
            control1: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.minY + rect.height * 0.69),
            control2: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.69)
        )
        path.closeSubpath()
        return path
    }
}
