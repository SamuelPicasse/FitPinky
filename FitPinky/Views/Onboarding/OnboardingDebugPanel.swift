import SwiftUI
import UIKit

struct OnboardingDebugPanel: View {
    @Environment(ActiveDataService.self) private var dataService
    @State private var expanded = false

    private var recentLines: [String] {
        Array(dataService.onboardingDebugLog.suffix(12))
    }

    var body: some View {
        if !recentLines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        expanded.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Diagnostics")
                                .font(.caption.weight(.semibold))
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = recentLines.joined(separator: "\n")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brand)
                    }
                    .buttonStyle(.plain)
                }

                if expanded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(recentLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
            .padding(12)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
        }
    }
}
