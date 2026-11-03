
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
                        .strokeBorder(Color.white.opacity(0.52), lineWidth: 1)
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
                    Text("VERITY").font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2.5).foregroundStyle(.secondary)
                }
                Spacer()
                Button { VerityPanelController.shared.hide() } label: {
                    Image(systemName: "minus").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary).frame(width: 27, height: 27)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain).help("Hide Verity")
            }

            Spacer(minLength: 0)

            ZStack {
                Circle().fill(Color.yellow.opacity(isDropTargeted ? 0.30 : 0.16))
                    .frame(width: 286, height: 286).blur(radius: 24)
                Circle().stroke(Color.orange.opacity(0.10), lineWidth: 1).frame(width: 274, height: 274)
                VerityFace(size: 248, mood: isDropTargeted ? .excited : (model.isEating ? .eating : model.mood))
                    .scaleEffect(model.isEating ? 0.78 : (isDropTargeted ? 1.07 : 1.0))
                    .offset(y: isFloating && !model.isEating ? -6 : 5)
                    .rotationEffect(.degrees(model.mood == .excited ? 5 : 0))
                    .shadow(color: .orange.opacity(0.20), radius: 18, y: 12)
                    .animation(.spring(response: 0.34, dampingFraction: 0.55), value: isDropTargeted)
                    .animation(.spring(response: 0.25, dampingFraction: 0.45), value: model.isEating)
                    .animation(.spring(response: 0.4, dampingFraction: 0.58), value: model.mood)
            }
            .frame(height: 286)

            Text(isDropTargeted ? "YIPPEE! FOOD!" : model.mood == .listening ? "I'm listening!" : model.mood == .thinking ? "Hmm, let me think…" : model.mood == .speaking ? "Here's what I think!" : "Hey! I'm Verity.")
                .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.primary)

            Text(model.statusMessage).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2).frame(height: 30)

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
                .foregroundStyle(.white).padding(.horizontal, 17).frame(height: 46)
                .background(Color(red: 0.13, green: 0.14, blue: 0.16), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Label("Or drop a file on me to read it", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(19).frame(width: 380, height: 560).contentShape(Rectangle())
    }
}

enum VerityMood: Equatable {
    case happy, excited, eating, listening, thinking, speaking, sleepy
}

/// A glossy yellow spherical mascot with softly shaded surface, eye highlights,
/// cheek glow, blinking, and expressions synchronized with the conversation.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy
    @State private var isBlinking = false
    @State private var mouthIsOpen = false
    private let ink = Color(red: 0.035, green: 0.035, blue: 0.025)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.99, blue: 0.62), location: 0),
                        .init(color: Color(red: 1.0, green: 0.94, blue: 0.22), location: 0.35),
                        .init(color: Color(red: 1.0, green: 0.83, blue: 0.02), location: 0.72),
                        .init(color: Color(red: 0.91, green: 0.61, blue: 0.0), location: 1)
                    ]),
                    center: UnitPoint(x: 0.29, y: 0.20),
                    startRadius: size * 0.01, endRadius: size * 0.88
                ))
                .overlay {
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.24), .clear, .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay { Circle().stroke(Color(red: 0.83, green: 0.57, blue: 0).opacity(0.34), lineWidth: max(0.8, size * 0.008)) }
                .overlay(alignment: .topLeading) {
                    Ellipse().fill(LinearGradient(colors: [.white.opacity(0.82), .white.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size * 0.30, height: size * 0.105).blur(radius: size * 0.012)
                        .rotationEffect(.degrees(-34)).offset(x: size * 0.15, y: size * 0.105)
                }
                .overlay(alignment: .bottomTrailing) {
                    Ellipse().fill(Color(red: 0.75, green: 0.42, blue: 0).opacity(0.20))
                        .frame(width: size * 0.36, height: size * 0.16).blur(radius: size * 0.06)
                        .offset(x: size * 0.03, y: -size * 0.02)
                }

            HStack(spacing: size * 0.235) { eye; eye }.offset(y: -size * 0.14)
            HStack(spacing: size * 0.30) { cheek; cheek }.offset(y: size * 0.12)
            mouth.offset(y: size * 0.19)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verity, a glossy yellow spherical smiley companion")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_600_000_000)
                withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.10)) { isBlinking = false }
            }
        }
        .task(id: mood) {
            guard mood == .speaking || mood == .eating else {
                mouthIsOpen = mood == .listening || mood == .excited
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.12)) { mouthIsOpen.toggle() }
                try? await Task.sleep(nanoseconds: 170_000_000)
            }
        }
    }

    private var eye: some View {
        Ellipse().fill(ink)
            .frame(width: size * 0.108, height: size * (isBlinking || mood == .sleepy ? 0.025 : 0.145))
            .overlay(alignment: .topTrailing) {
                if !isBlinking && mood != .sleepy {
                    Circle().fill(.white.opacity(0.90)).frame(width: size * 0.025, height: size * 0.025)
                        .offset(x: -size * 0.018, y: size * 0.014)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isBlinking)
    }

    private var cheek: some View {
        Ellipse().fill(Color(red: 1.0, green: 0.46, blue: 0.16).opacity(0.26))
            .frame(width: size * 0.12, height: size * 0.055).blur(radius: size * 0.018)
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .happy:
            VeritySmileShape().stroke(ink, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.57, height: size * 0.28)
        case .excited:
            Ellipse().fill(ink).frame(width: size * 0.18, height: size * 0.21).scaleEffect(y: mouthIsOpen ? 1.05 : 0.88)
        case .eating, .speaking:
            Ellipse().fill(ink).frame(width: size * (mouthIsOpen ? 0.25 : 0.17), height: size * (mouthIsOpen ? 0.19 : 0.10))
        case .listening:
            Ellipse().stroke(ink, lineWidth: size * 0.027).frame(width: size * 0.105, height: size * 0.13)
        case .thinking, .sleepy:
            Capsule().fill(ink).frame(width: size * 0.16, height: size * 0.025)
        }
    }
}

private struct VeritySmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = CGPoint(x: rect.minX + rect.width * 0.025, y: rect.minY + rect.height * 0.13)
        let right = CGPoint(x: rect.maxX - rect.width * 0.025, y: rect.minY + rect.height * 0.13)
        path.move(to: left)
        path.addCurve(to: right,
            control1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY * 1.18),
            control2: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY * 1.18))
        path.move(to: CGPoint(x: left.x + rect.width * 0.035, y: left.y + rect.height * 0.07))
        path.addLine(to: left)
        path.addLine(to: CGPoint(x: left.x + rect.width * 0.005, y: left.y - rect.height * 0.09))
        path.move(to: CGPoint(x: right.x - rect.width * 0.035, y: right.y + rect.height * 0.07))
        path.addLine(to: right)
        path.addLine(to: CGPoint(x: right.x - rect.width * 0.005, y: right.y - rect.height * 0.09))
        return path
    }
}
