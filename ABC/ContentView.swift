import SwiftUI
import AVFoundation
import Combine


class TonePlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat
    private var currentFrequency: Double?
    @Published private(set) var isPlaying = false

    init() {
        // 1. iOS 上必须先配置 AVAudioSession
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error:", error)
        }
        #endif

        // 2. attach + 用 mixer 的格式连接
        engine.attach(player)

        let mixer = engine.mainMixerNode
        let mixerFormat = mixer.outputFormat(forBus: 0)   // 一般是 2 声道 + 当前设备采样率
        self.audioFormat = mixerFormat

        engine.connect(player, to: mixer, format: mixerFormat)

        // 3. 启动 engine
        do {
            try engine.start()
            print("Engine started, running:", engine.isRunning)
        } catch {
            print("Audio engine failed to start:", error)
        }
    }

    func startTone(frequency: Double) {
        guard engine.isRunning else {
            print("Engine is not running")
            return
        }

        if currentFrequency == frequency && isPlaying { return }

        stopTone()

        let sampleRate = audioFormat.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                            frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        guard let channels = buffer.floatChannelData else { return }
        let channelCount = Int(audioFormat.channelCount)

        // 生成一个正弦波，并写入所有声道
        for frame in 0..<Int(frameCount) {
            let value = sin(2 * .pi * frequency * Double(frame) / sampleRate)
            let sample = Float(value * 0.35)

            for ch in 0..<channelCount {
                channels[ch][frame] = sample
            }
        }

        player.scheduleBuffer(buffer, at: nil, options: [.loops, .interrupts], completionHandler: nil)
        player.play()

        currentFrequency = frequency
        isPlaying = true
    }

    func stopTone() {
        player.stop()
        currentFrequency = nil
        isPlaying = false
    }
}



struct ContentView: View {
    @StateObject private var tonePlayer = TonePlayer()
    @State private var activeFrequency: Double?

    private let gFrequency = 392.0  // G4
    private let fFrequency = 349.23 // F4

    var body: some View {
        VStack(spacing: 32) {
            Text("Press and hold to play notes")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 24) {
                Button(action: {}) {
                    VStack(spacing: 8) {
                        Text("G")
                            .font(.largeTitle.bold())
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if activeFrequency != gFrequency {
                                activeFrequency = gFrequency
                                tonePlayer.startTone(frequency: gFrequency)
                            }
                        }
                        .onEnded { _ in
                            activeFrequency = nil
                            tonePlayer.stopTone()
                        }
                )

                Button(action: {}) {
                    VStack(spacing: 8) {
                        Text("F")
                            .font(.largeTitle.bold())
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if activeFrequency != fFrequency {
                                activeFrequency = fFrequency
                                tonePlayer.startTone(frequency: fFrequency)
                            }
                        }
                        .onEnded { _ in
                            activeFrequency = nil
                            tonePlayer.stopTone()
                        }
                )
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
