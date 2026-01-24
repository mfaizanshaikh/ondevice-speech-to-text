import SwiftUI

struct AudioLevelView: View {
    let audioLevel: Float
    private let barCount: Int = 40

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    AudioBar(
                        audioLevel: audioLevel,
                        barIndex: index,
                        totalBars: barCount
                    )
                    .frame(width: (geometry.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
                }
            }
        }
        .frame(height: 32)
    }
}

struct AudioBar: View {
    let audioLevel: Float
    let barIndex: Int
    let totalBars: Int

    @State private var displayHeight: CGFloat = 0.15

    private var targetHeight: CGFloat {
        // Create a wave pattern that responds to audio level
        let centerDistance = abs(Float(barIndex) - Float(totalBars) / 2) / Float(totalBars) * 2
        let wavePhase = sin(Double(barIndex) * 0.5 + Double(audioLevel) * 15) * 0.3
        let baseLevel = max(0, audioLevel - centerDistance * 0.3)
        return CGFloat(min(1.0, baseLevel * 1.8 + Float(wavePhase) * audioLevel + 0.15))
    }

    private var barColor: Color {
        let intensity = displayHeight
        if intensity > 0.75 {
            return .orange
        } else if intensity > 0.5 {
            return .green
        } else {
            return .green.opacity(0.6)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(barColor)
            .frame(height: 4 + displayHeight * 28)
            .animation(.easeOut(duration: 0.08), value: displayHeight)
            .onChange(of: audioLevel) { _, _ in
                displayHeight = targetHeight
            }
            .onAppear {
                displayHeight = targetHeight
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Silent")
        AudioLevelView(audioLevel: 0)

        Text("Low")
        AudioLevelView(audioLevel: 0.2)

        Text("Medium")
        AudioLevelView(audioLevel: 0.5)

        Text("Loud")
        AudioLevelView(audioLevel: 0.8)

        Text("Max")
        AudioLevelView(audioLevel: 1.0)
    }
    .padding()
    .frame(width: 380)
    .background(Color.black.opacity(0.8))
}
