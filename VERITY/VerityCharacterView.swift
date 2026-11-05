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
                mood: isDropTargeted ? .excited : (model.isEating ? .eating : model.mood),
                speechLevel: model.speechLevel
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
                mood: model.isEating ? .eating : model.mood,
                speechLevel: model.speechLevel
            )
            .scaleEffect((isHovering ? 1.045 : 1.0) * (model.isEating ? (isChomping ? 1.014 : 0.99) : (isBreathing ? 1.006 : 0.994)))
            .rotationEffect(.degrees(model.mood == .eerie ? -2.5 : (model.mood == .angry ? -4 : 0)))
            .shadow(color: .black.opacity(0.30), radius: 13, y: 8)
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
        .task(id: model.isEating) {
            guard model.isEating else {
                isChomping = false
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.20)) {
                    isChomping.toggle()
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
        }
        .task {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isBreathing = true
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
    var speechLevel: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.orange.opacity(0.24), Color.yellow.opacity(0.10), .clear],
                    center: .center,
                    startRadius: size * 0.18,
                    endRadius: size * 0.51
                ))
                .frame(width: size * 1.02, height: size * 1.02)
                .blur(radius: size * 0.075)
                .offset(y: size * 0.025)

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

            VerityOrbScene(mood: mood, speechLevel: speechLevel)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verity, a floating three-dimensional yellow orb with dark eyes and a shifting smile")
        .accessibilityAddTraits(.isImage)
    }
}

private final class VerityTrackingSceneView: SCNView {
    var onPointerMove: ((CGPoint) -> Void)?
    var onPointerExit: (() -> Void)?
    private var pointerTrackingArea: NSTrackingArea?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        if let pointerTrackingArea { removeTrackingArea(pointerTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0, bounds.height > 0 else { return }
        onPointerMove?(CGPoint(x: point.x / bounds.width, y: point.y / bounds.height))
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onPointerExit?()
        super.mouseExited(with: event)
    }
}

private struct VerityOrbScene: NSViewRepresentable {
    let mood: VerityMood
    let speechLevel: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = VerityTrackingSceneView(frame: .zero)
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.onPointerMove = { [weak coordinator = context.coordinator] point in
            coordinator?.updateGaze(point)
        }
        view.onPointerExit = { [weak coordinator = context.coordinator] in
            coordinator?.updateGaze(CGPoint(x: 0.5, y: 0.5))
        }
        context.coordinator.update(mood, speechLevel: speechLevel)
        context.coordinator.startBlinking()
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(mood, speechLevel: speechLevel)
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stopBlinking()
    }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        let camera = SCNNode()
        private let orb = SCNNode(geometry: SCNSphere(radius: 1))
        private let eyes = [SCNNode(), SCNNode()]
        private let eyeHighlights = (0..<2).map { _ in (0..<2).map { _ in SCNNode() } }
        private let brows = [SCNNode(), SCNNode()]
        private let smile = SCNNode()
        private let cavity = SCNNode(geometry: SCNSphere(radius: 1))
        private let tongue = SCNNode(geometry: SCNSphere(radius: 1))
        private let teeth = (0..<9).map { _ in SCNNode(geometry: SCNSphere(radius: 1)) }
        private var lastMood: VerityMood?
        private var lastSpeechLevel: Float = 0
        private var gazePoint = CGPoint(x: 0.5, y: 0.5)
        private var eyeHeightTargets = [Float](repeating: 0.135, count: 2)
        private var blinkTask: Task<Void, Never>?

        init() {
            scene.background.contents = NSColor.clear
            scene.lightingEnvironment.contents = NSColor(calibratedRed: 0.86, green: 0.81, blue: 0.68, alpha: 1)
            scene.lightingEnvironment.intensity = 1.15

            let ball = SCNSphere(radius: 1)
            ball.segmentCount = 96
            let skin = SCNMaterial()
            skin.lightingModel = .physicallyBased
            skin.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.04, alpha: 1)
            skin.metalness.contents = 0.0
            skin.roughness.contents = 0.52
            skin.specular.contents = NSColor(calibratedWhite: 0.60, alpha: 1)
            skin.isDoubleSided = true
            ball.materials = [skin]
            orb.geometry = ball
            scene.rootNode.addChildNode(orb)

            let idleFloat = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.022, z: 0, duration: 2.2),
                SCNAction.moveBy(x: 0, y: -0.022, z: 0, duration: 2.2)
            ])
            idleFloat.timingMode = .easeInEaseOut
            orb.runAction(.repeatForever(idleFloat), forKey: "idle-float")

            let idleSway = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: -0.025, z: 0, duration: 2.7, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: 0, y: 0.025, z: 0, duration: 5.4, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 2.7, usesShortestUnitArc: true)
            ])
            idleSway.timingMode = .easeInEaseOut
            orb.runAction(.repeatForever(idleSway), forKey: "idle-sway")

            let ambient = SCNNode()
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 560
            ambientLight.color = NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.55, alpha: 1)
            ambient.light = ambientLight
            scene.rootNode.addChildNode(ambient)

            let dark = SCNMaterial()
            dark.lightingModel = .physicallyBased
            dark.diffuse.contents = NSColor(calibratedWhite: 0.009, alpha: 1)
            dark.metalness.contents = 0.04
            dark.roughness.contents = 0.17
            dark.specular.contents = NSColor(calibratedWhite: 0.72, alpha: 1)
            dark.shininess = 0.85

            let glintMaterial = SCNMaterial()
            glintMaterial.lightingModel = .constant
            glintMaterial.diffuse.contents = NSColor(calibratedWhite: 1, alpha: 1)
            for (index, eye) in eyes.enumerated() {
                let geometry = SCNSphere(radius: 1)
                geometry.segmentCount = 32
                geometry.materials = [dark]
                eye.geometry = geometry
                eye.position = SCNVector3(index == 0 ? -0.29 : 0.29, 0.16, Self.surfaceZ(x: 0.29, y: 0.16) + 0.025)
                orb.addChildNode(eye)

                for (glintIndex, glint) in eyeHighlights[index].enumerated() {
                    let glintGeometry = SCNSphere(radius: glintIndex == 0 ? 0.16 : 0.09)
                    glintGeometry.segmentCount = 16
                    glintGeometry.materials = [glintMaterial]
                    glint.geometry = glintGeometry
                    glint.position = glintIndex == 0
                        ? SCNVector3(-0.28, 0.40, 1.06)
                        : SCNVector3(0.40, -0.35, 1.06)
                    eye.addChildNode(glint)
                }
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
            keyLight.intensity = 700
            keyLight.color = NSColor(calibratedRed: 1, green: 0.95, blue: 0.82, alpha: 1)
            key.light = keyLight
            key.position = SCNVector3(-1.4, 2.8, 4.0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            let fillLight = SCNLight()
            fillLight.type = .omni
            fillLight.intensity = 650
            fillLight.color = NSColor(calibratedRed: 0.76, green: 0.84, blue: 1, alpha: 1)
            fill.light = fillLight
            fill.position = SCNVector3(2.0, -1.8, 4.0)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            let rimLight = SCNLight()
            rimLight.type = .omni
            rimLight.intensity = 250
            rimLight.color = NSColor(calibratedRed: 1, green: 0.54, blue: 0.13, alpha: 1)
            rim.light = rimLight
            rim.position = SCNVector3(0.4, 2.4, -2.4)
            scene.rootNode.addChildNode(rim)

            let cameraGeometry = SCNCamera()
            cameraGeometry.usesOrthographicProjection = true
            cameraGeometry.orthographicScale = 2.48
            cameraGeometry.wantsHDR = true
            camera.camera = cameraGeometry
            camera.position = SCNVector3(0, 0, 4.2)
            scene.rootNode.addChildNode(camera)
        }

        func update(_ mood: VerityMood, speechLevel: CGFloat) {
            let moodChanged = mood != lastMood
            let level = Float(min(max(speechLevel, 0), 1))
            let levelChanged = abs(level - lastSpeechLevel) > 0.025
            guard moodChanged || levelChanged else { return }

            lastMood = mood
            lastSpeechLevel = level
            SCNTransaction.begin()
            SCNTransaction.animationDuration = moodChanged ? 0.22 : 0.055

            if moodChanged {
                let isEerie = mood == .eerie || mood == .manic
                let eyeWidth: Float = isEerie ? 0.125 : (mood == .shocked ? 0.13 : 0.095)
                let eyeHeight: Float = mood == .sleepy ? 0.045 : (isEerie ? 0.19 : (mood == .shocked ? 0.17 : 0.135))
                for (index, eye) in eyes.enumerated() {
                    eye.removeAction(forKey: "blink")
                    let asymmetry: Float = isEerie ? (index == 0 ? 1.12 : 0.78) : 1
                    let targetHeight = eyeHeight * asymmetry
                    eyeHeightTargets[index] = targetHeight
                    eye.scale = SCNVector3(eyeWidth, targetHeight, 0.055)
                    eye.eulerAngles.z = isEerie ? (index == 0 ? -0.08 : 0.13) : 0
                    eye.position = eyePosition(index)
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
                cavity.position = SCNVector3(0, -0.28, Self.surfaceZ(x: 0, y: -0.28) + 0.045)
            }

            let isEerie = mood == .eerie || mood == .manic
            let mouthWidth: Float = isEerie ? 0.49 : (mood == .shocked ? 0.16 : 0.34)
            let mouthHeight: Float = isEerie ? 0.31 : (mood == .shocked ? 0.22 : 0.20)
            let mouthDepth: Float = isEerie ? 0.09 : (mood == .shocked ? 0.08 : 0.075)
            let talkingOpenAmount: Float = mood == .speaking ? 0.10 + level * 0.23 : 0
            cavity.scale = SCNVector3(mouthWidth, mouthHeight + talkingOpenAmount, mouthDepth)
            tongue.scale = SCNVector3(0.20, 0.065 + (mood == .speaking ? level * 0.035 : 0), 0.018)

            SCNTransaction.commit()
        }

        func updateGaze(_ point: CGPoint) {
            gazePoint = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.10
            for index in eyes.indices { eyes[index].position = eyePosition(index) }
            SCNTransaction.commit()
        }

        func startBlinking() {
            guard blinkTask == nil else { return }
            blinkTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    let delay = UInt64.random(in: 3_000...6_500) * 1_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    guard let self, !Task.isCancelled else { return }
                    self.performBlink()
                }
            }
        }

        func stopBlinking() {
            blinkTask?.cancel()
            blinkTask = nil
            for eye in eyes { eye.removeAction(forKey: "blink") }
        }

        private func performBlink() {
            guard let mood = lastMood,
                  mood != .speaking, mood != .eating, mood != .shocked,
                  mood != .eerie, mood != .manic else { return }

            for (index, eye) in eyes.enumerated() {
                let targetHeight = CGFloat(eyeHeightTargets[index])
                let close = SCNAction.customAction(duration: 0.085) { node, elapsedTime in
                    let progress = min(max(elapsedTime / 0.085, 0), 1)
                    let eased = progress * progress * (3 - 2 * progress)
                    node.scale.y = targetHeight + (0.006 - targetHeight) * eased
                }
                let reopen = SCNAction.customAction(duration: 0.14) { node, elapsedTime in
                    let progress = min(max(elapsedTime / 0.14, 0), 1)
                    let eased = progress * progress * (3 - 2 * progress)
                    node.scale.y = 0.006 + (targetHeight - 0.006) * eased
                }
                eye.runAction(.sequence([close, reopen]), forKey: "blink")
            }
        }

        private func eyePosition(_ index: Int) -> SCNVector3 {
            let horizontal = Float((gazePoint.x - 0.5) * 2) * 0.045
            let vertical = Float((gazePoint.y - 0.5) * 2) * 0.035
            let x = (index == 0 ? -0.29 : 0.29) + horizontal
            let y = 0.16 + vertical
            return SCNVector3(x, y, Self.surfaceZ(x: x, y: y) + 0.025)
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
