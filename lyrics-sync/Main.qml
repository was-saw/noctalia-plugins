import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Media
import "lyricsParser.js" as LyricsParser
import "lxMusicApi.js" as LxMusicApi

Item {
    id: root

    property var pluginApi: null

    // ========== Settings ==========
    readonly property int fontSize: pluginApi?.pluginSettings?.fontSize ?? 14
    readonly property bool showTranslation: pluginApi?.pluginSettings?.showTranslation ?? true
    readonly property bool autoScroll: pluginApi?.pluginSettings?.autoScroll ?? true
    readonly property string lyricsSource: pluginApi?.pluginSettings?.lyricsSource ?? "lxmusic"
    readonly property string lyricsDirectory: pluginApi?.pluginSettings?.lyricsDirectory ?? ""
    readonly property color highlightColor: pluginApi?.pluginSettings?.highlightColor ?? "#FF6B9D"
    
    // LX Music Settings
    readonly property string lxMusicHost: pluginApi?.pluginSettings?.lxMusicHost ?? "127.0.0.1"
    readonly property int lxMusicPort: pluginApi?.pluginSettings?.lxMusicPort ?? 23330
    readonly property bool lxMusicEnabled: lyricsSource === "lxmusic"

    // ========== Current Media Info ==========
    readonly property var currentPlayer: MediaService.activePlayer
    
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string albumArt: ""
    property real positionMs: 0
    property real durationMs: 0
    property bool isPlaying: false

    // MPRIS fallback
    readonly property string mprisTitle: currentPlayer?.title ?? ""
    readonly property string mprisArtist: currentPlayer?.artist ?? ""
    readonly property int mprisPosition: currentPlayer?.position ?? 0
    readonly property int mprisDuration: currentPlayer?.length ?? 0
    readonly property bool mprisIsPlaying: currentPlayer?.isPlaying ?? false

    // ========== Lyrics Data ==========
    property var lyricsData: []
    property int currentLineIndex: -1
    property string currentLyric: ""
    property string currentTranslation: ""
    property string nextLyric: ""
    property bool lyricsLoaded: false
    property string lyricsError: ""

    // ========== LX Music Connection State ==========
    property bool lxMusicConnected: false
    property bool lxMusicConnecting: false
    property int reconnectAttempts: 0
    readonly property int maxReconnectAttempts: 5

    // ========== Track Change Detection ==========
    property string lastTrackKey: ""
    readonly property string currentTrackKey: trackTitle + "|" + trackArtist

    onCurrentTrackKeyChanged: {
        if (currentTrackKey !== lastTrackKey && currentTrackKey !== "|") {
            lastTrackKey = currentTrackKey;
            console.log("[LyricsSync] Track changed:", trackTitle);
            // 无论什么模式都加载完整歌词
            if (lxMusicEnabled) {
                loadLxMusicLyrics();
            } else {
                loadLyrics();
            }
        }
    }

    onLyricsSourceChanged: {
        console.log("[LyricsSync] Source changed to:", lyricsSource);
        if (lxMusicEnabled) {
            connectToLxMusic();
        } else {
            disconnectFromLxMusic();
            trackTitle = mprisTitle;
            trackArtist = mprisArtist;
            positionMs = mprisPosition / 1000;
            durationMs = mprisDuration / 1000;
            isPlaying = mprisIsPlaying;
            loadLyrics();
        }
    }

    // ========== Initialization ==========
    Component.onCompleted: {
        console.log("[LyricsSync] Initializing...");
        if (lxMusicEnabled) {
            connectToLxMusic();
        } else {
            trackTitle = mprisTitle;
            trackArtist = mprisArtist;
            positionMs = mprisPosition / 1000;
            durationMs = mprisDuration / 1000;
            isPlaying = mprisIsPlaying;
        }
    }

    // ========== Lyrics Sync Timer ==========
    Timer {
        id: syncTimer
        interval: 100
        running: root.isPlaying && root.lyricsLoaded && !root.lxMusicEnabled
        repeat: true
        onTriggered: root.updateCurrentLine()
    }

    // ========== LX Music Reconnect Timer ==========
    Timer {
        id: sseReconnectTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            if (root.lxMusicEnabled && !root.lxMusicConnected) {
                root.connectToLxMusic();
            }
        }
    }

    // ========== LX Music Polling Timer ==========
    Timer {
        id: ssePollTimer
        interval: 200
        running: root.lxMusicEnabled && root.lxMusicConnected
        repeat: true
        onTriggered: root.pollLxMusicStatus()
    }

    // ========== LX Music Functions ==========
    function connectToLxMusic() {
        if (lxMusicConnecting) return;
        
        console.log("[LyricsSync] Connecting to LX Music at", lxMusicHost + ":" + lxMusicPort);
        lxMusicConnecting = true;
        lyricsError = "";
        
        const url = LxMusicApi.getStatusUrl(lxMusicHost, lxMusicPort, 
            "status,name,singer,albumName,lyricLineText,lyricLineAllText,duration,progress,picUrl");
        lxStatusRequest.command = ["curl", "-s", "-m", "2", url];
        lxStatusRequest.running = true;
    }

    function disconnectFromLxMusic() {
        lxMusicConnected = false;
        lxMusicConnecting = false;
        ssePollTimer.stop();
        console.log("[LyricsSync] Disconnected from LX Music");
    }

    function pollLxMusicStatus() {
        if (!lxMusicConnected) return;
        const url = LxMusicApi.getStatusUrl(lxMusicHost, lxMusicPort, 
            "status,name,singer,albumName,lyricLineText,lyricLineAllText,duration,progress,picUrl");
        lxStatusRequest.command = ["curl", "-s", "-m", "2", url];
        lxStatusRequest.running = true;
    }

    function handleLxMusicStatus(response) {
        try {
            const data = JSON.parse(response);
            
            // Update track info
            if (data.name !== undefined) trackTitle = data.name || "";
            if (data.singer !== undefined) trackArtist = data.singer || "";
            if (data.albumName !== undefined) trackAlbum = data.albumName || "";
            if (data.picUrl !== undefined) albumArt = data.picUrl || "";
            if (data.duration !== undefined) durationMs = data.duration * 1000;
            if (data.progress !== undefined) positionMs = data.progress * 1000;
            
            // Update playback status
            if (data.status !== undefined) {
                isPlaying = (data.status === "playing");
            }
            
            // Update lyrics from LX Music
            if (data.lyricLineText !== undefined) {
                currentLyric = data.lyricLineText || "";
            }
            if (data.lyricLineAllText !== undefined) {
                const lines = (data.lyricLineAllText || "").split('\n');
                if (lines.length > 0) {
                    currentLyric = lines[0];
                    if (lines.length > 1) {
                        currentTranslation = lines.slice(1).join('\n');
                    } else {
                        currentTranslation = "";
                    }
                }
            }
            
            // 更新当前歌词索引（根据播放进度）
            updateCurrentLine();
            
            lyricsLoaded = true;
            
        } catch (e) {
            console.log("[LyricsSync] Parse error:", e);
        }
    }

    function handleLxMusicError() {
        lxMusicConnected = false;
        lxMusicConnecting = false;
        
        if (reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            lyricsError = "连接 LX Music 中...";
            console.log("[LyricsSync] Retry", reconnectAttempts);
            sseReconnectTimer.start();
        } else {
            lyricsError = "无法连接 LX Music，请确认是否已启动？";
            console.log("[LyricsSync] Max retries reached");
        }
    }

    function loadLxMusicLyrics() {
        console.log("[LyricsSync] Loading full lyrics from LX Music...");
        const url = LxMusicApi.getLyricAllUrl(lxMusicHost, lxMusicPort);
        console.log("[LyricsSync] Lyrics URL:", url);
        lxLyricRequest.command = ["curl", "-s", "-m", "5", url];
        lxLyricRequest.running = true;
    }

    // ========== LX Music Status Request ==========
    Process {
        id: lxStatusRequest
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                const response = this.text.trim();
                console.log("[LyricsSync] Got response:", response.substring(0, 100));
                root.lxMusicConnecting = false;
                root.lxMusicConnected = true;
                root.reconnectAttempts = 0;
                root.handleLxMusicStatus(response);
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            console.log("[LyricsSync] curl exited with code:", exitCode);
            if (exitCode !== 0) {
                root.lxMusicConnecting = false;
                root.handleLxMusicError();
            }
        }
    }

    // ========== LX Music Lyrics Request ==========
    Process {
        id: lxLyricRequest
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = this.text.trim();
                    console.log("[LyricsSync] Got lyrics response, length:", response.length);
                    const data = JSON.parse(response);
                    console.log("[LyricsSync] Parsed lyrics data, has lyric:", !!data.lyric, "has tlyric:", !!data.tlyric);
                    if (data.lyric) {
                        root.parseLrcContent(data.lyric, data.tlyric || "");
                    } else {
                        console.log("[LyricsSync] No lyric field in response");
                    }
                } catch (e) {
                    console.log("[LyricsSync] Lyrics parse error:", e, "response:", this.text.substring(0, 200));
                }
            }
        }
    }

    // ========== Local Lyrics ==========
    function loadLyrics() {
        lyricsData = [];
        currentLineIndex = -1;
        currentLyric = "";
        currentTranslation = "";
        nextLyric = "";
        lyricsLoaded = false;
        lyricsError = "";

        if (!trackTitle) {
            lyricsError = "无曲目信息";
            return;
        }

        console.log("[LyricsSync] Loading lyrics for:", trackTitle);

        if (lyricsSource === "local") {
            loadLocalLyrics();
        } else if (lyricsSource === "lxmusic") {
            loadLxMusicLyrics();
        }
    }

    function loadLocalLyrics() {
        const trackUrl = currentPlayer?.trackUrl ?? "";
        
        if (trackUrl) {
            const musicPath = trackUrl.replace("file://", "");
            const lrcPath = musicPath.replace(/\.[^/.]+$/, ".lrc");
            lyricsFileReader.path = lrcPath;
        } else if (lyricsDirectory) {
            const sanitizedTitle = trackTitle.replace(/[\/\\:*?"<>|]/g, "_");
            const sanitizedArtist = trackArtist.replace(/[\/\\:*?"<>|]/g, "_");
            const lrcPath = lyricsDirectory + "/" + sanitizedArtist + " - " + sanitizedTitle + ".lrc";
            lyricsFileReader.path = lrcPath;
        } else {
            lyricsError = "未配置歌词来源";
        }
    }

    function parseLrcContent(content, translationContent) {
        const result = LyricsParser.parseLrc(content);
        
        if (translationContent && !result.error) {
            const transResult = LyricsParser.parseLrc(translationContent);
            if (!transResult.error && transResult.lyrics.length > 0) {
                const transMap = {};
                for (const line of transResult.lyrics) {
                    transMap[line.time] = line.text;
                }
                for (const line of result.lyrics) {
                    if (transMap[line.time]) {
                        line.translation = transMap[line.time];
                    }
                }
            }
        }
        
        if (result.error) {
            lyricsError = result.error;
            lyricsLoaded = false;
        } else {
            lyricsData = result.lyrics;
            lyricsLoaded = true;
            console.log("[LyricsSync] Loaded", lyricsData.length, "lines");
        }
    }

    function updateCurrentLine() {
        if (!lyricsData || lyricsData.length === 0) return;

        const pos = positionMs;
        let newIndex = -1;

        for (let i = lyricsData.length - 1; i >= 0; i--) {
            if (lyricsData[i].time <= pos) {
                newIndex = i;
                break;
            }
        }

        if (newIndex !== currentLineIndex) {
            currentLineIndex = newIndex;
            
            if (newIndex >= 0 && newIndex < lyricsData.length) {
                currentLyric = lyricsData[newIndex].text;
                currentTranslation = lyricsData[newIndex].translation || "";
                
                if (newIndex + 1 < lyricsData.length) {
                    nextLyric = lyricsData[newIndex + 1].text;
                } else {
                    nextLyric = "";
                }
            } else {
                currentLyric = "";
                currentTranslation = "";
                nextLyric = lyricsData.length > 0 ? lyricsData[0].text : "";
            }
        }
    }

    // ========== LX Music Controls ==========
    function lxPlay() {
        lxControlRequest.command = ["curl", "-s", "-X", "GET",
            LxMusicApi.buildUrl(lxMusicHost, lxMusicPort, "/play")];
        lxControlRequest.running = true;
    }
    
    function lxPause() {
        lxControlRequest.command = ["curl", "-s", "-X", "GET",
            LxMusicApi.buildUrl(lxMusicHost, lxMusicPort, "/pause")];
        lxControlRequest.running = true;
    }
    
    function lxNext() {
        lxControlRequest.command = ["curl", "-s", "-X", "GET",
            LxMusicApi.buildUrl(lxMusicHost, lxMusicPort, "/skip-next")];
        lxControlRequest.running = true;
    }
    
    function lxPrev() {
        lxControlRequest.command = ["curl", "-s", "-X", "GET",
            LxMusicApi.buildUrl(lxMusicHost, lxMusicPort, "/skip-prev")];
        lxControlRequest.running = true;
    }
    
    function lxSeek(seconds) {
        lxControlRequest.command = ["curl", "-s", "-X", "GET",
            LxMusicApi.buildUrl(lxMusicHost, lxMusicPort, "/seek") + "?offset=" + seconds];
        lxControlRequest.running = true;
    }

    Process {
        id: lxControlRequest
        running: false
    }

    // ========== File Reader ==========
    FileView {
        id: lyricsFileReader
        path: ""
        
        onLoaded: {
            const content = lyricsFileReader.text;
            if (content) {
                root.parseLrcContent(content, "");
            } else {
                root.lyricsError = "歌词文件未找到";
                console.log("[LyricsSync] File not found:", path);
            }
        }
    }

    // ========== MPRIS Fallback ==========
    Connections {
        target: MediaService
        enabled: !root.lxMusicEnabled
        
        function onActivePlayerChanged() {
            root.trackTitle = root.mprisTitle;
            root.trackArtist = root.mprisArtist;
            root.durationMs = root.mprisDuration / 1000;
            root.isPlaying = root.mprisIsPlaying;
        }
    }
    
    Timer {
        interval: 500
        running: !root.lxMusicEnabled && root.isPlaying
        repeat: true
        onTriggered: {
            root.positionMs = root.mprisPosition / 1000;
        }
    }
}
