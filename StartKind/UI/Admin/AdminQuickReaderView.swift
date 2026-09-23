import Foundation
import SwiftUI
import UIKit

@MainActor
struct AdminQuickReaderView: View {
    enum InitialMode: String, Identifiable {
        case text, photo
        var id: String { rawValue }
    }

    private enum ReaderMode {
        case text
        case photo
    }

    private enum PhotoStage {
        case source
        case reading
        case review
        case finding
        case result
    }

    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let initialMode: InitialMode
    private let textRecognizer: AdminQuickReaderTextRecognizing

    @State private var inputText = ""
    @State private var result: AdminParseResult?
    @State private var isReadingPhoto = false
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var timerRoute: TimerRoute?
    @State private var showPaywall = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showVault = false
    @State private var pendingSaveStart: SavedStartDraft?
    @State private var savePrompt: SavedStartDraft?
    @State private var savedStartConfirmation: SavedStartDraft?
    @State private var readerMode: ReaderMode
    @State private var photoStage: PhotoStage
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @FocusState private var inputFocused: Bool

    init(
        initialMode: InitialMode = .text,
        textRecognizer: AdminQuickReaderTextRecognizing = VisionAdminQuickReaderOCRService()
    ) {
        self.initialMode = initialMode
        self.textRecognizer = textRecognizer
        _readerMode = State(initialValue: initialMode == .photo ? .photo : .text)
        _photoStage = State(initialValue: .source)
#if DEBUG
        // Screenshot mode has no network and cannot wait on the real AI
        // parse; show its canned result immediately instead.
        if ScreenshotMode.screen == .admin {
            _inputText = State(initialValue: ScreenshotDemoContent.adminPastedText)
            _result = State(initialValue: ScreenshotDemoContent.adminResult)
        }
#endif
    }

    private var canParse: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = readerMode == .text || selectedImage != nil
        return hasText && hasImage && !isParsing && !isReadingPhoto
    }

    private var urgentSignal: UrgentAdminSignal? {
        env.urgentAdminSignal(for: inputText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing16) {
                    header
                    if readerMode == .photo {
                        photoFlow
                    } else {
                        inputCard
                        if let signal = urgentSignal { urgentCard(signal) }
                        if isParsing { loadingRow }
                        if let result { resultCard(result) }
                    }
                    if let errorMessage {
                        KindBanner(text: errorMessage, tone: .warning)
                            .accessibilityIdentifier("admin.error")
                    }
                    if let savedStartConfirmation {
                        SavedStartConfirmationBanner(title: savedStartConfirmation.title) {
                            self.savedStartConfirmation = nil
                            showVault = true
                        }
                        .accessibilityIdentifier("admin.savedStart.confirmation")
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
                Task { @MainActor in await readImage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                Task { @MainActor in await readImage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $timerRoute, onDismiss: presentPendingSavePrompt) { route in
            TimerView(session: route.session, step: route.step) { outcome, blocker, returnNote in
                handleTimerOutcome(outcome, session: route.session, step: route.step, blocker: blocker, returnNote: returnNote)
            }
        }
        .sheet(isPresented: $showVault) {
            VaultPickerView(vault: env.vault) { item in
                inputText = item.body
                recognizedText = item.body
                result = nil
                readerMode = .text
                photoStage = .source
                showVault = false
            }
        }
        .alert(
            L("savedStart.prompt.title"),
            isPresented: Binding(
                get: { savePrompt != nil },
                set: { isPresented in
                    if !isPresented { savePrompt = nil }
                }
            )
        ) {
            if let draft = savePrompt {
                Button(L("savedStart.prompt.save")) {
                    saveCompletedStart(draft)
                }
                .accessibilityIdentifier("savedStart.save")
            }
            Button(L("savedStart.prompt.notNow"), role: .cancel) {
                savePrompt = nil
            }
            .accessibilityIdentifier("savedStart.notNow")
        } message: {
            if let draft = savePrompt {
                Text(verbatim: L("savedStart.prompt.message", draft.title))
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

    @ViewBuilder
    private var photoFlow: some View {
        switch photoStage {
        case .source:
            photoSourcePanel
        case .reading:
            photoReadingPanel
        case .review:
            photoReviewPanel
        case .finding:
            photoReviewPanel
        case .result:
            if let result {
                resultCard(result)
            } else {
                // Keep a recoverable destination visible even if a future
                // change ever separates the result state from its payload.
                photoReviewPanel
            }
        }
    }

    private var photoSourcePanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            SectionLabel("admin.scan.title")
            Text(verbatim: L("admin.scan.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if selectedImage != nil {
                Text(verbatim: L("admin.scan.replaceBody"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Theme.spacing8) {
                QuietButton("admin.camera", systemImage: "camera.viewfinder", accessibilityId: "admin.camera") {
                    openCamera()
                }
                QuietButton("admin.photoLibrary", systemImage: "photo.on.rectangle", accessibilityId: "admin.photoLibrary") {
                    showPhotoLibraryPicker = true
                }
            }

            QuietButton("admin.scan.paste", systemImage: "doc.on.clipboard", accessibilityId: "admin.paste") {
                beginPastedTextMode()
            }
        }
        .startKindCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.photo.source")
    }

    private var photoReadingPanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            SectionLabel("admin.scan.title")
            HStack(spacing: Theme.spacing12) {
                ProgressView()
                    .tint(Theme.accent)
                Text(verbatim: L("admin.ocr.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("admin.ocr.progress")
        }
        .startKindCard()
    }

    private var photoReviewPanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            SectionLabel("admin.review.title")
            Text(verbatim: L("admin.review.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let selectedImage {
                HStack(alignment: .top, spacing: Theme.spacing12) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                        .accessibilityLabel(Text(verbatim: L("admin.review.selectedImage")))
                        .accessibilityIdentifier("admin.image.thumbnail")

                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        Text(verbatim: L("admin.review.selectedImage"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.ink)
                        QuietButton("admin.replace", systemImage: "arrow.triangle.2.circlepath", accessibilityId: "admin.image.replace") {
                            replaceImage()
                        }
                        QuietButton("admin.remove", systemImage: "xmark", accessibilityId: "admin.image.remove") {
                            removeImage()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(photoStage == .finding)
            }

            SectionLabel("admin.review.text")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $recognizedText)
                    .focused($inputFocused)
                    .frame(height: 180)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.spacing8)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
                    .accessibilityIdentifier("admin.recognizedText")
                    .onChange(of: recognizedText) { _, newValue in
                        guard readerMode == .photo else { return }
                        inputText = newValue
                    }

                if recognizedText.isEmpty {
                    Text(verbatim: L("admin.review.empty"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.spacing12)
                        .padding(.vertical, Theme.spacing16)
                        .allowsHitTesting(false)
                }
            }
            .disabled(photoStage == .finding)

            if isParsing {
                HStack(spacing: Theme.spacing12) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text(verbatim: L("admin.parse.loading"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("admin.parse.progress")
            }

            PrimaryButton(
                "admin.parse",
                systemImage: "wand.and.stars",
                enabled: canParse,
                busy: isParsing,
                accessibilityId: "admin.parse"
            ) {
                Task { await parse() }
            }
        }
        .startKindCard()
        .accessibilityIdentifier("admin.photo.review")
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .focused($inputFocused)
                    .frame(height: 180)
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
                    beginPhotoFlow()
                }
            }

            PrimaryButton("admin.parse", systemImage: "wand.and.stars", enabled: canParse, busy: isParsing, accessibilityId: "admin.parse") {
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("admin.parse.progress")
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
                let session = env.startTimer(step: step, minutes: signal.proposal.timerMinutes)
                timerRoute = TimerRoute(session: session, step: step)
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
    }

    private func pasteText() {
        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
            inputText = pasted
            recognizedText = pasted
            result = nil
            errorMessage = nil
        }
    }

    private func beginPastedTextMode() {
        inputFocused = false
        readerMode = .text
        photoStage = .source
        result = nil
        errorMessage = nil
        pasteText()
    }

    private func beginPhotoFlow() {
        inputFocused = false
        readerMode = .photo
        photoStage = .source
        selectedImage = nil
        recognizedText = ""
        inputText = ""
        result = nil
        errorMessage = nil
    }

    private func replaceImage() {
        guard !isReadingPhoto && !isParsing else { return }
        inputFocused = false
        result = nil
        errorMessage = nil
        photoStage = .source
    }

    private func removeImage() {
        guard !isReadingPhoto && !isParsing else { return }
        inputFocused = false
        selectedImage = nil
        recognizedText = ""
        inputText = ""
        result = nil
        errorMessage = nil
        photoStage = .source
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
        selectedImage = image
        result = nil
        isReadingPhoto = true
        photoStage = .reading
        errorMessage = nil
        inputFocused = false
        do {
            guard let cgImage = image.cgImage else { throw AdminReaderError.emptyPhoto }
            let text = try await textRecognizer.recognizeText(from: cgImage, language: env.currentLanguage)
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                errorMessage = L("admin.ocr.empty")
            } else {
                recognizedText = trimmedText
                inputText = trimmedText
            }
        } catch {
            errorMessage = L("admin.ocr.error")
        }
        isReadingPhoto = false
        photoStage = .review
    }

    private func parse() async {
        guard !isParsing else { return }
        inputFocused = false
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isParsing = true
        result = nil
        errorMessage = nil
        if readerMode == .photo {
            photoStage = .finding
        }
        do {
            let parsedResult = try await env.parseAdmin(text: text)
            recognizedText = text
            result = parsedResult
            if readerMode == .photo {
                photoStage = .result
            }
        } catch let usageError as UsageError {
            if PaywallTrigger.fromReturnedLimitError(usageError) == .adminLimit {
                showPaywall = true
            } else {
                errorMessage = usageError.localizedDescription
            }
        } catch {
            errorMessage = L("common.error")
        }
        isParsing = false
        if readerMode == .photo && result == nil {
            photoStage = .review
        }
    }

    private func startTimer(for proposal: NextStepProposal) {
        let capture = env.persistence.saveCapture(rawText: inputText, source: .manual, language: env.currentLanguage)
        let step = env.persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        let session = env.startTimer(step: step, minutes: min(proposal.timerMinutes, 25))
        timerRoute = TimerRoute(session: session, step: step)
    }

    private func handleTimerOutcome(_ outcome: TimerOutcome, session: TimerSessionModel, step: NextStepModel, blocker: BlockerReason? = nil, returnNote: String? = nil) {
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        let completedProposal = step.proposal
        if outcome == .partial || outcome == .paused {
            _ = env.rescheduleStep(step, reason: .paused)
        } else if outcome == .abandoned {
            _ = env.rescheduleStep(step, reason: .skipped)
        }
        env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
        timerRoute = nil
        if outcome == .completed {
            pendingSaveStart = SavedStartCompletionPolicy.draft(
                outcome: outcome,
                isRootFinished: true,
                proposal: completedProposal,
                vault: env.vault
            )
        }
    }

    private func presentPendingSavePrompt() {
        guard let pendingSaveStart else { return }
        self.pendingSaveStart = nil
        savePrompt = pendingSaveStart
    }

    private func saveCompletedStart(_ draft: SavedStartDraft) {
        env.vault.add(title: draft.title, body: draft.body, category: draft.category)
        savePrompt = nil
        savedStartConfirmation = draft
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
