import SwiftUI

/// Live audio feature meters for debug tuning.
struct AudioFeatureMeterView: View {
    let snapshot: AudioFeatureSnapshot
    let engineState: AudioEngineState
    var accent: Color = Color(red: 0.2, green: 0.85, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Input")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(engineState.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(engineState == .running ? accent : .orange)
            }

            meterRow(label: "Bass", value: snapshot.bass)
            meterRow(label: "Mids", value: snapshot.mids)
            meterRow(label: "Highs", value: snapshot.highs)
            meterRow(label: "Energy", value: snapshot.energy)

            HStack {
                Text("Beat")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 52, alignment: .leading)

                Circle()
                    .fill(snapshot.isBeat ? accent : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
                    .shadow(color: snapshot.isBeat ? accent.opacity(0.8) : .clear, radius: 6)

                Spacer()

                Text(String(format: "%.2f", snapshot.beatStrength))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent.opacity(0.9))
            }
        }
        .frame(maxWidth: 280)
    }

    private func meterRow(label: String, value: Float) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 52, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.2f", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, alignment: .trailing)
        }
        .frame(height: 14)
    }
}

#Preview {
    ZStack {
        Color.black
        AudioFeatureMeterView(
            snapshot: AudioFeatureSnapshot(
                bass: 0.72,
                mids: 0.41,
                highs: 0.28,
                energy: 0.55,
                isBeat: true,
                beatStrength: 0.9,
                timestamp: Date().timeIntervalSince1970
            ),
            engineState: .running
        )
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
