import SwiftUI

/// Secondary caption controls kept out of the compact menu-bar panel.
struct AdditionalSettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adjustments")
                    .font(.headline)
                OpacityControl(title: "Fill", value: fillOpacity)
                OpacityControl(title: "Text", value: textOpacity, range: 0.2 ... 1)
                HStack {
                    Text("Invert fill")
                    Spacer()
                    Toggle("Invert fill", isOn: invertsBackground)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Accessibility")
                    .font(.headline)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bionic")
                        Text("Bolds word beginnings with subtle spacing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Toggle("Bionic", isOn: bionicReading)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { model.beginPreview() }
        .onDisappear { model.endPreview() }
    }

    private var fillOpacity: Binding<Double> {
        Binding(
            get: { model.settings.fillOpacity },
            set: { model.settings.fillOpacity = $0 }
        )
    }

    private var textOpacity: Binding<Double> {
        Binding(
            get: { model.settings.textOpacity },
            set: { model.settings.textOpacity = $0 }
        )
    }

    private var invertsBackground: Binding<Bool> {
        Binding(
            get: { model.settings.invertsCaptionBackground },
            set: { model.settings.invertsCaptionBackground = $0 }
        )
    }

    private var bionicReading: Binding<Bool> {
        Binding(
            get: { model.settings.bionicReadingEnabled },
            set: { model.settings.bionicReadingEnabled = $0 }
        )
    }
}

private struct OpacityControl: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0 ... 1

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 32, alignment: .leading)
            Slider(value: $value, in: range, step: 0.05)
            Text(value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }
}
