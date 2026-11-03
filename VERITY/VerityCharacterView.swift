import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The full Verity conversation/document surface, opened from the desktop pet.
struct VerityDesktopView: View {
    @ObservedObject private var model = VerityModel.shared
    @StateObject private var conversation = VerityConversationModel()
    @State private var isDropTargeted = false
    @State private var isConversationOpen = false
    @State private var isScreenContextOpen = false
    @State private var isMemoryManagerOpen = false
    @State private var isCommandPaletteOpen = false
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
        .sheet(isPresented: $isCommandPaletteOpen) {
            VerityCommandPaletteView(
                onTalk: { isConversationOpen = true },
                onStudy: { isScreenContextOpen = true },
                onMemory: { isMemoryManagerOpen = true },
                onSettings: {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            )
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
                Button { isCommandPaletteOpen = true } label: {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 27, height: 27)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("k", modifiers: [.command])
                .help("Open command palette · Command-K")

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

            Label("Click Verity to open the assistant", systemImage: "cursorarrow.click")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(19)
        .frame(width: 380, height: 560)
    }

    private var homeCaption: String {
        if isDropTargeted { return "Ooh, a file! Let me take a look." }
        if model.isEating { return "Just having a little look!" }
        switch model.mood {
        case .listening: return "I'm listening! Go ahead."
        case .thinking: return "Just a second. I've got this."
        case .speaking: return "See? I told you I could help."
        case .shocked: return "Oh! I wasn't expecting that."
        case .suspicious: return "Hmm. Something isn't quite right."
        case .angry: return "Oh dear. That wasn't a good idea."
        case .manic, .excited: return "Good. We're making progress."
        case .sleepy: return "A tiny break? Oh, all right. I'm ready now!"
        case .eating: return "Ooh, what's this?"
        case .happy: return "Hello. What can I help you with?"
        case .eerie: return "..."
        }
    }
}

/// A compact keyboard-friendly launcher for VERITY's main workflows.
private struct VerityCommandPaletteView: View {
    let onTalk: () -> Void
    let onStudy: () -> Void
    let onMemory: () -> Void
    let onSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VERITY COMMANDS")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Text("What would you like to do?")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            command("Talk with Verity", detail: "Ask a question or use your microphone", icon: "waveform", key: "1", action: onTalk)
            command("Study / understand a window", detail: "Capture one window, review it, then choose a study action", icon: "book.closed", key: "2", action: onStudy)
            command("Memory & saved sessions", detail: "Review saved notes or resume a conversation", icon: "brain", key: "3", action: onMemory)
            command("Verity Settings", detail: "Privacy, voice, updates and appearance", icon: "gearshape", key: "4", action: onSettings)
        }
        .padding(18)
        .frame(width: 390)
        .background(.ultraThinMaterial)
    }

    private func command(
        _ title: String,
        detail: String,
        icon: String,
        key: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 30, height: 30)
                    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("⌘\(key)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(9)
            .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(key.first ?? "1"), modifiers: [.command])
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
    @AppStorage(VerityPrivacyPreferences.quietPresenceEnabledKey) private var quietPresenceEnabled = false

    var body: some View {
        ZStack {
            VerityFace(
                size: quietPresenceEnabled ? 88 : 142,
                mood: model.isEating ? .eating : model.mood
            )
            .opacity(quietPresenceEnabled ? 0.88 : 1.0)
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
                Text("SAMPLE ACQUIRED")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -91)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            } else if petLife.hungerLevel > 0.68 {
                Text("NO FILE. NO PROGRESS.")
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
            Button("Hide desktop helper") { controller.hidePet() }
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
                try? await Task.sleep(nanoseconds: UInt64.random(in: 52...138) * 1_000_000_000)
                guard !Task.isCancelled,
                      eerieIdleEnabled,
                      model.mood == .happy,
                      model.currentFile == nil,
                      !model.isEating else { continue }
                model.showReaction(.eerie, duration: UInt64.random(in: 2_400...3_600) * 1_000_000)
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

/// Verity's original look: a bright yellow smiley sphere with simple black features.
 /// The unsettling face is reserved for a short, occasional idle reaction.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy
    @State private var mouthOpen = false
    @State private var isBlinking = false

    private var animatedMouth: Bool {
        mood == .speaking || mood == .eating
    }

    private var wideMouth: Bool {
        mood == .eerie
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.28),
                            Color(red: 1.0, green: 0.88, blue: 0.02),
                            Color(red: 0.91, green: 0.68, blue: 0.0)
                        ],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadius: size * 0.015,
                        endRadius: size * 0.82
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: max(1, size * 0.008)))
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.34))
                        .frame(width: size * 0.23, height: size * 0.085)
                        .blur(radius: size * 0.014)
                        .rotationEffect(.degrees(-28))
                        .offset(x: size * 0.16, y: size * 0.095)
                }

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
        .accessibilityLabel("Verity, a bright yellow smiley sphere with black oval eyes and a curved smile")
        .task(id: mood) {
            if mood == .eerie {
                isBlinking = false
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_800...5_200) * 1_000_000)
                guard mood != .eerie else {
                    isBlinking = false
                    continue
                }
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
            : (mood == .eerie ? (isLeft ? 0.19 : 0.12)
            : (mood == .sleepy ? 0.055
            : (mood == .shocked ? 0.18 : 0.15)))
        let widthFactor: CGFloat = mood == .eerie ? 0.12 : (mood == .shocked ? 0.13 : 0.105)
        let angle: Double = mood == .eerie ? (isLeft ? -5 : 7)
            : (mood == .angry ? (isLeft ? 15 : -15)
            : (mood == .suspicious ? (isLeft ? -7 : 8) : 0))

        return Ellipse()
            .fill(Color(red: 0.012, green: 0.010, blue: 0.006))
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
                .frame(width: size * 0.17, height: size * 0.23)
        } else if mood == .eerie {
            openGrin
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
            .frame(width: size * 0.36, height: size * 0.09)
    }

    private var openGrin: some View {
        let grinWidth: CGFloat = mood == .eerie ? 0.48 : (wideMouth ? 0.40 : 0.29)
        let grinHeight: CGFloat = mood == .eerie ? 0.34 : (wideMouth ? 0.28 : 0.20)
        let toothCount = mood == .eerie ? 8 : 5

        return ZStack {
            Ellipse()
                .fill(Color.black)
                .frame(width: size * grinWidth, height: size * grinHeight)

            Ellipse()
                .fill(Color(red: 0.55, green: 0.04, blue: 0.035))
                .frame(width: size * grinWidth * 0.66, height: size * grinHeight * 0.30)
                .offset(y: size * grinHeight * 0.28)

            VStack(spacing: size * 0.045) {
                toothRow(count: toothCount, toothHeight: size * (mood == .eerie ? 0.060 : 0.035))
                if mood == .eerie {
                    Spacer(minLength: size * 0.012)
                    toothRow(count: 7, toothHeight: size * 0.046)
                }
            }
            .frame(width: size * grinWidth * 0.88, height: size * grinHeight * 0.78)
            .padding(.vertical, size * 0.008)
        }
        .frame(width: size * 0.53, height: size * 0.37)
    }

    private func toothRow(count: Int, toothHeight: CGFloat) -> some View {
        HStack(spacing: size * 0.006) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.008, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.96, blue: 0.82))
                    .frame(
                        width: size * (index == count / 2 ? 0.055 : 0.047),
                        height: toothHeight
                    )
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
