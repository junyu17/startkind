import SwiftUI
import UIKit
@preconcurrency import Vision

struct AdminQuickReaderView: View {
    enum InitialMode: String, Identifiable {
        case text, photo
        var id: String { rawValue }
    }

    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let initialMode: InitialMode

    @State private var inputText = ""
    @State private var result: AdminParseResult?
    @State private var isReadingPhoto = false
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var timerSession: TimerSessionModel?
    @State private var activeStep: NextStepModel?
    @State private var showPaywall = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @FocusState private var inputFocused: Bool

    init(initialMode: InitialMode = .text) {
        self.initialMode = initialMode
    }

    private var canParse: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isParsing && !isReadingPhoto
    }

    private var urgentSignal: UrgentAdminSignal? {
        env.urgentAdminSignal(for: inputText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing16) {
                    header
                    if initialMode == .photo { scanCard }
                    inputCard
                    if let signal = urgentSignal { urgentCard(signal) }
                    if isParsing || isReadingPhoto { loadingRow }
                    if let result { resultCard(result) }
                    if let errorMessage {
                        Text(verbatim: errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(Theme.spacing16)
            }
            .navigationTitle(L("admin.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("common.done")) { inputFocused = false }
                        .accessibilityIdentifier("admin.keyboard.done")
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: .adminLimit).environmentObject(env)
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                Task { await readImage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                Task { await readImage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $timerSession) { session in
            if let activeStep {
                TimerView(session: session, step: activeStep) { outcome, blocker, returnNote in
                    handleTimerOutcome(outcome, session: session, step: activeStep, blocker: blocker, returnNote: returnNote)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("admin.kicker")
            Text(verbatim: L("admin.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !env.isPlus {
                Text(verbatim: L("admin.freeAllowance", env.usageState.adminQuickStartsRemaining, env.usageState.adminQuickStartLimit))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
        .startKindCard()
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            SectionLabel("admin.scan.title")
            Text(verbatim: L("admin.scan.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.spacing8) {
                QuietButton("admin.camera", systemImage: "camera.viewfinder", accessibilityId: "admin.camera") {
                    openCamera()
                }
                QuietButton("admin.photoLibrary", systemImage: "photo.on.rectangle", accessibilityId: "admin.photoLibrary") {
                    showPhotoLibraryPicker = true
                }
            }
        }
        .startKindCard()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .focused($inputFocused)
                    .frame(minHeight: 150)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.spacing8)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
                    .accessibilityIdentifier("admin.input")

                if inputText.isEmpty {
                    Text(verbatim: L("admin.input.placeholder"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.spacing12)
                        .padding(.vertical, Theme.spacing16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: Theme.spacing8) {
                QuietButton("admin.paste", systemImage: "doc.on.clipboard", accessibilityId: "admin.paste") {
                    pasteText()
                }

                QuietButton("admin.photo", systemImage: "photo.on.rectangle", accessibilityId: "admin.photo") {
                    showPhotoLibraryPicker = true
                }
            }

            PrimaryButton("admin.parse", systemImage: "wand.and.stars", enabled: canParse, accessibilityId: "admin.parse") {
                Task { await parse() }
            }
        }
        .startKindCard()
    }

    private var loadingRow: some View {
        HStack(spacing: Theme.spacing12) {
            ProgressView().tint(Theme.accent)
            Text(verbatim: L(isReadingPhoto ? "admin.ocr.loading" : "admin.parse.loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.softAccent.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
    }

    private func urgentCard(_ signal: UrgentAdminSignal) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing10) {
            Label(signal.title, systemImage: "exclamationmark.clock")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(verbatim: signal.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: signal.proposal.step)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("urgentAdmin.start", systemImage: "play.fill", accessibilityId: "urgentAdmin.start") {
                guard let step = env.createUrgentAdminStep(from: inputText) else { return }
                activeStep = step
                timerSession = env.startTimer(step: step, minutes: signal.proposal.timerMinutes)
            }
        }
        .startKindCard()
    }

    private func resultCard(_ result: AdminParseResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("admin.result.title"))
                    .font(.headline)
                Spacer()
                Text(verbatim: confidenceText(result.confidence))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("admin.result")

            VStack(alignment: .leading, spacing: Theme.spacing8) {
                factRow("admin.fact.type", artifactName(result.artifactType), "tray.full")
                if let dueDate = result.dueDate { factRow("admin.fact.due", dateText(dueDate), "calendar") }
                if let amount = result.amount { factRow("admin.fact.amount", amount, "dollarsign.circle") }
                if let contact = result.contact { factRow("admin.fact.contact", contact, "person.crop.circle") }
                if let link = result.linkOrPhone { factRow("admin.fact.link", link, "link") }
            }

            if !result.requiredDocuments.isEmpty {
                tagSection(title: L("admin.documents"), values: result.requiredDocuments)
            }
            if !result.missingInfo.isEmpty {
                tagSection(title: L("admin.missing"), values: result.missingInfo)
            }

            nextStepPreview(result.oneNextStep)
        }
        .startKindCard()
    }

    private func factRow(_ key: String, _ value: String, _ image: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing8) {
            Image(systemName: image)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: L(key))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tagSection(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel(verbatim: title)
            FlexibleHStack(spacing: Theme.spacing8) {
                ForEach(values, id: \.self) { value in
                    Text(verbatim: value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, Theme.spacing10)
                        .padding(.vertical, Theme.spacing8)
                        .background(Theme.warmWash.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
            }
        }
    }

    private func nextStepPreview(_ proposal: NextStepProposal) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing10) {
            SectionLabel("admin.nextStep")
            Text(verbatim: proposal.title)
                .font(.title3)
                .fontWeight(.bold)
            Text(verbatim: proposal.step)
                .font(.body)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: Theme.spacing8) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(verbatim: proposal.stopCondition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            PrimaryButton(
                verbatim: L("nextstep.timer.label") + " " + L("nextstep.timer.minutes", proposal.timerMinutes),
                systemImage: "play.fill",
                accessibilityId: "admin.startTimer"
            ) {
                startTimer(for: proposal)
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private func pasteText() {
        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
            inputText = pasted
            errorMessage = nil
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = L("admin.cameraUnavailable")
            return
        }
        showCameraPicker = true
    }

    private func readImage(_ image: UIImage?) async {
        guard let image else { return }
        isReadingPhoto = true
        errorMessage = nil
        do {
            let text = try await Self.recognizeText(from: image, language: env.currentLanguage)
            inputText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if inputText.isEmpty { errorMessage = L("admin.ocr.empty") }
        } catch {
            errorMessage = L("admin.ocr.error")
        }
        isReadingPhoto = false
    }

    private func parse() async {
        inputFocused = false
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isParsing = true
        errorMessage = nil
        do {
            result = try await env.parseAdmin(text: text)
        } catch let usageError as UsageError {
            if case .adminLimitReached = usageError {
                showPaywall = true
            } else {
                errorMessage = usageError.localizedDescription
            }
        } catch {
            errorMessage = L("common.error")
        }
        isParsing = false
    }

    private func startTimer(for proposal: NextStepProposal) {
        let capture = env.persistence.saveCapture(rawText: inputText, source: .manual, language: env.currentLanguage)
        let step = env.persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        activeStep = step
        timerSession = env.startTimer(step: step, minutes: min(proposal.timerMinutes, 25))
    }

    private func handleTimerOutcome(_ outcome: TimerOutcome, session: TimerSessionModel, step: NextStepModel, blocker: BlockerReason? = nil, returnNote: String? = nil) {
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        if outcome == .partial || outcome == .paused {
            _ = env.rescheduleStep(step, reason: .paused)
        } else if outcome == .abandoned {
            _ = env.rescheduleStep(step, reason: .skipped)
        }
        env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
        timerSession = nil
        if outcome == .completed {
            activeStep = nil
            result = nil
        }
    }

    private func confidenceText(_ confidence: Double) -> String {
        L("admin.confidence", Int((confidence * 100).rounded()))
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func artifactName(_ type: AdminArtifactType) -> String {
        L("admin.artifact.\(type.rawValue)")
    }

    private static func recognizeText(from image: UIImage, language: String) async throws -> String {
        guard let cgImage = image.cgImage else { throw AdminReaderError.emptyPhoto }
        return try await recognizeText(from: cgImage, language: language)
    }

    private static func recognizeText(from image: CGImage, language: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = language.lowercased().hasPrefix("zh")
                ? ["zh-Hans", "en-US"]
                : ["en-US"]
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private enum AdminReaderError: Error {
    case emptyPhoto
}

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage?) -> Void
        private let dismiss: DismissAction

        init(onImage: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
            dismiss()
        }
    }
}
