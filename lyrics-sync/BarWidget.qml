import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    // ========== Standard Bar Widget Properties ==========
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    implicitWidth: barIsVertical ? Style.barHeight : Math.min(300, Math.max(Style.capsuleHeight, lyricText.implicitWidth + Style.marginL * 2))
    implicitHeight: Style.barHeight

    // Bar positioning properties
    readonly property string barPosition: Settings.data.bar.position || "top"
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusM
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    clip: true

    Behavior on color {
        ColorAnimation { duration: Style.animationNormal }
    }

    // ========== Plugin Data ==========
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property string currentLyric: mainInstance?.currentLyric ?? ""
    readonly property string trackTitle: mainInstance?.trackTitle ?? ""
    readonly property bool isPlaying: mainInstance?.isPlaying ?? false
    readonly property bool lyricsLoaded: mainInstance?.lyricsLoaded ?? false
    readonly property bool lxMusicConnected: mainInstance?.lxMusicConnected ?? false
    readonly property bool lxMusicEnabled: mainInstance?.lxMusicEnabled ?? false
    readonly property int scrollSpeed: pluginApi?.pluginSettings?.barWidgetScrollSpeed ?? 50

    // ========== Scrolling Animation for Long Lyrics ==========
    property real scrollOffset: 0
    property bool needsScroll: lyricText.implicitWidth > root.width - Style.marginM * 2

    Timer {
        id: scrollTimer
        interval: root.scrollSpeed
        running: root.needsScroll && root.isPlaying
        repeat: true
        onTriggered: {
            root.scrollOffset += 1;
            if (root.scrollOffset > lyricText.implicitWidth + 50) {
                root.scrollOffset = -root.width;
            }
        }
    }

    onCurrentLyricChanged: {
        scrollOffset = 0;
    }

    // ========== Content ==========
    RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS
        clip: true

        // Connection indicator for LX Music
        Rectangle {
            visible: root.lxMusicEnabled && !root.barIsVertical
            width: 6
            height: 6
            radius: 3
            color: root.lxMusicConnected ? "#4CAF50" : "#F44336"
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            NText {
                id: lyricText
                x: root.needsScroll ? -root.scrollOffset : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                
                text: {
                    if (!root.mainInstance) return "♪ ...";
                    // 优先显示当前歌词（如果有）
                    if (root.currentLyric) return root.currentLyric;
                    // LX Music 模式下，显示连接状态
                    if (root.lxMusicEnabled) {
                        if (!root.lxMusicConnected) return "连接中...";
                        if (!root.trackTitle) return "♪ 无音乐";
                        return "♪ ♪ ♪";
                    }
                    // 非 LX Music 模式
                    if (!root.isPlaying) return "⏸ 已暂停";
                    if (!root.lyricsLoaded) return "♪ 无歌词";
                    return "♪ ♪ ♪";
                }
                
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                pointSize: Style.fontSizeS
                font.weight: root.currentLyric ? Font.Bold : Font.Normal
                
                Behavior on x {
                    enabled: !root.needsScroll
                    NumberAnimation { duration: Style.animationNormal }
                }
                
                // 歌词切换时的淡入淡出动画
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: lyricText; property: "opacity"; to: 0.3; duration: 80 }
                        PropertyAction { target: lyricText; property: "text" }
                        NumberAnimation { target: lyricText; property: "opacity"; to: 1.0; duration: 120 }
                    }
                }
            }
        }
    }

    // ========== Mouse Interaction ==========
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen);
            }
        }
    }
}
