import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
    id: root

    property var pluginApi: null

    implicitWidth: 400
    implicitHeight: 150

    showBackground: true

    // ========== Plugin Data ==========
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property string trackTitle: mainInstance?.trackTitle ?? ""
    readonly property string trackArtist: mainInstance?.trackArtist ?? ""
    readonly property string currentLyric: mainInstance?.currentLyric ?? ""
    readonly property string currentTranslation: mainInstance?.currentTranslation ?? ""
    readonly property string nextLyric: mainInstance?.nextLyric ?? ""
    readonly property bool isPlaying: mainInstance?.isPlaying ?? false
    readonly property bool lyricsLoaded: mainInstance?.lyricsLoaded ?? false
    readonly property string lyricsError: mainInstance?.lyricsError ?? ""
    readonly property bool lxMusicConnected: mainInstance?.lxMusicConnected ?? false
    readonly property bool lxMusicEnabled: mainInstance?.lxMusicEnabled ?? false

    // ========== Settings ==========
    readonly property int fontSize: pluginApi?.pluginSettings?.fontSize ?? 14
    readonly property bool showTranslation: pluginApi?.pluginSettings?.showTranslation ?? true
    readonly property color highlightColor: pluginApi?.pluginSettings?.highlightColor ?? "#FF6B9D"
    readonly property bool scrollAnimation: pluginApi?.pluginSettings?.scrollAnimation ?? true

    // ========== Content ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        // Track Info
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            // Connection indicator for LX Music
            Rectangle {
                visible: root.lxMusicEnabled
                width: 8
                height: 8
                radius: 4
                color: root.lxMusicConnected ? "#4CAF50" : "#F44336"
            }

            NText {
                text: "♪"
                color: root.isPlaying ? root.highlightColor : Color.mOnSurfaceVariant
                pointSize: root.fontSize + 4
                
                SequentialAnimation on opacity {
                    running: root.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            NText {
                Layout.fillWidth: true
                text: root.trackTitle ? (root.trackTitle + (root.trackArtist ? " - " + root.trackArtist : "")) : "无音乐播放"
                color: Color.mOnSurface
                pointSize: root.fontSize - 2
                elide: Text.ElideRight
                opacity: 0.8
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Color.mOutline
            opacity: 0.3
        }

        // Current Lyric
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Style.marginXS

                // Main Lyric
                NText {
                    id: mainLyricText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    
                    text: {
                        if (!root.isPlaying) return "⏸ 已暂停";
                        if (root.lyricsError) return root.lyricsError;
                        if (!root.lyricsLoaded) return "♪ 等待歌词...";
                        return root.currentLyric || "♪ ♪ ♪";
                    }
                    
                    color: root.currentLyric ? root.highlightColor : Color.mOnSurfaceVariant
                    pointSize: root.fontSize + 2
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    
                    Behavior on text {
                        enabled: root.scrollAnimation
                        SequentialAnimation {
                            NumberAnimation { target: mainLyricText; property: "opacity"; to: 0.5; duration: 100 }
                            NumberAnimation { target: mainLyricText; property: "opacity"; to: 1.0; duration: 100 }
                        }
                    }
                }

                // Translation
                NText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.showTranslation && root.currentTranslation
                    text: root.currentTranslation
                    color: Color.mOnSurfaceVariant
                    pointSize: root.fontSize - 2
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                }

                // Next Lyric Preview
                NText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.nextLyric && root.lyricsLoaded
                    text: root.nextLyric
                    color: Color.mOnSurfaceVariant
                    pointSize: root.fontSize - 2
                    wrapMode: Text.WordWrap
                    opacity: 0.5
                }
            }
        }
    }

    // Click to open panel
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.openPanel(screen);
                });
            }
        }
    }
}
