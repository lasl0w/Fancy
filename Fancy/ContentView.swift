//
//  ContentView.swift
//  Fancy
//
//  Created by tom montgomery on 11/10/24.
//

import SwiftUI
import Inject

private enum ImageSize {
    static let width: CGFloat = UIScreen.main.bounds.width / 2 - 24
    static let height: CGFloat = 200
    static let aspectRatio: CGFloat = width / height
}

struct Artwork: Identifiable, Equatable {
    let id = UUID()
    let imageUrl: String
    let title: String
    let artist: String
}

struct ContentView: View {
    @ObserveInjection var inject
    @State private var artworks: [Artwork] = [
        Artwork(
            imageUrl: "https://images.unsplash.com/photo-1573521193826-58c7dc2e13e3",
            title: "Liquid Dreams",
            artist: "Birmingham Museums Trust"
        ),
        Artwork(
            imageUrl: "https://images.unsplash.com/photo-1541701494587-cb58502866ab",
            title: "Abstract Flow",
            artist: "Pawel Czerwinski"
        ),
        Artwork(
            imageUrl: "https://images.unsplash.com/photo-1499781350541-7783f6c6a0c8",
            title: "Neon Waves",
            artist: "Jazmin Quaynor"
        ),
        Artwork(
            imageUrl: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe",
            title: "Digital Spectrum",
            artist: "Pawel Czerwinski"
        ),
        Artwork(
            imageUrl: "https://images.unsplash.com/photo-1574169208507-84376144848b",
            title: "Cosmic Blend",
            artist: "Pawel Czerwinski"
        )
    ]
    
    @State private var selectedArtwork: Artwork?
    @State private var favorites: Set<UUID> = []
    @Namespace private var namespace
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        TabView {
            // All Wallpapers Tab
            NavigationStack {
                GalleryView(
                    artworks: artworks,
                    selectedArtwork: $selectedArtwork,
                    favorites: $favorites,
                    namespace: namespace,
                    showingFavoritesOnly: false
                )
                .navigationTitle("All Wallpapers")
            }
            .tabItem {
                Label("All", systemImage: "photo.stack")
            }
            
            // Favorites Tab
            NavigationStack {
                GalleryView(
                    artworks: artworks.filter { favorites.contains($0.id) },
                    selectedArtwork: $selectedArtwork,
                    favorites: $favorites,
                    namespace: namespace,
                    showingFavoritesOnly: true
                )
                .navigationTitle("Favorites")
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
        }
        .enableInjection()
    }
}

struct GalleryView: View {
    let artworks: [Artwork]
    @Binding var selectedArtwork: Artwork?
    @Binding var favorites: Set<UUID>
    let namespace: Namespace.ID
    let showingFavoritesOnly: Bool
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            // Main Grid View
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(artworks) { artwork in
                        if selectedArtwork?.id != artwork.id {
                            ArtworkThumbnail(
                                artwork: artwork,
                                namespace: namespace,
                                isFavorite: favorites.contains(artwork.id)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    selectedArtwork = artwork
                                }
                            }
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if favorites.contains(artwork.id) {
                                        favorites.remove(artwork.id)
                                    } else {
                                        favorites.insert(artwork.id)
                                    }
                                }
                            }
                        } else {
                            Color.clear
                                .frame(height: 200)
                        }
                    }
                }
                .padding()
            }
            .zIndex(0)
            
            // Detail View Overlay
            if let selected = selectedArtwork {
                Color.black
                    .ignoresSafeArea()
                    .opacity(0.8)
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedArtwork = nil
                        }
                    }
                
                EnhancedArtworkDetailView(
                    artwork: selected,
                    namespace: namespace,
                    isFavorite: favorites.contains(selected.id),
                    onDismiss: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedArtwork = nil
                        }
                    },
                    onFavoriteToggle: {
                        withAnimation {
                            if favorites.contains(selected.id) {
                                favorites.remove(selected.id)
                            } else {
                                favorites.insert(selected.id)
                            }
                        }
                    }
                )
                .zIndex(2)
                .transition(.identity)
            }
        }
    }
}

struct ArtworkThumbnail: View {
    let artwork: Artwork
    let namespace: Namespace.ID
    let isFavorite: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CachedAsyncImage(url: artwork.imageUrl)
                .matchedGeometryEffect(id: artwork.id, in: namespace)
                .aspectRatio(ImageSize.aspectRatio, contentMode: .fill)
                .frame(width: ImageSize.width, height: ImageSize.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(8)
            }
        }
    }
}

struct EnhancedArtworkDetailView: View {
    let artwork: Artwork
    let namespace: Namespace.ID
    let isFavorite: Bool
    let onDismiss: () -> Void
    let onFavoriteToggle: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @GestureState private var dragState = DragState.inactive
    
    var body: some View {
        CachedAsyncImage(url: artwork.imageUrl)
            .matchedGeometryEffect(id: artwork.id, in: namespace)
            .aspectRatio(ImageSize.aspectRatio, contentMode: .fit)
            .frame(maxWidth: UIScreen.main.bounds.width - 32)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .offset(offset)
            .scaleEffect(scale)
            .gesture(
                DragGesture()
                    .updating($dragState) { drag, state, _ in
                        state = .dragging(translation: drag.translation)
                    }
                    .onChanged { gesture in
                        let translation = gesture.translation
                        offset = translation
                        let dragPercentage = abs(translation.height / UIScreen.main.bounds.height)
                        scale = 1.0 - (dragPercentage * 0.5)
                    }
                    .onEnded { gesture in
                        let dragPercentage = abs(offset.height / UIScreen.main.bounds.height)
                        if dragPercentage > 0.3 {
                            onDismiss()
                        } else {
                            withAnimation(.spring()) {
                                offset = .zero
                                scale = 1.0
                            }
                        }
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { _ in
                        if scale < 0.7 {
                            onDismiss()
                        } else {
                            withAnimation(.spring()) {
                                scale = 1.0
                            }
                        }
                    }
            )
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : .white)
                            .font(.title2)
                    }
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
    }
}

enum DragState {
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
}

struct ImageWithFavorite: View {
    @ObserveInjection var inject
    @State private var isFavorite = false
    let image: Image // Or you could use a URL/String if loading from remote
    
    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .white)
                    .shadow(radius: 3)
                    .padding(8)
            }
            .onLongPressGesture(minimumDuration: 0.5) { // You can adjust this duration
                withAnimation(.spring()) {
                    isFavorite.toggle()
                }
                
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
            .enableInjection()
    }
}

// Preview
struct ImageWithFavorite_Previews: PreviewProvider {
    static var previews: some View {
        ImageWithFavorite(image: Image("yourImageName"))
            .frame(width: 300, height: 300)
    }
}

#Preview {
    ContentView()
}
