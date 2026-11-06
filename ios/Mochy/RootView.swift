import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct RootView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var loading = false
    @State private var searchError: String?
    @State private var searched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var importPresented = false
    @State private var onlineTrack: Track?
    @State private var playerPresented = false
    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section {
                        Text("MOCHY").font(.system(size: 38, weight: .black, design: .rounded)).foregroundStyle(.mint)
                        Text("Một chút nhạc cho ngày của bạn.").foregroundStyle(.secondary)
                    }.listRowBackground(Color.clear)
                    Section {
                        if loading { HStack { ProgressView(); Text("Đang tìm bài…") } }
                        if let searchError { Text(searchError).foregroundStyle(.orange) }
                        ForEach(results) { track in
                            HStack {
                                Button { open(track) } label: { TrackRow(track: track) }.buttonStyle(.plain)
                                Spacer(minLength: 8)
                                Button { library.save(track) } label: {
                                    Image(systemName: library.contains(track) ? "heart.fill" : "heart")
                                }.buttonStyle(.borderless).disabled(library.contains(track)).accessibilityLabel("Lưu bài")
                            }
                        }
                        if !loading && results.isEmpty && searchError == nil {
                            ContentUnavailableView(searched ? "Chưa tìm thấy bài" : "Tìm nhạc bạn thích",
                                                   systemImage: "magnifyingglass",
                                                   description: Text("Nhập tên bài hát hoặc ca sĩ ở ô tìm kiếm."))
                        }
                    } header: { Text("YouTube Music") }
                    Section {
                        Text("Bản thử iOS 0.1. Nhạc online mở bằng trình phát web YouTube; chưa hỗ trợ tải nhạc online hoặc phát nền online.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Khám phá").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "Bài hát, ca sĩ…")
                .onSubmit(of: .search) { search() }
            }.tabItem { Label("Khám phá", systemImage: "sparkles") }
            NavigationStack {
                List {
                    if library.tracks.isEmpty {
                        ContentUnavailableView("Nhạc của bạn", systemImage: "music.note.list",
                            description: Text("Nhấn dấu + để nhập nhạc từ Tệp, hoặc lưu bài từ mục Khám phá."))
                    }
                    ForEach(library.tracks) { track in
                        Button { open(track) } label: { TrackRow(track: track) }.buttonStyle(.plain)
                            .swipeActions {
                                Button("Xoá", role: .destructive) {
                                    if player.current?.id == track.id { player.stop() }
                                    library.remove(track)
                                }
                            }
                    }
                }.navigationTitle("Thư viện")
                    .toolbar { Button { importPresented = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nhập nhạc") }
            }.tabItem { Label("Thư viện", systemImage: "square.stack") }
            NavigationStack {
                Form {
                    Section("Mochy iOS · 0.1 thử nghiệm") {
                        Text("Bản chuyển sang iOS chưa đầy đủ tính năng của Mochy Android 8.3.2.")
                        Text("Nhạc trong Tệp: phát bằng trình phát iOS, có hàng đợi và điều khiển màn hình khoá.")
                        Text("YouTube: tìm kiếm thử nghiệm, lưu bài và mở trang phát trong ứng dụng. Khả năng phát do YouTube quyết định.")
                    }
                    Section("Mã nguồn & giấy phép") {
                        Link("Mochy Music gốc", destination: URL(string: "https://github.com/realidkroo/Mochy-Music")!)
                        Link("Mã nguồn bản iOS", destination: URL(string: "https://github.com/anhtuan119/Mochy-iOS")!)
                        Text("GPL-3.0 · Bản chuyển đổi không chính thức. Không phải ứng dụng của Google hay YouTube.").font(.footnote)
                    }
                }.navigationTitle("Thông tin")
            }.tabItem { Label("Thông tin", systemImage: "info.circle") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let current = player.current {
                HStack {
                    Button { playerPresented = true } label: {
                        HStack {
                            Image(systemName: "waveform").foregroundStyle(.mint).frame(width: 35)
                            VStack(alignment: .leading) {
                                Text(current.title).lineLimit(1).font(.subheadline.bold())
                                Text(current.artist).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }.accessibilityLabel("Phát hoặc tạm dừng")
                    Button { player.next() } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.accessibilityLabel("Bài tiếp")
                }.padding(.horizontal).padding(.vertical, 6).background(.ultraThinMaterial)
            }
        }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): library.importFiles(urls)
            case .failure(let error): library.error = error.localizedDescription
            }
        }
        .sheet(item: $onlineTrack) { track in
            OnlinePlayer(track: track)
        }
        .sheet(isPresented: $playerPresented) { NowPlayingView().environmentObject(player) }
        .alert("Không thể hoàn tất", isPresented: Binding(get: { library.error != nil || player.error != nil }, set: { if !$0 { library.error = nil; player.error = nil } })) {
            Button("Đóng") { library.error = nil; player.error = nil }
        } message: { Text(library.error ?? player.error ?? "") }
    }
    private func open(_ track: Track) {
        if track.videoID != nil { player.pause(); onlineTrack = track }
        else { player.play(track, library: library) }
    }
    private func search() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []; searchError = nil; searched = !text.isEmpty
        guard !text.isEmpty else { loading = false; return }
        loading = true
        searchTask = Task { @MainActor in
            do {
                let tracks = try await MusicSearch().search(text)
                guard !Task.isCancelled else { return }
                results = tracks
                loading = false
            } catch {
                guard !Task.isCancelled else { return }
                loading = false
                searchError = "Không tìm được lúc này. Kiểm tra mạng rồi thử lại. Nguồn tìm kiếm có thể đã thay đổi."
            }
        }
    }
}

private struct TrackRow: View {
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artwork) { image in image.resizable().scaledToFill() } placeholder: {
                ZStack { Color.mint.opacity(0.12); Image(systemName: "music.note").foregroundStyle(.mint) }
            }.frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 4).contentShape(Rectangle())
    }
}

private struct NowPlayingView: View {
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    @State private var dragging = false
    @State private var scrub = 0.0
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 36).fill(LinearGradient(colors: [.mint.opacity(0.6), .teal.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note").font(.system(size: 88)).foregroundStyle(.white)
                }.frame(maxWidth: 290, maxHeight: 290).aspectRatio(1, contentMode: .fit)
                VStack(spacing: 8) {
                    Text(player.current?.title ?? "Chưa chọn bài").font(.title2.bold()).multilineTextAlignment(.center)
                    Text(player.current?.artist ?? "").foregroundStyle(.secondary)
                }
                VStack {
                    Slider(value: Binding(get: { dragging ? scrub : player.elapsed }, set: { scrub = $0 }), in: 0...max(player.duration, 1)) { editing in
                        if editing { scrub = player.elapsed; dragging = true }
                        else { player.seek(scrub); dragging = false }
                    }.disabled(player.duration <= 0)
                    HStack { Text(time(player.elapsed)); Spacer(); Text(time(player.duration)) }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                HStack(spacing: 40) {
                    Button { player.previous() } label: { Image(systemName: "backward.end.fill").font(.title) }
                    Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 72)) }
                    Button { player.next() } label: { Image(systemName: "forward.end.fill").font(.title) }
                }
                Spacer()
            }.padding(30).navigationTitle("Đang phát").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Đóng") { dismiss() } }
        }
    }
    private func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct OnlinePlayer: View {
    let track: Track
    @Environment(\.dismiss) var dismiss
    @State private var failure: String?
    private var url: URL { URL(string: "https://m.youtube.com/watch?v=\(track.videoID ?? "")")! }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let failure { Text(failure).font(.footnote).foregroundStyle(.orange).padding() }
                YouTubeWebView(url: url, failure: $failure)
                Text("Trình phát YouTube · Nhấn phát trên trang. Bản này chưa hỗ trợ nghe nền online.")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }.navigationTitle(track.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Link(destination: url) { Image(systemName: "safari") } }
                }
        }
    }
}

private struct YouTubeWebView: UIViewRepresentable {
    let url: URL
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator(failure: $failure) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: url))
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.loadHTMLString("", baseURL: nil)
        uiView.navigationDelegate = nil
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var failure: String?
        init(failure: Binding<String?>) { _failure = failure }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failure = "Không tải được YouTube. Thử mở bằng nút Safari." }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failure = error.localizedDescription }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure = "Trang phát đã dừng. Đóng rồi mở lại bài hát." }
    }
}
