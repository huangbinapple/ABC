import SwiftUI
import AVFoundation
import Combine


class TonePlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private var phase: Double = 0
    private var frequency: Double = 0
    private var amplitude: Double = 0
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

        self.frequency = frequency
        self.amplitude = 0.35
        isPlaying = true
    }

    func stopTone() {
        amplitude = 0
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
