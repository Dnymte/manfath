import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Generates QR code images for arbitrary strings (URLs, in practice).
/// Uses Core Image's built-in QR filter with medium error correction —
/// enough slack to survive screen glare when scanned by a phone.
public enum QRCodeService {

    /// Returns a pixel-doubled NSImage at roughly `size`x`size` points.
    /// Returns `nil` only if Core Image rejects the input (very rare;
    /// QR generator accepts arbitrary bytes).
    public static func generate(from string: String, size: CGFloat = 160) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = max(1, size / output.extent.width)
        let scaled = output.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )

        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
