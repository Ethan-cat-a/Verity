import SwiftUI
import UniformTypeIdentifiers

struct VerityDesktopView: View {
    @ObservedObject private var model = VerityModel.shared
    @State private var isDropTargeted = false
    @State private var isFloating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                }

            if let file = model.currentFile {
                VerityFileInspectorView(file: file) {
                    model.closeFile()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                characterHome
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .frame(width: 330, height: 420)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: model.currentFile?.id)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            FileDropHandler.handle(providers) { url in
                Task { @MainActor in
                    guard let url else {
                        model.setStatus("I couldn't open that. Try dropping a normal file.")
                        return
                    }
                    model.accept(fileURL: url)
                }
            }
        }
    }

    private var characterHome: some View {
        VStack(spacing: 10) {
            HStack {
                Text("VERITY")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    VerityPanelController.shared.hide()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 25, height: 25)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Hide Verity")
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(isDropTargeted ? 0.25 : 0.13))
                    .frame(width: 238, height: 238)
                    .blur(radius: 17)

                VerityFace(size: 202, mood: isDropTargeted ? .excited : (model.isEating ? .eating : .happy))
                    .scaleEffect(model.isEating ? 0.76 : (isDropTargeted ? 1.08 : 1.0))
                    .offset(y: isFloating && !model.isEating ? -5 : 5)
                    .rotationEffect(.degrees(model.isEating ? -13 : 0))
                    .animation(.spring(response: 0.34, dampingFraction: 0.55), value: isDropTargeted)
                    .animation(.spring(response: 0.25, dampingFraction: 0.45), value: model.isEating)
                    .shadow(color: .black.opacity(0.13), radius: 13, y: 10)
            }
            .frame(height: 236)

            Text(isDropTargeted ? "YIPPEE! FOOD!" : "Hello! I'm Verity!")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text(model.statusMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 31)

            HStack(spacing: 8) {
                Label("Feed me files", systemImage: "tray.and.arrow.down.fill")
                Text("•")
                Label("I'll read them", systemImage: "doc.text.magnifyingglass")
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(18)
        .contentShape(Rectangle())
    }
}

enum VerityMood: Equatable {
    case happy, excited, eating
}

/// A closer vector interpretation of Verity: a clean, bright yellow sphere,
/// simple oval black eyes and a broad, upward-cornered black smile.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy

    private let ink = Color(red: 0.035, green: 0.035, blue: 0.025)

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.23),
                            Color(red: 1.0, green: 0.88, blue: 0.02),
                            Color(red: 0.98, green: 0.73, blue: 0.0)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.25),
                        startRadius: size * 0.02,
                        endRadius: size * 0.82
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color(red: 0.88, green: 0.62, blue: 0.0).opacity(0.28), lineWidth: max(0.8, size * 0.008))
                }

            HStack(spacing: size * 0.25) {
                eye
                eye
            }
            .offset(y: -size * 0.155)

            mouth
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verity, a bright yellow spherical smiley face")
    }

    private var eye: some View {
        Ellipse()
            .fill(ink)
            .frame(width: size * 0.105, height: size * 0.145)
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            VeritySmileShape()
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.57, height: size * 0.28)
        case .excited:
            Ellipse()
                .fill(ink)
                .frame(width: size * 0.19, height: size * 0.23)
        case .eating:
            Ellipse()
                .fill(ink)
                .frame(width: size * 0.27, height: size * 0.12)
        }
    }
}

private struct VeritySmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = CGPoint(x: rect.minX + rect.width * 0.025, y: rect.minY + rect.height * 0.13)
        let right = CGPoint(x: rect.maxX - rect.width * 0.025, y: rect.minY + rect.height * 0.13)

        path.move(to: left)
        path.addCurve(
            to: right,
            control1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY * 1.18),
            control2: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY * 1.18)
        )

        // Small lifted tips make the smile read like the original round-face design.
        path.move(to: CGPoint(x: left.x + rect.width * 0.035, y: left.y + rect.height * 0.07))
        path.addLine(to: CGPoint(x: left.x, y: left.y))
        path.addLine(to: CGPoint(x: left.x + rect.width * 0.005, y: left.y - rect.height * 0.09))
        path.move(to: CGPoint(x: right.x - rect.width * 0.035, y: right.y + rect.height * 0.07))
        path.addLine(to: right)
        path.addLine(to: CGPoint(x: right.x - rect.width * 0.005, y: right.y - rect.height * 0.09))
        return path
    }
}
