import Foundation
import Combine

struct Track: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var artist: String
    var fileName: String?
    var videoID: String?
    var artwork: URL?
}

@MainActor
final class MusicLibrary: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published var error: String?
    private let root: URL
    private var index: URL { root.appendingPathComponent("library.json") }
    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: index.path) {
                tracks = try JSONDecoder().decode([Track].self, from: Data(contentsOf: index))
            }
        } catch { self.error = "Không đọc được thư viện: \(error.localizedDescription)" }
    }
    func fileURL(_ track: Track) -> URL? {
        track.fileName.map { root.appendingPathComponent($0) }
    }
    func contains(_ track: Track) -> Bool { tracks.contains { $0.id == track.id } }
    func save(_ track: Track) {
        guard !contains(track) else { return }
        var next = tracks
        next.append(track)
        commit(next)
    }
    @discardableResult private func commit(_ next: [Track]) -> Bool {
        do {
            try JSONEncoder().encode(next).write(to: index, options: .atomic)
            tracks = next
            return true
        } catch { self.error = "Không lưu được thư viện: \(error.localizedDescription)"; return false }
    }
    func remove(_ track: Track) {
        guard commit(tracks.filter { $0.id != track.id }) else { return }
        if let url = fileURL(track) {
            do { try FileManager.default.removeItem(at: url) }
            catch { self.error = "Đã bỏ khỏi thư viện nhưng chưa xoá được file: \(error.localizedDescription)" }
        }
    }
    func importFiles(_ urls: [URL]) {
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let id = UUID().uuidString
            let name = id + "." + source.pathExtension.lowercased()
            let destination = root.appendingPathComponent(name)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                let track = Track(id: id, title: source.deletingPathExtension().lastPathComponent,
                                  artist: "Nhạc trên iPhone", fileName: name)
                if !commit(tracks + [track]) { try? FileManager.default.removeItem(at: destination) }
            } catch { self.error = "Không nhập được \(source.lastPathComponent): \(error.localizedDescription)" }
        }
    }
}

// Search response layout and WEB_REMIX context adapted from Mochy Music 8.3.2.
// This provider is unofficial and may change. No account or cookie is collected.
struct MusicSearch {
    func search(_ query: String) async throws -> [Track] {
        let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("67", forHTTPHeaderField: "X-Youtube-Client-Name")
        request.setValue("1.20260707.12.00", forHTTPHeaderField: "X-Youtube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": ["client": ["clientName": "WEB_REMIX", "clientVersion": "1.20260707.12.00", "hl": "vi", "gl": "VN"]],
            "query": query
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return Self.parse(try JSONSerialization.jsonObject(with: data))
    }
    static func parse(_ json: Any) -> [Track] {
        var found: [Track] = []
        var seen = Set<String>()
        func visit(_ value: Any) {
            if let array = value as? [Any] { array.forEach(visit); return }
            guard let dict = value as? [String: Any] else { return }
            if let item = dict["musicResponsiveListItemRenderer"] as? [String: Any],
               let columns = item["flexColumns"] as? [[String: Any]] {
                let texts: [[String: Any]] = columns.compactMap {
                    ($0["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
                }
                let runs = texts.compactMap { $0["runs"] as? [[String: Any]] }
                let playlistData = item["playlistItemData"] as? [String: Any]
                let nav = item["navigationEndpoint"] as? [String: Any]
                let watch = nav?["watchEndpoint"] as? [String: Any]
                let runNav = runs.first?.first?["navigationEndpoint"] as? [String: Any]
                let runWatch = runNav?["watchEndpoint"] as? [String: Any]
                if let id = (playlistData?["videoId"] ?? watch?["videoId"] ?? runWatch?["videoId"]) as? String,
                   id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil,
                   seen.insert(id).inserted {
                    let title = runs.first?.compactMap { $0["text"] as? String }.joined() ?? "Bài hát"
                    let artist = runs.dropFirst().first?.compactMap { $0["text"] as? String }.joined() ?? "YouTube Music"
                    let thumb = (item["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any]
                    let images = (thumb?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
                    let artwork = (images?.last?["url"] as? String).flatMap(URL.init(string:))
                    found.append(Track(id: id, title: title, artist: artist, videoID: id, artwork: artwork))
                }
            }
            for key in dict.keys.sorted() { if let child = dict[key] { visit(child) } }
        }
        visit(json)
        return found
    }
}
