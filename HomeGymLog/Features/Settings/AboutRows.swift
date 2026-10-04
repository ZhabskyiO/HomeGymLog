import SwiftUI

/// An ABOUT card link row (m5-release §2.7): accent label in the "Build a new program…" style, no trailing glyph.
/// `Link` ≈ an `<a href>` that hands the URL to Safari; the system gives it the link trait, so VoiceOver reads
/// "Privacy policy, link" with no extra modifier.
struct AboutLinkRow: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
