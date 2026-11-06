import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class MusicPlayer: ObservableObject {
    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var duration = 0.0
    @Published var error: String?
    private let engine = AVPlayer()
    private var queue: [(Track, URL)] = []
    private var timeToken: Any?
    private var statusToken: NSKeyValueObservation?
    private var stateToken: NSKeyValueObservation?
    private var endToken: NSObjectProtocol?
    private var interruptionToken: NSObjectProtocol?
    private var routeToken: NSObjectProtocol?
    init() {
        timeToken = engine.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                let seconds = self.engine.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite ? max(0, seconds) : 0
                self.updateNowPlaying()
            }
        }
        stateToken = engine.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in self?.isPlaying = playing; self?.updateNowPlaying() }
        }
        endToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, item === self.engine.currentItem else { return }
                self.next()
            }
        }
        interruptionToken = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue {
                Task { @MainActor in self?.pause() }
            }
        }
        routeToken = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            if note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor in self?.pause() }
            }
        }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(position) }
            return .success
        }
    }
    func play(_ track: Track, library: MusicLibrary) {
        queue = library.tracks.compactMap { item in library.fileURL(item).map { (item, $0) } }
        guard let url = library.fileURL(track) else { return }
        start(track, url: url)
    }
    private func start(_ track: Track, url: URL) {
        statusToken = nil
        current = track; elapsed = 0; duration = 0; error = nil
        let item = AVPlayerItem(url: url)
        engine.replaceCurrentItem(with: item)
        statusToken = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let failure = item.status == .failed ? item.error?.localizedDescription ?? "Định dạng nhạc không được hỗ trợ." : nil
            Task { @MainActor in
                guard let self, self.engine.currentItem === item else { return }
                if let failure { self.error = failure; self.pause() }
            }
        }
        resume()
    }
    func resume() {
        guard current != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            if duration > 0 && elapsed >= duration - 0.2 { seek(0) }
            engine.play()
        } catch { self.error = error.localizedDescription }
    }
    func pause() { engine.pause(); isPlaying = false; updateNowPlaying() }
    func toggle() { if isPlaying { pause() } else { resume() } }
    func seek(_ seconds: Double) {
        guard seconds.isFinite else { return }
        engine.seek(to: CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600))
    }
    func next() {
        guard let index = queue.firstIndex(where: { $0.0.id == current?.id }), index + 1 < queue.count else { pause(); return }
        start(queue[index + 1].0, url: queue[index + 1].1)
    }
    func previous() {
        if elapsed > 3 { seek(0); return }
        guard let index = queue.firstIndex(where: { $0.0.id == current?.id }), index > 0 else { seek(0); return }
        start(queue[index - 1].0, url: queue[index - 1].1)
    }
    func stop() {
        pause(); engine.replaceCurrentItem(with: nil); current = nil; queue = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    private func updateNowPlaying() {
        guard let current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.title, MPMediaItemPropertyArtist: current.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
