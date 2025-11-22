import SwiftUI
import AVFoundation

class TonePlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }

    func playTone(frequency: Double, duration: Double = 0.6) {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData?[0]

        for frame in 0..<Int(frameCount) {
            let sample = sin(2 * .pi * frequency * Double(frame) / sampleRate)
            channel?[frame] = Float(sample * 0.35)
        }

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
