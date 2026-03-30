import SwiftData
import SwiftUI

struct AlbumSelectorOverlay: View {
    @ObservedObject var albumViewModel: AlbumViewModel
    @State private var isShowingPicker = false
    @State private var hasCycled = false
    @State private var albumNameOffset: CGFloat = 0
    @State private var albumNameOpacity: Double = 1.0

    var body: some View {
        VStack {
            HStack {
                Spacer()

                // Album pill — centered at top
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                    Text(albumViewModel.selectedAlbum?.name ?? "No Album")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.8))
                .background(Color.black.opacity(0.3))
                .cornerRadius(20)
                .offset(y: albumNameOffset)
                .opacity(albumNameOpacity)
                .onTapGesture {
                    isShowingPicker = true
                }
                .onLongPressGesture {
                    isShowingPicker = true
                }
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if !hasCycled && abs(value.translation.height) > 25 {
                                hasCycled = true

                                // Animate album name out
                                let goingDown = value.translation.height > 0
                                withAnimation(.easeIn(duration: 0.12)) {
                                    albumNameOffset = goingDown ? 15 : -15
                                    albumNameOpacity = 0
                                }

                                // Cycle album
                                if goingDown {
                                    albumViewModel.cycleToNextAlbum()
                                } else {
                                    albumViewModel.cycleToPreviousAlbum()
                                }

                                // Haptic
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                                // Animate new name in from opposite direction
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    albumNameOffset = goingDown ? -10 : 10
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        albumNameOffset = 0
                                        albumNameOpacity = 1
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            hasCycled = false
                            withAnimation(.easeOut(duration: 0.15)) {
                                albumNameOffset = 0
                                albumNameOpacity = 1
                            }
                        }
                )

                Spacer()
            }
            .padding(.top, 12)

            Spacer()
        }
        .sheet(isPresented: $isShowingPicker) {
            AlbumPickerSheet(albumViewModel: albumViewModel, isPresented: $isShowingPicker)
        }
    }
}

struct AlbumPickerSheet: View {
    @ObservedObject var albumViewModel: AlbumViewModel
    @Binding var isPresented: Bool
    @State private var newAlbumName = ""
    @State private var showCreateAlbum = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(albumViewModel.albums, id: \.id) { album in
                        Button(action: {
                            albumViewModel.selectedAlbum = album
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(album.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if album.id == albumViewModel.selectedAlbum?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    Button(action: {
                        showCreateAlbum = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Create New Album")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
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
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Album.self, configurations: config)
    return AlbumSelectorOverlay(albumViewModel: AlbumViewModel(modelContext: container.mainContext))
}
