import SwiftUI

struct AlbumCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumName = ""
    @State private var selectedColor = Color.blue
    @State private var selectedEmoji = "📷"

    let onCreateAlbum: (String, Color, String) -> Void

    let emojis = ["📷", "📸", "🎬", "🎥", "🎞️", "📹", "🖼️", "🌅", "🌄", "🌠"]
    let colors: [Color] = [.blue, .green, .red, .purple, .orange, .pink, .yellow, .cyan]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Album Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Enter album name", text: $albumName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(spacing: 12) {
                    Text("Choose Color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                        }
                        Spacer()
                    }
                }

                VStack(spacing: 12) {
                    Text("Choose Emoji")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                Text(emoji)
                                    .font(.system(size: 24))
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedEmoji == emoji ? selectedColor.opacity(0.3) : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColor, lineWidth: selectedEmoji == emoji ? 2 : 0)
                                    )
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                    .foregroundColor(.primary)

                    Button(action: {
                        if !albumName.isEmpty {
                            onCreateAlbum(albumName, selectedColor, selectedEmoji)
                            dismiss()
                        }
                    }) {
                        Text("Create")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(albumName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .disabled(albumName.isEmpty)
                }
            }
            .padding(20)
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AlbumCreationSheet(onCreateAlbum: { _, _, _ in })
}
