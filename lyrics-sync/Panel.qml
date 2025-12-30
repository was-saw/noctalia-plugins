import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen

    // SmartPanel
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 550 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    // ========== Plugin Data ==========
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property string trackTitle: mainInstance?.trackTitle ?? ""
    readonly property string trackArtist: mainInstance?.trackArtist ?? ""
    readonly property var lyricsData: mainInstance?.lyricsData ?? []
    readonly property int currentLineIndex: mainInstance?.currentLineIndex ?? -1
    readonly property bool isPlaying: mainInstance?.isPlaying ?? false
    readonly property bool lyricsLoaded: mainInstance?.lyricsLoaded ?? false
    readonly property string lyricsError: mainInstance?.lyricsError ?? ""
    readonly property real positionMs: mainInstance?.positionMs ?? 0
    readonly property real durationMs: mainInstance?.durationMs ?? 0
    readonly property bool lxMusicConnected: mainInstance?.lxMusicConnected ?? false
    readonly property bool lxMusicEnabled: mainInstance?.lxMusicEnabled ?? false
    readonly property string albumArt: mainInstance?.albumArt ?? ""
    readonly property string currentLyric: mainInstance?.currentLyric ?? ""
    readonly property string currentTranslation: mainInstance?.currentTranslation ?? ""

    // ========== Settings ==========
    readonly property int fontSize: pluginApi?.pluginSettings?.fontSize ?? 14
    readonly property bool showTranslation: pluginApi?.pluginSettings?.showTranslation ?? true
    readonly property color highlightColor: pluginApi?.pluginSettings?.highlightColor ?? "#FF6B9D"
    readonly property bool autoScroll: pluginApi?.pluginSettings?.autoScroll ?? true

    // Auto scroll to current line when index changes
    onCurrentLineIndexChanged: {
        if (root.autoScroll && root.currentLineIndex >= 0 && lyricsListView.count > 0) {
            lyricsListView.positionViewAtIndex(root.currentLineIndex, ListView.Center);
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Color.transparent

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // ========== Header ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: headerContent.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                RowLayout {
                    id: headerContent
                    anchors {
                        fill: parent
                        margins: Style.marginM
                    }
                    spacing: Style.marginM

                    // Album Art
                    Rectangle {
                        width: 60
                        height: 60
                        radius: Style.radiusM
                        color: Color.mSurface
                        visible: root.albumArt || root.trackTitle

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: root.albumArt
                            fillMode: Image.PreserveAspectCrop
                            visible: root.albumArt
                        }

                        NText {
                            anchors.centerIn: parent
                            text: "♪"
                            pointSize: 24
                            color: Color.mOnSurfaceVariant
                            visible: !root.albumArt
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        // Connection status for LX Music
                        RowLayout {
                            visible: root.lxMusicEnabled
                            spacing: Style.marginXS

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: root.lxMusicConnected ? "#4CAF50" : "#F44336"
                            }

                            NText {
                                text: root.lxMusicConnected ? "LX Music" : "未连接"
                                color: Color.mOnSurfaceVariant
                                pointSize: Style.fontSizeS - 2
                            }
                        }

                        NText {
                            Layout.fillWidth: true
                            text: root.trackTitle || "无曲目"
                            color: Color.mOnSurface
                            pointSize: root.fontSize + 2
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        NText {
                            Layout.fillWidth: true
                            text: root.trackArtist || ""
                            color: Color.mOnSurfaceVariant
                            pointSize: root.fontSize - 1
                            elide: Text.ElideRight
                            visible: root.trackArtist
                        }
                    }
                }
            }

            // ========== Playback Controls (LX Music) ==========
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.marginM
                visible: root.lxMusicEnabled && root.lxMusicConnected

                NButton {
                    icon: "player-skip-back"
                    onClicked: {
                        if (root.mainInstance) root.mainInstance.lxPrev();
                    }
                }

                NButton {
                    icon: root.isPlaying ? "player-pause" : "player-play"
                    onClicked: {
                        if (root.mainInstance) {
                            if (root.isPlaying) {
                                root.mainInstance.lxPause();
                            } else {
                                root.mainInstance.lxPlay();
                            }
                        }
                    }
                }

                NButton {
                    icon: "player-skip-forward"
                    onClicked: {
                        if (root.mainInstance) root.mainInstance.lxNext();
                    }
                }
            }

            // Progress bar
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: root.isPlaying || root.positionMs > 0

                NText {
                    text: formatTime(root.positionMs)
                    color: Color.mOnSurfaceVariant
                    pointSize: root.fontSize - 2
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Color.mSurfaceVariant

                    Rectangle {
                        width: root.durationMs > 0 ? parent.width * (root.positionMs / root.durationMs) : 0
                        height: parent.height
                        radius: parent.radius
                        color: root.highlightColor
                        
                        Behavior on width {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: root.lxMusicEnabled && root.lxMusicConnected
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (root.mainInstance && root.durationMs > 0) {
                                const seekPos = (mouse.x / width) * (root.durationMs / 1000);
                                root.mainInstance.lxSeek(seekPos);
                            }
                        }
                    }
                }

                NText {
                    text: formatTime(root.durationMs)
                    color: Color.mOnSurfaceVariant
                    pointSize: root.fontSize - 2
                }
            }

            // ========== Separator ==========
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
                opacity: 0.3
            }

            // ========== Current Lyric Display ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    // Current lyric (large)
                    NText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.currentLyric || "暂无歌词"
                        color: root.currentLyric ? root.highlightColor : Color.mOnSurfaceVariant
                        pointSize: root.fontSize + 4
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                    }

                    // Translation
                    NText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.showTranslation && root.currentTranslation
                        text: root.currentTranslation
                        color: Color.mOnSurfaceVariant
                        pointSize: root.fontSize
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    // Lyrics list (scrollable)
                    ListView {
                        id: lyricsListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Style.marginS
                        visible: root.lyricsData.length > 0

                        model: root.lyricsData

                        delegate: Item {
                            width: lyricsListView.width
                            height: lyricColumn.height + Style.marginXS

                            property bool isCurrent: index === root.currentLineIndex

                            ColumnLayout {
                                id: lyricColumn
                                width: parent.width
                                spacing: 2

                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.text || ""
                                    color: isCurrent ? root.highlightColor : Color.mOnSurface
                                    pointSize: isCurrent ? root.fontSize + 2 : root.fontSize
                                    font.weight: isCurrent ? Font.Bold : Font.Normal
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    opacity: isCurrent ? 1.0 : 0.6

                                    Behavior on pointSize {
                                        NumberAnimation { duration: 150 }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }
                                }

                                NText {
                                    Layout.fillWidth: true
                                    visible: root.showTranslation && modelData.translation
                                    text: modelData.translation || ""
                                    color: Color.mOnSurfaceVariant
                                    pointSize: root.fontSize - 2
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    opacity: isCurrent ? 0.8 : 0.4
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("[LyricsSync] Clicked line", index, "at time", modelData.time);
                                }
                            }
                        }
                    }

                    // Placeholder when no lyrics
                    NText {
                        Layout.alignment: Qt.AlignCenter
                        visible: !root.lyricsLoaded || root.lyricsData.length === 0
                        text: root.lyricsError || "暂无歌词"
                        color: Color.mOnSurfaceVariant
                        pointSize: root.fontSize
                    }
                }
            }

            // ========== Actions ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    icon: "refresh"
                    text: "重新加载"
                    onClicked: {
                        if (root.mainInstance) {
                            if (root.lxMusicEnabled) {
                                root.mainInstance.loadLxMusicLyrics();
                            } else {
                                root.mainInstance.loadLyrics();
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                NText {
                    text: "设置请在插件管理中打开"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    opacity: 0.7
                }
            }
        }
    }

    // ========== Helper Functions ==========
    function formatTime(ms) {
        const totalSeconds = Math.floor(ms / 1000);
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = totalSeconds % 60;
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }
}
