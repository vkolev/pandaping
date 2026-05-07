import SwiftUI

struct LinkPreviewView: View {
    let url: URL
    let isOwn: Bool

    @State private var metadata: LinkMetadata?
    @State private var fetchTask: Task<Void, Never>?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 0) {
            if let metadata {
                if metadata.isDirectImage {
                    imagePreview(metadata: metadata)
                } else {
                    richPreview(metadata: metadata)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
            }
        }
        .onAppear {
            guard metadata == nil, fetchTask == nil else { return }
            fetchTask = Task {
                metadata = await LinkPreviewCache.shared.fetch(url)
            }
        }
        .onDisappear {
            fetchTask?.cancel()
            fetchTask = nil
        }
    }

    // MARK: - Image Preview

    @ViewBuilder
    private func imagePreview(metadata: LinkMetadata) -> some View {
        let imageURL = metadata.imageURL ?? metadata.url
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { openURL(imageURL) }
            case .failure:
                fallbackCard(metadata: metadata)
            case .empty:
                ProgressView()
                    .frame(width: 100, height: 60)
            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - Rich Preview

    @ViewBuilder
    private func richPreview(metadata: LinkMetadata) -> some View {
        Button {
            openURL(metadata.url)
        } label: {
            HStack(spacing: 10) {
                if let imageURL = metadata.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        default:
                            faviconView(metadata: metadata)
                        }
                    }
                } else {
                    faviconView(metadata: metadata)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(metadata.title ?? metadata.url.host ?? metadata.url.absoluteString)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let description = metadata.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if metadata.title != nil {
                        Text(metadata.url.host ?? metadata.url.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(maxWidth: 320, alignment: .leading)
            .background(isOwn ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fallback Card

    @ViewBuilder
    private func fallbackCard(metadata: LinkMetadata) -> some View {
        Button {
            openURL(metadata.url)
        } label: {
            HStack(spacing: 8) {
                faviconView(metadata: metadata)
                Text(metadata.url.host ?? metadata.url.absoluteString)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: 320, alignment: .leading)
            .background(isOwn ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Favicon

    @ViewBuilder
    private func faviconView(metadata: LinkMetadata) -> some View {
        if let faviconURL = metadata.faviconURL {
            AsyncImage(url: faviconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    placeholderFavicon
                }
            }
        } else {
            placeholderFavicon
        }
    }

    private var placeholderFavicon: some View {
        Image(systemName: "globe")
            .font(.system(size: 20))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }
}
