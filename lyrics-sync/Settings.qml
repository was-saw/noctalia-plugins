import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    // Local state
    property int valueFontSize: pluginApi?.pluginSettings?.fontSize ?? 14
    property bool valueShowTranslation: pluginApi?.pluginSettings?.showTranslation ?? true
    property bool valueAutoScroll: pluginApi?.pluginSettings?.autoScroll ?? true
    property bool valueScrollAnimation: pluginApi?.pluginSettings?.scrollAnimation ?? true
    property color valueHighlightColor: pluginApi?.pluginSettings?.highlightColor ?? "#FF6B9D"
    property string valueLyricsSource: pluginApi?.pluginSettings?.lyricsSource ?? "lxmusic"
    property string valueLyricsDirectory: pluginApi?.pluginSettings?.lyricsDirectory ?? ""
    property string valueLxMusicHost: pluginApi?.pluginSettings?.lxMusicHost ?? "127.0.0.1"
    property string valueLxMusicPort: String(pluginApi?.pluginSettings?.lxMusicPort ?? 23330)
    property int valueScrollSpeed: pluginApi?.pluginSettings?.barWidgetScrollSpeed ?? 50

    spacing: Style.marginL

    // ========== 歌词来源 ==========
    NComboBox {
        label: "来源类型"
        description: "歌词来源"

        model: [
            { key: "lxmusic", name: "LX Music" },
            { key: "local", name: "本地文件" }
        ]

        currentKey: root.valueLyricsSource
        onSelected: key => root.valueLyricsSource = key
    }

    // ========== LX Music 设置 ==========
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        visible: root.valueLyricsSource === "lxmusic"

        NTextInput {
            Layout.fillWidth: true
            label: "LX Music 地址"
            description: "API 服务器地址"
            placeholderText: "127.0.0.1"
            text: root.valueLxMusicHost
            onTextChanged: root.valueLxMusicHost = text
        }

        NTextInput {
            Layout.fillWidth: true
            label: "LX Music 端口"
            description: "默认 23330"
            placeholderText: "23330"
            text: root.valueLxMusicPort
            onTextChanged: root.valueLxMusicPort = text
        }

        // 连接状态
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: pluginApi?.mainInstance?.lxMusicConnected ? "#4CAF50" : "#F44336"
            }

            NText {
                text: pluginApi?.mainInstance?.lxMusicConnected ? "已连接" : "未连接"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }

            Item { Layout.fillWidth: true }

            NButton {
                text: "重新连接"
                onClicked: {
                    if (pluginApi?.mainInstance) {
                        pluginApi.mainInstance.reconnectAttempts = 0;
                        pluginApi.mainInstance.connectToLxMusic();
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            text: "请在 LX Music 设置中启用「开放 API 服务」（默认端口 23330）"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS - 1
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }

    // ========== 本地文件设置 ==========
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        visible: root.valueLyricsSource === "local"

        NTextInput {
            Layout.fillWidth: true
            label: "歌词目录"
            description: "将 .lrc 文件放在音乐文件同目录，或指定歌词目录"
            placeholderText: "/path/to/lyrics"
            text: root.valueLyricsDirectory
            onTextChanged: root.valueLyricsDirectory = text
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL
        Layout.bottomMargin: Style.marginL
    }

    // ========== 显示设置 ==========
    NLabel {
        label: "显示"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NLabel {
            label: "字体大小"
        }

        NValueSlider {
            Layout.fillWidth: true
            from: 10
            to: 24
            stepSize: 1
            value: root.valueFontSize
            onMoved: value => root.valueFontSize = value
            text: root.valueFontSize.toString()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "高亮颜色"
            Layout.alignment: Qt.AlignTop
        }

        NColorPicker {
            selectedColor: root.valueHighlightColor
            onColorSelected: color => root.valueHighlightColor = color
        }
    }

    NToggle {
        label: "显示翻译"
        description: "有翻译时显示翻译歌词"
        checked: root.valueShowTranslation
        onToggled: checked => root.valueShowTranslation = checked
    }

    NToggle {
        label: "自动滚动"
        description: "自动滚动到当前歌词"
        checked: root.valueAutoScroll
        onToggled: checked => root.valueAutoScroll = checked
    }

    NToggle {
        label: "滚动动画"
        description: "歌词切换时的动画效果"
        checked: root.valueScrollAnimation
        onToggled: checked => root.valueScrollAnimation = checked
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL
        Layout.bottomMargin: Style.marginL
    }

    // ========== 状态栏组件设置 ==========
    NLabel {
        label: "状态栏组件"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NLabel {
            label: "滚动速度"
            description: "长歌词滚动速度 (ms)"
        }

        NValueSlider {
            Layout.fillWidth: true
            from: 20
            to: 100
            stepSize: 10
            value: root.valueScrollSpeed
            onMoved: value => root.valueScrollSpeed = value
            text: root.valueScrollSpeed + "ms"
        }
    }

    // ========== 保存函数 ==========
    function saveSettings() {
        if (!pluginApi) return;

        pluginApi.pluginSettings.fontSize = root.valueFontSize;
        pluginApi.pluginSettings.showTranslation = root.valueShowTranslation;
        pluginApi.pluginSettings.autoScroll = root.valueAutoScroll;
        pluginApi.pluginSettings.scrollAnimation = root.valueScrollAnimation;
        pluginApi.pluginSettings.highlightColor = root.valueHighlightColor.toString();
        pluginApi.pluginSettings.lyricsSource = root.valueLyricsSource;
        pluginApi.pluginSettings.lyricsDirectory = root.valueLyricsDirectory;
        pluginApi.pluginSettings.lxMusicHost = root.valueLxMusicHost;
        pluginApi.pluginSettings.lxMusicPort = parseInt(root.valueLxMusicPort) || 23330;
        pluginApi.pluginSettings.barWidgetScrollSpeed = root.valueScrollSpeed;

        pluginApi.saveSettings();
    }
}
