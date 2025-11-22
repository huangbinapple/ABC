import SwiftUI
import AVFoundation
import Combine


class TonePlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat

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

    func playTone(frequency: Double, duration: Double = 0.6) {
        guard engine.isRunning else {
            print("Engine is not running")
            return
        }

        let sampleRate = audioFormat.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)

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

        // 安排播放
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)

        if !player.isPlaying {
            player.play()
        }
    }
}



struct ContentView: View {
    @StateObject private var tonePlayer = TonePlayer()

    private let gFrequency = 392.0  // G4
    private let fFrequency = 349.23 // F4

    var body: some View {
        VStack(spacing: 32) {
            Text("Tap to play notes")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 24) {
                Button {
                    tonePlayer.playTone(frequency: gFrequency)
                } label: {
                    VStack(spacing: 8) {
                        Text("G")
                            .font(.largeTitle.bold())
                        Text("+")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    tonePlayer.playTone(frequency: fFrequency)
                } label: {
                    VStack(spacing: 8) {
                        Text("F")
                            .font(.largeTitle.bold())
                        Text("-")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
