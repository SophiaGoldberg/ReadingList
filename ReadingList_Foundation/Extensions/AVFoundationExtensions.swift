import AVFoundation

public extension AVCaptureDevice {
    /// Returns whether the torch is now on or off, or nil if the torch isn't controllable or doesn't exist
    static func toggleTorch() -> Bool? {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil }
        guard device.hasTorch else { return nil }

        do {
            try device.lockForConfiguration()
            defer {
                device.unlockForConfiguration()
            }
            if device.torchMode == .on {
                device.torchMode = .off
                return false
            } else {
                try device.setTorchModeOn(level: 1.0)
                return true
            }
        } catch {
            return nil
       }
    }
}
