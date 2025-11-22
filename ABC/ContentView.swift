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

        let mixer = engine.mainMixerNode
        let mixerFormat = mixer.outputFormat(forBus: 0)   // 一般是 2 声道 + 当前设备采样率
        let sampleRate = mixerFormat.sampleRate

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = (2 * Double.pi * self.frequency) / sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase) * self.amplitude)
                self.phase += phaseIncrement

                if self.phase > 2 * Double.pi {
                    self.phase -= 2 * Double.pi
                }

                for buffer in ablPointer {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = sample
                }
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: mixerFormat)

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

        stopTone()

        let sampleRate = audioFormat.sampleRate
        let duration = 0.2
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

        // 循环播放，直到主动停止
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        player.play()
    }

    func stopTone() {
        guard player.isPlaying else { return }
        player.stop()
        player.reset()
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
                ToneButton(title: "G") {
                    tonePlayer.startTone(frequency: gFrequency)
                } onRelease: {
                    tonePlayer.stopTone()
                }

                ToneButton(title: "F") {
                    tonePlayer.startTone(frequency: fFrequency)
                } onRelease: {
                    tonePlayer.stopTone()
                }
            }
        }
        .padding()
    }
}

struct ToneButton: View {
    let title: String
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(.ultraThickMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 80, pressing: { pressing in
            if pressing {
                onPress()
            } else {
                onRelease()
            }
        }, perform: { })
    }
}

#Preview {
    ContentView()
}
