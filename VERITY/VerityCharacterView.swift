import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SceneKit

/// The single, focused VERITY surface: one character, one conversation, one job.
struct VerityDesktopView: View {
    @ObservedObject private var model = VerityModel.shared
    @StateObject private var conversation = VerityConversationModel()
    @State private var isDropTargeted = false

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
                VerityConversationView(
                    model: conversation,
                    onClose: { isConversationOpen = false }
                )
            } else {
                characterHome
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .frame(width: 380, height: 560)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: model.currentFile?.id)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            FileDropHandler.handle(providers) { url in
                Task { @MainActor in
                    guard let url else {
                        model.setStatus("That file is beneath my standards. Try a normal document.")
                        return
                    }
                    model.accept(fileURL: url)
                }
            }
        }
    }

    @State private var isConversationOpen = false

    private var characterHome: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VERITY")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2.5)
                    Text("THE KNOW-IT-ALL BALL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { VerityPanelController.shared.hide() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Hide this window. I'll still be here.")
            }

            Spacer(minLength: 0)

            VerityFace(
                size: 235,
                mood: isDropTargeted ? .excited : (model.isEating ? .eating : model.mood)
            )
            .shadow(color: .orange.opacity(0.2), radius: 18, y: 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: model.mood)

            Text(homeCaption)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
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
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Ask Verity")
                    Spacer()
                    Text("I KNOW.")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 47)
                .background(Color(red: 0.13, green: 0.14, blue: 0.16), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Text("Or drop a document on me. Obviously.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(19)
        .frame(width: 380, height: 560)
    }

    private var homeCaption: String {
        if isDropTargeted { return "Excellent. Something worth my attention." }
        if model.isEating { return "I'm inspecting it. You're welcome." }
        switch model.mood {
        case .listening: return "Go on. I am paying attention."
        case .thinking: return "One moment. I have found the interesting part."
        case .speaking: return "There. Exactly as expected."
        case .shocked: return "Oh. That is unexpected."
        case .suspicious: return "I noticed a small inconsistency."
        case .angry: return "That was unnecessary. Continue."
        case .manic, .excited: return "I did enjoy being right about that."
        case .sleepy: return "I was thinking. You may continue."
        case .eating: return "A little snack. Don't mind me."
        case .eerie: return "We can pretend that was normal."
        case .happy: return "Hello. I am ready. I have been ready."
        }
    }
}

/// The docked desktop ball. It is always available and never reads files or screens on its own.
struct VerityDesktopPetView: View {
    @ObservedObject private var model = VerityModel.shared
    @ObservedObject private var controller = VerityPanelController.shared
    @State private var isBreathing = false
    @State private var isChomping = false
    @State private var isHovering = false
    @AppStorage(VerityCharacterPreferences.eerieIdleEnabledKey) private var eerieIdleEnabled = true

    var body: some View {
        ZStack {
            VerityFace(
                size: 142,
                mood: model.isEating ? .eating : model.mood
            )
            .scaleEffect((isHovering ? 1.045 : 1.0) * (model.isEating ? (isChomping ? 1.045 : 0.965) : (isBreathing ? 1.006 : 0.998)))
            .offset(y: isBreathing && !model.isEating ? -0.7 : 0.7)
            .rotationEffect(.degrees(model.mood == .eerie ? -2.5 : (model.mood == .angry ? -4 : 0)))
            .shadow(color: .black.opacity(0.30), radius: 13, y: 8)
            .animation(.spring(response: 0.15, dampingFraction: 0.50), value: isChomping)
            .animation(.easeInOut(duration: 0.55), value: model.mood)
            .animation(.spring(response: 0.20, dampingFraction: 0.62), value: isHovering)
            .contentShape(Circle())
            .onTapGesture {
                model.showReaction(.excited, duration: 750_000_000)
                controller.showCompanion()
            }
            .onHover { isHovering = $0 }
            .help("Click Verity. Obviously.")

            if isHovering {
                Text("ASK ME. I KNOW.")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .offset(y: -79)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .allowsHitTesting(false)
            }

            if model.isEating {
                Text("INSPECTION COMPLETE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.5)
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
            Button("Ask Verity") { controller.showCompanion() }
            Button("Hide desktop ball") { controller.hidePet() }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
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
                try? await Task.sleep(nanoseconds: UInt64.random(in: 240...540) * 1_000_000_000)
                guard !Task.isCancelled,
                      eerieIdleEnabled,
                      model.mood == .happy,
                      model.currentFile == nil,
                      !model.isEating else { continue }
                model.showReaction(.eerie, duration: UInt64.random(in: 2_400...3_800) * 1_000_000)
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

/// A softly lit, genuinely 3D yellow orb with an original face and expressions.
struct VerityFace: View {
    var size: CGFloat = 180
    var mood: VerityMood = .happy

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(0.28), .black.opacity(0.10), .clear],
                    center: .center,
                    startRadius: 1,
                    endRadius: size * 0.40
                ))
                .frame(width: size * 0.72, height: size * 0.17)
                .offset(y: size * 0.39)
                .blur(radius: size * 0.025)

            VerityOrbScene(mood: mood)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verity, a floating three-dimensional yellow orb with dark eyes and a shifting smile")
        .accessibilityAddTraits(.isImage)
    }
}

private struct VerityOrbScene: NSViewRepresentable {
    let mood: VerityMood

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.update(mood)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(mood)
    }

    final class Coordinator {
        let scene = SCNScene()
        let camera = SCNNode()
        private let orb = SCNNode(geometry: SCNSphere(radius: 1))
        private let eyes = [SCNNode(), SCNNode()]
        private let brows = [SCNNode(), SCNNode()]
        private let smile = SCNNode()
        private let cavity = SCNNode(geometry: SCNSphere(radius: 1))
        private let tongue = SCNNode(geometry: SCNSphere(radius: 1))
        private let teeth = (0..<9).map { _ in SCNNode(geometry: SCNSphere(radius: 1)) }
        private var lastMood: VerityMood?

        init() {
            scene.background.contents = NSColor.clear

            let ball = SCNSphere(radius: 1)
            ball.segmentCount = 96
            let skin = SCNMaterial()
            skin.lightingModel = .physicallyBased
            skin.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.035, alpha: 1)
            skin.metalness.contents = 0.03
            skin.roughness.contents = 0.27
            skin.specular.contents = NSColor(calibratedWhite: 1, alpha: 1)
            skin.shininess = 0.72
            skin.isDoubleSided = true
            ball.materials = [skin]
            orb.geometry = ball
            scene.rootNode.addChildNode(orb)

            let dark = SCNMaterial()
            dark.lightingModel = .physicallyBased
            dark.diffuse.contents = NSColor(calibratedWhite: 0.009, alpha: 1)
            dark.metalness.contents = 0.04
            dark.roughness.contents = 0.17
            dark.specular.contents = NSColor(calibratedWhite: 0.72, alpha: 1)
            dark.shininess = 0.85

            for (index, eye) in eyes.enumerated() {
                let geometry = SCNSphere(radius: 1)
                geometry.segmentCount = 32
                geometry.materials = [dark]
                eye.geometry = geometry
                eye.position = SCNVector3(index == 0 ? -0.29 : 0.29, 0.16, Self.surfaceZ(x: 0.29, y: 0.16) + 0.025)
                orb.addChildNode(eye)
            }

            let browMaterial = SCNMaterial()
            browMaterial.diffuse.contents = NSColor(calibratedWhite: 0.018, alpha: 1)
            for (index, brow) in brows.enumerated() {
                let geometry = SCNCapsule(capRadius: 0.025, height: 0.20)
                geometry.materials = [browMaterial]
                brow.geometry = geometry
                brow.position = SCNVector3(index == 0 ? -0.29 : 0.29, 0.38, Self.surfaceZ(x: 0.29, y: 0.38) + 0.025)
                brow.eulerAngles.z = index == 0 ? -0.18 : 0.18
                orb.addChildNode(brow)
                brow.isHidden = true
            }

            let ink = SCNMaterial()
            ink.diffuse.contents = NSColor(calibratedRed: 0.008, green: 0.006, blue: 0.006, alpha: 1)
            ink.roughness.contents = 0.42
            ink.isDoubleSided = true
            smile.geometry = Self.makeSmileMaterialShape(material: ink)
            orb.addChildNode(smile)

            cavity.geometry?.materials = [ink]
            cavity.position = SCNVector3(0, -0.28, Self.surfaceZ(x: 0, y: -0.28) + 0.045)
            cavity.scale = SCNVector3(0.34, 0.20, 0.075)
            orb.addChildNode(cavity)
            cavity.isHidden = true

            let red = SCNMaterial()
            red.diffuse.contents = NSColor(calibratedRed: 0.32, green: 0.018, blue: 0.018, alpha: 1)
            tongue.geometry?.materials = [red]
            tongue.position = SCNVector3(0, -0.36, Self.surfaceZ(x: 0, y: -0.36) + 0.09)
            tongue.scale = SCNVector3(0.20, 0.065, 0.018)
            orb.addChildNode(tongue)
            tongue.isHidden = true

            for (index, tooth) in teeth.enumerated() {
                let enamel = SCNMaterial()
                enamel.diffuse.contents = NSColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 1)
                enamel.roughness.contents = 0.23
                let box = SCNBox(width: index % 3 == 1 ? 0.082 : 0.066, height: index < 5 ? 0.075 : 0.060, length: 0.035, chamferRadius: 0.018)
                box.materials = [enamel]
                tooth.geometry = box
                let position = index < 5 ? index : index - 5
                let count = index < 5 ? 5 : 4
                let x = (Float(position) - Float(count - 1) / 2) * 0.125
                let upper = index < 5
                let y = upper ? -0.19 - 0.11 * (1 - abs(x) / 0.31) : -0.39 + 0.10 * (1 - abs(x) / 0.25)
                tooth.position = SCNVector3(x, y, Self.surfaceZ(x: x, y: y) + 0.092)
                orb.addChildNode(tooth)
                tooth.isHidden = true
            }

            let key = SCNNode()
            let keyLight = SCNLight()
            keyLight.type = .omni
            keyLight.intensity = 950
            keyLight.color = NSColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 1)
            key.light = keyLight
            key.position = SCNVector3(-2.4, 3.2, 4.0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            let fillLight = SCNLight()
            fillLight.type = .omni
            fillLight.intensity = 280
            fillLight.color = NSColor(calibratedRed: 0.72, green: 0.81, blue: 1, alpha: 1)
            fill.light = fillLight
            fill.position = SCNVector3(3.0, -1.2, 2.6)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            let rimLight = SCNLight()
            rimLight.type = .omni
            rimLight.intensity = 500
            rimLight.color = NSColor(calibratedRed: 1, green: 0.54, blue: 0.13, alpha: 1)
            rim.light = rimLight
            rim.position = SCNVector3(0.4, 2.4, -2.4)
            scene.rootNode.addChildNode(rim)

            let cameraGeometry = SCNCamera()
            cameraGeometry.usesOrthographicProjection = true
            cameraGeometry.orthographicScale = 2.48
            camera.camera = cameraGeometry
            camera.position = SCNVector3(0, 0, 4.2)
            scene.rootNode.addChildNode(camera)
        }

        func update(_ mood: VerityMood) {
            guard mood != lastMood else { return }
            lastMood = mood

            let isEerie = mood == .eerie || mood == .manic
            let eyeWidth: Float = isEerie ? 0.125 : (mood == .shocked ? 0.13 : 0.095)
            let eyeHeight: Float = mood == .sleepy ? 0.045 : (isEerie ? 0.19 : (mood == .shocked ? 0.17 : 0.135))
            for (index, eye) in eyes.enumerated() {
                let asymmetry: Float = isEerie ? (index == 0 ? 1.12 : 0.78) : 1
                eye.scale = SCNVector3(eyeWidth, eyeHeight * asymmetry, 0.055)
                eye.eulerAngles.z = isEerie ? (index == 0 ? -0.08 : 0.13) : 0
            }

            let showBrows = mood == .angry || mood == .suspicious || isEerie
            for (index, brow) in brows.enumerated() {
                brow.isHidden = !showBrows
                brow.eulerAngles.z = mood == .angry
                    ? (index == 0 ? 0.34 : -0.34)
                    : (index == 0 ? -0.16 : 0.12)
            }

            let open = mood == .speaking || mood == .eating || mood == .eerie || mood == .manic || mood == .shocked
            smile.isHidden = open
            cavity.isHidden = !open
            tongue.isHidden = !open || mood == .shocked
            for (index, tooth) in teeth.enumerated() {
                tooth.isHidden = !open || mood == .shocked || (mood != .eerie && mood != .manic && index > 4)
            }
            cavity.scale = isEerie
                ? SCNVector3(0.49, 0.31, 0.09)
                : (mood == .shocked ? SCNVector3(0.16, 0.22, 0.08) : SCNVector3(0.34, 0.20, 0.075))
            if mood == .shocked {
                smile.isHidden = true
                cavity.position = SCNVector3(0, -0.28, Self.surfaceZ(x: 0, y: -0.28) + 0.045)
            } else {
                cavity.position = SCNVector3(0, -0.28, Self.surfaceZ(x: 0, y: -0.28) + 0.045)
            }
        }

        private static func surfaceZ(x: Float, y: Float) -> Float {
            sqrt(max(0.06, 1 - x * x - y * y))
        }

        private static func makeSmileMaterialShape(material: SCNMaterial) -> SCNGeometry {
            let segments = 36
            let width: Float = 0.72
            let thickness: Float = 0.035
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []

            for index in 0...segments {
                let t = Float(index) / Float(segments)
                let x = (t - 0.5) * width
                let y = -0.20 - sin(t * .pi) * 0.19
                let dx: Float = 1
                let dy = -0.19 * .pi * cos(t * .pi) * 2 / width
                let length = sqrt(dx * dx + dy * dy)
                let nx = -dy / length
                let ny = dx / length

                for side: Float in [-1, 1] {
                    let px = x + nx * thickness * side / 2
                    let py = y + ny * thickness * side / 2
                    vertices.append(SCNVector3(px, py, surfaceZ(x: px, y: py) + 0.035))
                }

                if index < segments {
                    let base = Int32(index * 2)
                    indices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                }
            }

            let source = SCNGeometrySource(vertices: vertices)
            let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<Int32>.size)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.materials = [material]
            return geometry
        }
    }
}
