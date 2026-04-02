import SwiftData
import SwiftUI

// AlbumSelectorOverlay has been folded into CameraControlsView.
// AlbumPickerSheet remains here as a shared sheet component.

struct AlbumPickerSheet: View {
    @ObservedObject var albumViewModel: AlbumViewModel
    @Binding var isPresented: Bool
    @State private var newAlbumName = ""
    @State private var showCreateAlbum = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(albumViewModel.albums, id: \.id) { album in
                    Button(action: {
                        albumViewModel.selectedAlbum = album
                        isPresented = false
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.tint)
                            Text(album.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if album.id == albumViewModel.selectedAlbum?.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }

                Button(action: { showCreateAlbum = true }) {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                        Text("New Album")
                            .foregroundStyle(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
            .alert("New Album", isPresented: $showCreateAlbum) {
                TextField("Album Name", text: $newAlbumName)
                Button("Create") {
                    if !newAlbumName.isEmpty {
                        albumViewModel.createAlbum(name: newAlbumName)
                        newAlbumName = ""
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }
}
