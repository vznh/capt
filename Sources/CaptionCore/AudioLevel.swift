import AVFoundation

public enum AudioLevel {
    /// Peak absolute sample across channels for float32 buffers. Zero for empty buffers, nil for non-float formats.
    public static func peak(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let channels = buffer.floatChannelData else { return nil }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channel]
            for i in 0..<frames {
                let v = abs(samples[i])
                if v > peak { peak = v }
            }
        }
        return peak
    }
}
