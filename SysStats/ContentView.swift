import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SysStats")
                .font(.headline)
                .padding(.bottom, 4)

            Divider()

            Text("System statistics will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding()
        .frame(width: 280, height: 180)
    }
}

#Preview {
    ContentView()
}
