import SwiftUI

struct AlbumCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumName      = ""
    @State private var selectedColor  = Color.blue
    @State private var selectedEmoji  = "📷"

    let onCreateAlbum: (String, Color, String) -> Void

    let emojis:  [String] = ["📷", "📸", "🎬", "🎥", "🎞️", "📹", "🖼️", "🌅", "🌄", "🌠"]
    let colors:  [Color]  = [.blue, .green, .red, .purple, .orange, .pink, .yellow, .cyan]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Preview badge ──────────────────────────────────────
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [selectedColor.opacity(0.8), selectedColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        Text(selectedEmoji)
                            .font(.system(size: 34))
                    }
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.3), value: selectedColor)

                    // ── Album name ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Album Name", systemImage: "folder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Enter album name", text: $albumName)
                            .font(.system(size: 16, weight: .medium))
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                    }

                    // ── Color picker ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Color", systemImage: "paintpalette")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    .white,
                                                    lineWidth: selectedColor == color ? 2.5 : 0
                                                )
                                        )
                                        .shadow(
                                            color: color.opacity(selectedColor == color ? 0.5 : 0),
                                            radius: 6
                                        )
                                        .animation(.spring(duration: 0.2), value: selectedColor == color)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                    // ── Emoji picker ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Icon", systemImage: "face.smiling")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
                            ForEach(emojis, id: \.self) { emoji in
                                Button(action: { selectedEmoji = emoji }) {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .frame(width: 52, height: 48)
                                        .background(
                                            selectedEmoji == emoji
                                                ? selectedColor.opacity(0.2)
                                                : Color(.systemGray6),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(
                                                    selectedEmoji == emoji ? selectedColor : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .animation(.spring(duration: 0.2), value: selectedEmoji == emoji)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if !albumName.isEmpty {
                            onCreateAlbum(albumName, selectedColor, selectedEmoji)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(albumName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AlbumCreationSheet(onCreateAlbum: { _, _, _ in })
}
