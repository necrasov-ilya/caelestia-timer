pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root
    property bool editingPresets: false
    property var keyboardOwner: null
    property bool keyboardActive: false
    property bool dashboardOpen: true
    onKeyboardActiveChanged: TimerService.requestKeyboard(keyboardOwner, keyboardActive)
    Component.onCompleted: TimerService.requestKeyboard(keyboardOwner, keyboardActive)
    Component.onDestruction: TimerService.requestKeyboard(keyboardOwner, false)
    readonly property var timer: TimerService
    readonly property bool activeTimer: timer.phase === "running" || timer.phase === "paused"
    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: Math.max(Tokens.sizes.dashboard.mediaTabHeight, 390)

    DriftingShapes {
        anchors.fill: parent
        animate: root.dashboardOpen && root.timer.phase !== "paused"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraLarge

        Item {
            id: dial
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(260, root.width * 0.30)
            readonly property real diameter: Math.min(width - 20, height - 20, 320)
            property real animatedProgress: root.timer.progress
            Behavior on animatedProgress { NumberAnimation { duration: 260; easing.type: Easing.Linear } }

            MaterialShape {
                id: backdrop
                anchors.centerIn: parent
                implicitSize: dial.diameter - 42
                shape: root.timer.phase === "finished" ? MaterialShape.Sunny : MaterialShape.Cookie9Sided
                color: Colours.palette.m3surfaceContainerHigh
                opacity: 0.92
                rotation: -8
                scale: root.timer.running ? 1 : 0.95
                Behavior on color { CAnim {} }
                Behavior on scale { Anim {} }
            }

            Shape {
                anchors.centerIn: parent
                width: dial.diameter
                height: width
                opacity: root.activeTimer || root.timer.phase === "finished" ? 1 : 0
                Behavior on opacity { Anim {} }
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.palette.m3secondaryContainer
                    strokeWidth: 9
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.diameter / 2; centerY: dial.diameter / 2
                        radiusX: dial.diameter / 2 - 12; radiusY: radiusX
                        startAngle: -90; sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.palette.m3primary
                    strokeWidth: 9
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.diameter / 2; centerY: dial.diameter / 2
                        radiusX: dial.diameter / 2 - 12; radiusY: radiusX
                        startAngle: -90; sweepAngle: Math.max(0.01, dial.animatedProgress * 360)
                    }
                    Behavior on strokeColor { CAnim {} }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small
                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timer.phase === "finished" ? "check" : root.timer.phase === "paused" ? "pause" : "timer"
                    color: Colours.palette.m3primary
                    fontStyle: root.activeTimer || root.timer.phase === "finished" ? Tokens.font.icon.large : Tokens.font.icon.builders.large.scale(2.5).build()
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.activeTimer || root.timer.phase === "finished"
                    text: root.timer.timeText
                    font: Qt.font({ family: Tokens.font.headline.large.family,
                        pixelSize: root.timer.timeText.length > 5 ? 42 : 54, weight: Font.Bold })
                    color: Colours.palette.m3primary
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timer.phase === "running" ? root.timer.tr("Time for yourself", "Время для себя") :
                        root.timer.phase === "paused" ? root.timer.tr("Take your time", "Можно не спешить") :
                        root.timer.phase === "finished" ? root.timer.tr("Time's up", "Время вышло") :
                        root.timer.tr("Choose your rhythm", "Выбери свой ритм")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        text: root.timer.tr("Timer", "Таймер")
                        font: Tokens.font.headline.small
                    }
                    StyledText {
                        text: root.editingPresets ? root.timer.tr("Make them your own", "Название и время — под тебя") :
                            root.timer.tr("A little space to focus", "Немного времени на важное")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                    }
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                ColumnLayout {
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        text: root.timer.tr("Minutes", "Минуты")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    TimerSpinBox {
                        id: minutesInput
                        objectName: "timerMinutes"
                        from: 0; to: 1440; stepSize: 1
                        sourceValue: Math.floor(root.timer.state.durationSeconds / 60)
                        enabled: root.timer.editable
                        onValueModified: root.timer.setDuration(Math.max(1, Math.min(86400,
                            Math.round(value) * 60 + root.timer.state.durationSeconds % 60)))
                        Accessible.name: root.timer.tr("Minutes", "Минуты")
                    }
                }
                ColumnLayout {
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        text: root.timer.tr("Seconds", "Секунды")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    TimerSpinBox {
                        from: 0; to: 59; stepSize: 1
                        objectName: "timerSeconds"
                        sourceValue: root.timer.state.durationSeconds % 60
                        enabled: root.timer.editable
                        onValueModified: root.timer.setDuration(Math.max(1, Math.min(86400,
                            Math.floor(root.timer.state.durationSeconds / 60) * 60 + Math.round(value))))
                        Accessible.name: root.timer.tr("Seconds", "Секунды")
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                IconTextButton {
                    Layout.fillWidth: true
                    icon: root.timer.running ? "pause" : "play_arrow"
                    text: root.timer.running ? root.timer.tr("Pause", "Пауза") :
                        root.timer.phase === "paused" ? root.timer.tr("Resume", "Продолжить") : root.timer.tr("Start", "Начать")
                    font: Tokens.font.title.medium
                    disabled: !root.timer.ready
                    onClicked: root.timer.running ? root.timer.pause() : root.timer.start()
                }
                IconButton {
                    icon: "restart_alt"
                    type: IconButton.Tonal
                    disabled: !root.timer.ready || root.timer.phase === "idle"
                    onClicked: root.timer.reset()
                    Accessible.name: root.timer.tr("Reset timer", "Сбросить таймер")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                IconButton {
                    icon: root.timer.state.soundEnabled ? "volume_up" : "volume_off"
                    type: IconButton.Text
                    isToggle: true
                    checked: root.timer.state.soundEnabled
                    onClicked: root.timer.setSound(!root.timer.state.soundEnabled)
                    Accessible.name: root.timer.tr("Sound", "Звук")
                }
                IconButton {
                    icon: root.timer.state.notificationsEnabled ? "notifications_active" : "notifications_off"
                    type: IconButton.Text
                    isToggle: true
                    checked: root.timer.state.notificationsEnabled
                    onClicked: root.timer.setNotifications(!root.timer.state.notificationsEnabled)
                    Accessible.name: root.timer.tr("Notifications", "Уведомления")
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.timer.storageError || (root.activeTimer ? root.timer.tr("Your time is kept", "Время сохраняется") : root.timer.tr("Up to 24 hours", "До 24 часов"))
                    font: Tokens.font.body.small
                    color: root.timer.storageError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 290
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.timer.tr("Your presets", "Твои пресеты")
                    font: Tokens.font.title.large
                }
                IconButton {
                    icon: root.editingPresets ? "check" : "tune"
                    type: IconButton.Text
                    disabled: !root.timer.ready
                    onClicked: {
                        // Commit a focused name field before closing the editor.
                        forceActiveFocus();
                        root.editingPresets = !root.editingPresets;
                    }
                    Accessible.name: root.timer.tr("Edit presets", "Настроить пресеты")
                }
            }
            GridLayout {
                visible: !root.editingPresets
                Layout.fillWidth: true
                columns: 1
                columnSpacing: Tokens.spacing.small
                rowSpacing: Tokens.spacing.small
                Repeater {
                    model: 4
                    delegate: PresetButton {
                        required property int index
                        Layout.fillWidth: true
                        label: root.timer.presetLabel(root.timer.state.presets[index].label)
                        minutes: root.timer.state.presets[index].seconds / 60
                        selected: root.timer.state.durationSeconds === root.timer.state.presets[index].seconds
                        disabled: !root.timer.editable
                        onClicked: root.timer.setDuration(root.timer.state.presets[index].seconds)
                    }
                }
            }

            ColumnLayout {
                visible: root.editingPresets
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Repeater {
                    model: 4
                    delegate: RowLayout {
                        id: presetRow
                        required property int index
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        StyledTextField {
                            id: presetName
                            Layout.minimumWidth: 90
                            objectName: "presetName" + presetRow.index
                            Layout.fillWidth: true
                            text: root.timer.presetLabel(root.timer.state.presets[presetRow.index].label)
                            maximumLength: 32
                            onEditingFinished: {
                                if (text.trim())
                                    root.timer.updatePreset(presetRow.index, text, root.timer.state.presets[presetRow.index].seconds);
                                else
                                    text = root.timer.presetLabel(root.timer.state.presets[presetRow.index].label);
                            }
                            Accessible.name: root.timer.tr("Preset name", "Название пресета")
                        }
                        TimerSpinBox {
                            from: 1; to: 1440; stepSize: 1
                            sourceValue: Math.round(root.timer.state.presets[presetRow.index].seconds / 60)
                            onValueModified: root.timer.updatePreset(presetRow.index, presetName.text,
                                Math.round(value) * 60)
                            Accessible.name: root.timer.tr("Preset minutes", "Минуты пресета")
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.timer.tr("Minutes · saved automatically", "Минуты · сохраняется автоматически")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }


            Item { Layout.fillHeight: true }
        }
    }

    component TimerSpinBox: StyledSpinBox {
        id: spin
        property real sourceValue
        value: sourceValue
        onSourceValueChanged: value = sourceValue
        Connections {
            target: spin
            function onValueModified(): void {
                // Native spin buttons assign value internally; keep the model in sync.
                Qt.callLater(() => spin.value = spin.sourceValue);
            }
        }
    }

    component PresetButton: ButtonBase {
        id: preset
        property string label
        property real minutes
        property bool selected
        type: ButtonBase.Tonal
        checked: selected
        activeColour: Colours.palette.m3secondaryContainer
        inactiveColour: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.9)
        activeOnColour: Colours.palette.m3onSecondaryContainer
        inactiveOnColour: Colours.palette.m3onSurfaceVariant
        implicitWidth: 150
        implicitHeight: 67
        defaultRadius: Tokens.rounding.medium
        horizontalPadding: Tokens.padding.medium
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: preset.label
                color: preset.onColour
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
            StyledText {
                text: Math.round(preset.minutes * 100) / 100 + " " + TimerService.tr("min", "мин")
                color: preset.onColour
                font: Tokens.font.title.medium
            }
        }
    }
}
