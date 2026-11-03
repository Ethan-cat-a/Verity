import SwiftUI
import UniformTypeIdentifiers

/// The full Verity conversation/document surface, opened from the desktop pet.
struct VerityDesktopView: View {
    @ObservedObject private var model = VerityModel.shared
    @StateObject private var conversation = VerityConversationModel()
    @State private var isDropTargeted = false
    @State private var isConversationOpen = false
    @State private var isScreenContextOpen = false
    @State private var isMemoryManagerOpen = false
    @AppStorage(VerityPrivacyPreferences.screenContextEnabledKey) private var screenContextEnabled = false

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
        .sheet(isPresented: $isScreenContextOpen) {
            VerityScreenContextSheet()
        }
        .sheet(isPresented: $isMemoryManagerOpen) {
            VerityMemoryManagerView { snapshot in
                conversation.resumeSession(snapshot)
                isConversationOpen = true
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
                .help("Close this window (Verity stays on your desktop)")
            }

            Spacer(minLength: 0)

            VerityFace(
                size: 235,
                mood: isDropTargeted ? .manic : (model.isEating ? .eating : model.mood)
            )
            .shadow(color: .orange.opacity(0.18), radius: 16, y: 10)
            .animation(.spring(response: 0.34, dampingFraction: 0.60), value: model.mood)
            .animation(.spring(response: 0.30, dampingFraction: 0.62), value: model.isEating)

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

            Button {
                isScreenContextOpen = true
            } label: {
                Label("Understand a window", systemImage: "macwindow")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 35)
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(screenContextEnabled ? "Choose a window for Verity to read" : "Enable this in Settings → Trust Center first")

            Button {
                isMemoryManagerOpen = true
            } label: {
                Label("Memory & sessions", systemImage: "brain")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 35)
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Label("Double-click the desktop ball to open this window", systemImage: "cursorarrow.click")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(19)
        .frame(width: 380, height: 560)
    }

    private var homeCaption: String {
        if isDropTargeted { return "GIVE ME THE FILE." }
        if model.isEating { return "NOM NOM NOM. NO REFUNDS." }
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
        case .happy: return "I'm here. Try not to make this complicated."
        case .eerie: return "..."
        }
    }
}

/// A transparent, borderless desktop helper docked in the lower-right corner.
struct VerityDesktopPetView: View {
    @ObservedObject private var model = VerityModel.shared
    @ObservedObject private var controller = VerityPanelController.shared
    @StateObject private var petLife = VerityPetLifeModel()
    @State private var isBreathing = false
    @State private var isChomping = false
    @State private var isHovering = false
    @AppStorage(VerityPetLifeModel.eerieIdlePreferenceKey) private var eerieIdleEnabled = true

    var body: some View {
        ZStack {
            VerityFace(
                size: 142,
                mood: model.isEating ? .eating : model.mood
            )
            .scaleEffect(model.isEating ? (isChomping ? 1.045 : 0.965) : (isBreathing ? 1.006 : 0.998))
            .offset(y: isBreathing && !model.isEating ? -0.7 : 0.7)
            .rotationEffect(.degrees(model.mood == .eerie ? -2.5 : (model.mood == .angry ? -4 : 0)))
            .shadow(color: .black.opacity(0.30), radius: 13, y: 8)
            .animation(.spring(response: 0.15, dampingFraction: 0.50), value: isChomping)
            .animation(.easeInOut(duration: 0.55), value: model.mood)
            .contentShape(Circle())
            .onTapGesture {
                controller.showCompanion()
            }
            .onHover { isHovering = $0 }
            .help("Click Verity to ask for help. Right-click for options.")

            if isHovering {
                Text("NEED A HAND?")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .offset(y: -79)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .allowsHitTesting(false)
            }

            if model.isEating {
                Text("CHOMP!")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -91)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            } else if petLife.hungerLevel > 0.68 {
                Text("FEED ME")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -91)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 180, height: 180)
        .background(Color.clear)
        .contentShape(Circle())
        .contextMenu {
            Button("Open Verity") { controller.showCompanion() }
            Button("Hide desktop pet") { controller.hidePet() }
        }
        .onAppear {
            petLife.start()
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .task(id: model.isEating) {
            guard model.isEating else {
                isChomping = false
                return
            }
            while !Task.isCancelled {
                withAnimation(.spring(response: 0.14, dampingFraction: 0.48)) {
                    isChomping.toggle()
                }
                try? await Task.sleep(nanoseconds: 155_000_000)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 38...72) * 1_000_000_000)
                guard !Task.isCancelled,
                      eerieIdleEnabled,
                      model.mood == .happy,
                      model.currentFile == nil,
                      !model.isEating else { continue }
                model.showReaction(.eerie, duration: UInt64.random(in: 2_800...4_200) * 1_000_000)
            }
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
    case eerie
}

/// Verity's deliberately simple, unsettling yellow sphere.
/// The talking and eating states alternate between two mouth frames.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy
    @State private var mouthOpen = false
    @State private var isBlinking = false

    private var animatedMouth: Bool {
        mood == .speaking || mood == .eating
    }

    private var wideMouth: Bool {
        mood == .manic || mood == .excited || mood == .eerie
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.91, green: 0.76, blue: 0.12),
                            Color(red: 0.88, green: 0.66, blue: 0.015),
                            Color(red: 0.59, green: 0.39, blue: 0.005)
                        ],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadius: size * 0.015,
                        endRadius: size * 0.82
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.34), lineWidth: max(1.2, size * 0.012)))

            HStack(spacing: size * 0.255) {
                eye(isLeft: true)
                eye(isLeft: false)
            }
            .offset(y: -size * 0.145)

            if mood == .angry || mood == .suspicious || mood == .eerie {
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
        .accessibilityLabel("Verity, a muted gold sphere with a crooked, unsettling grin")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_800...5_200) * 1_000_000)
                if mood == .eerie { continue }
                withAnimation(.easeInOut(duration: 0.075)) { isBlinking = true }
                try? await Task.sleep(nanoseconds: 115_000_000)
                withAnimation(.easeInOut(duration: 0.10)) { isBlinking = false }
            }
        }
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
        let heightFactor: CGFloat = isBlinking ? 0.018
            : (mood == .eerie ? (isLeft ? 0.19 : 0.115)
            : (mood == .sleepy ? 0.045
            : (mood == .angry ? 0.105 : (mood == .shocked ? 0.175 : 0.145))))
        let widthFactor: CGFloat = mood == .shocked || mood == .eerie ? 0.125 : 0.105
        let angle: Double = mood == .eerie ? (isLeft ? -5 : 7)
            : (mood == .angry ? (isLeft ? 15 : -15)
            : (mood == .suspicious ? (isLeft ? -7 : 8) : 0))

        return Ellipse()
            .fill(Color(red: 0.018, green: 0.014, blue: 0.009))
            .frame(width: size * widthFactor, height: size * heightFactor)
            .rotationEffect(.degrees(angle))
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: mood)
            .animation(.easeInOut(duration: 0.10), value: isBlinking)
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
        VerityClosedSmileShape()
            .stroke(
                Color.black,
                style: StrokeStyle(
                    lineWidth: max(2, size * 0.018),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size * (mood == .eerie ? 0.49 : 0.42), height: size * 0.10)
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
                Rectangle()
                    .fill(Color(red: 0.91, green: 0.85, blue: 0.66))
                    .frame(
                        width: size * (index == count / 2 ? 0.061 : 0.052),
                        height: toothHeight * (index.isMultiple(of: 2) ? 1.0 : 0.82)
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? 1.4 : -1.8))
            }
        }
    }
}

private struct VerityClosedSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.18))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.18),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.92)
        )
        return path
    }
}

private struct VeritySmileCavityShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.12))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.12),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY * 0.98),
            control2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY * 0.98)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.34))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.34),
            control1: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.minY + rect.height * 0.48),
            control2: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.48)
        )
        path.closeSubpath()
        return path
    }
}
