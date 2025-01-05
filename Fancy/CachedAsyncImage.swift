import SwiftUI

actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: Image] = [:]
    
    func image(for url: String) -> Image? {
        cache[url]
    }
    
    func insert(_ image: Image, for url: String) {
        cache[url] = image
    }
}

struct CachedAsyncImage: View {
    let url: String
    @State private var image: Image?
    
    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        if let cached = await ImageCache.shared.image(for: url) {
            image = cached
            return
        }
        
        guard let imageUrl = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: imageUrl),
              let uiImage = UIImage(data: data) else {
            return
        }
        
        let loadedImage = Image(uiImage: uiImage)
        await ImageCache.shared.insert(loadedImage, for: url)
        image = loadedImage
    }
} 