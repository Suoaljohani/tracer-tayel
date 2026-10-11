import SwiftUI
import Speech
import AVFoundation
import Observation

/// Live dictation for staff answers (Arabic or English, following the app language).
@Observable
@MainActor
final class Dictation {
    var isRecording = false
    var level: Float = 0
    var errorText: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var baseText = ""
    private var onText: ((String) -> Void)?

    func toggle(current: String, onText: @escaping (String) -> Void) {
        if isRecording { stop() } else { Task { await start(current: current, onText: onText) } }
    }

    func start(current: String, onText: @escaping (String) -> Void) async {
        errorText = nil
        let speechOK = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else {
            errorText = L("Allow microphone and speech recognition in Settings to dictate.", "اسمح بالميكروفون والتعرف على الكلام من الإعدادات لاستخدام الإملاء.")
            return
        }
        let localeID = AppSettings.shared.language == .arabic ? "ar-SA" : "en-US"
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else {
            errorText = L("Dictation is unavailable right now.", "الإملاء غير متاح حاليًا.")
            return
        }
        self.onText = onText
        baseText = current.isEmpty ? "" : current + " "

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            request = req

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                req.append(buffer)
                let level = Dictation.rms(buffer)
                Task { @MainActor in self?.level = level }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            Haptics.tap()

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.onText?(self.baseText + result.bestTranscription.formattedString)
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self.stop()
                    }
                }
            }
        } catch {
            errorText = error.localizedDescription
            stop()
        }
    }

    func stop() {
        guard isRecording || task != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        return min(1, sqrt(sum / Float(n)) * 8)
    }
}

struct DictationButton: View {
    @Binding var text: String
    var tint: Color = Palette.gold
    @State private var dictation = Dictation()

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                dictation.toggle(current: text) { newText in text = newText }
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        if dictation.isRecording {
                            Circle().fill(tint.opacity(0.25))
                                .frame(width: 30, height: 30)
                                .scaleEffect(1 + CGFloat(dictation.level) * 0.6)
                                .animation(.easeOut(duration: 0.12), value: dictation.level)
                        }
                        Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(dictation.isRecording ? .white : tint)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(dictation.isRecording ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.1))))
                    }
                    Text(dictation.isRecording ? L("Listening…", "جارٍ الاستماع…") : L("Dictate", "إملاء"))
                        .font(.trCaptionBold)
                        .foregroundStyle(tint)
                }
            }
            .buttonStyle(.plain)
            if let e = dictation.errorText {
                Text(e).font(.trMicro).foregroundStyle(RiskLevel.high.color).multilineTextAlignment(.trailing)
            }
        }
        .onDisappear { dictation.stop() }
    }
}
