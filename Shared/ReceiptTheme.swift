import SwiftUI

/// Thermal-receipt look: paper, ink, monospaced type, dashed rules. Colors live in the asset
/// catalog with separate light ("day receipt") and dark ("night receipt") values.
enum ReceiptTheme {
    #if os(watchOS)
    // The watch has no light appearance and its asset catalogs ignore the dark variants, so the
    // night receipt values are repeated here.
    static let paper = Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x18 / 255)
    static let ink = Color(red: 0xE8 / 255, green: 0xE2 / 255, blue: 0xD0 / 255)
    static let inkSecondary = Color(red: 0xA8 / 255, green: 0xA3 / 255, blue: 0x96 / 255)
    static let dash = Color(red: 0x6B / 255, green: 0x67 / 255, blue: 0x5E / 255)
    static let desk = Color(red: 0x0E / 255, green: 0x0D / 255, blue: 0x0C / 255)
    #else
    static let paper = Color("Paper")
    static let ink = Color("Ink")
    static let inkSecondary = Color("InkSecondary")
    static let dash = Color("Dash")
    static let desk = Color("Desk")
    #endif

    static let maxWidth: CGFloat = 420

    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(ReceiptTheme.dash, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// A sheet of receipt paper with a torn, zigzag bottom edge.
struct ReceiptPaper: Shape {
    var tooth: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: rect.origin)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tooth))
            let count = max(Int(rect.width / (tooth * 2)), 1)
            let step = rect.width / CGFloat(count)
            for i in 0..<count {
                let x = rect.maxX - CGFloat(i) * step
                p.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
                p.addLine(to: CGPoint(x: x - step, y: rect.maxY - tooth))
            }
            p.closeSubpath()
        }
    }
}

struct ReceiptRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 12)
            Text(verbatim: value)
                .multilineTextAlignment(.trailing)
        }
        .font(ReceiptTheme.font(.callout))
        .foregroundStyle(ReceiptTheme.ink)
    }
}
