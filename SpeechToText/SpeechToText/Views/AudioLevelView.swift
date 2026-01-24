import SwiftUI

struct AudioLevelView: View {
    let audioLevel: Float
    private let barCount: Int = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(
                    audioLevel: audioLevel,
                    barIndex: index,
                    totalBars: barCount
                )
            }
        }
        .frame(height: 28)
    }
}

struct AudioBar: View {
    let audioLevel: Float
    let barIndex: Int
    let totalBars: Int

    @State private var displayHeight: CGFloat = 0.2

    private var targetHeight: CGFloat {
        // Each bar responds at a different threshold for a wave effect
        let threshold = Float(barIndex) / Float(totalBars)
        let excess = max(0, audioLevel - threshold * 0.3)
        // Add some variation based on bar position for organic feel
        let variation = Float(sin(Double(barIndex) * 0.8 + Double(audioLevel) * 10) * 0.15)
        return CGFloat(min(1.0, excess * 2.5 + variation + 0.2))
    }

    private var barColor: Color {
        let intensity = displayHeight
        if intensity > 0.7 {
            return .orange
        } else if intensity > 0.4 {
            return .green
        } else {
            return .green.opacity(0.7)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 4, height: 6 + displayHeight * 22)
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
        HStack {
            Text("Silent")
            Spacer()
            AudioLevelView(audioLevel: 0)
        }
        HStack {
            Text("Low")
            Spacer()
            AudioLevelView(audioLevel: 0.2)
        }
        HStack {
            Text("Medium")
            Spacer()
            AudioLevelView(audioLevel: 0.5)
        }
        HStack {
            Text("Loud")
            Spacer()
            AudioLevelView(audioLevel: 0.8)
        }
        HStack {
            Text("Max")
            Spacer()
            AudioLevelView(audioLevel: 1.0)
        }
    }
    .padding()
    .frame(width: 200)
    .background(Color.black.opacity(0.8))
}
