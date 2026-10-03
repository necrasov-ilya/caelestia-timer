pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    readonly property var timer: TimerService
    readonly property bool activeTimer: timer.phase === "running" || timer.phase === "paused"
    readonly property bool presented: dashboardOpen && (keyboardActive || !keyboardOwner)
    readonly property string sessionName: {
        const preset = timer.state.presets.find(item => item.seconds === timer.state.durationSeconds);
        return preset ? timer.presetLabel(preset.label) : timer.tr("Custom timer", "Своё время");
    }

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight

    onKeyboardActiveChanged: TimerService.requestKeyboard(keyboardOwner, keyboardActive)
    Component.onCompleted: TimerService.requestKeyboard(keyboardOwner, keyboardActive)
    Component.onDestruction: TimerService.requestKeyboard(keyboardOwner, false)

    DriftingShapes {
        anchors.fill: parent
        animate: root.presented && root.timer.phase !== "paused"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraLarge

        Item {
            id: dial

            Layout.fillHeight: true
            Layout.preferredWidth: Tokens.sizes.dashboard.mediaSectionWidth
            readonly property real diameter: Math.min(width - Tokens.padding.small, height - Tokens.padding.small, 320)

            MaterialShape {
                id: backdrop

                anchors.centerIn: parent
                implicitSize: dial.diameter - (root.activeTimer || root.timer.phase === "finished" ? 34 : 8)
                shape: root.timer.phase === "finished" ? MaterialShape.Sunny : MaterialShape.Cookie9Sided
                color: Colours.palette.m3surfaceContainerHigh
                opacity: 0.92
                rotation: -8
                Behavior on color { CAnim {} }
                Behavior on implicitSize { Anim {} }
            }

            FrameAnimation {
                running: root.visible && root.presented && root.timer.phase !== "paused"
                    && Tokens.anim.durations.scale > 0
                onTriggered: backdrop.rotation = (backdrop.rotation + Math.min(frameTime, 0.05) * 10 /
                    Tokens.anim.durations.scale) % 360
            }

            TimerRing {
                anchors.centerIn: parent
                width: dial.diameter
                height: width
                visible: opacity > 0
                opacity: root.activeTimer || root.timer.phase === "finished" ? 1 : 0
                progress: root.timer.progress
                moving: root.presented && root.timer.running
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timer.phase === "finished" ? "check" : root.timer.phase === "paused" ? "pause" : "timer"
                    color: Colours.palette.m3primary
                    fontStyle: root.activeTimer || root.timer.phase === "finished"
                        ? Tokens.font.icon.large : Tokens.font.icon.builders.large.scale(2.5).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.activeTimer || root.timer.phase === "finished"
                    text: root.timer.timeText
                    font: Qt.font({ family: Tokens.font.headline.large.family,
                        pixelSize: root.timer.timeText.length > 5 ? 42 : 54, weight: Font.Bold })
                    color: Colours.palette.m3secondary
                    Behavior on color { CAnim {} }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 310
            spacing: Tokens.spacing.large

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.sessionName
                    font: Tokens.font.title.large
                }

                StyledText {
                    text: root.timer.phase === "running" ? root.timer.tr("Counting down", "Идёт отсчёт") :
                        root.timer.phase === "paused" ? root.timer.tr("Paused", "На паузе") :
                        root.timer.phase === "finished" ? root.timer.tr("Time's up", "Время вышло") :
                        root.timer.tr("Ready when you are", "Можно начинать")
                    color: Colours.palette.m3secondary
                    font: Tokens.font.body.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.timer.tr("Duration", "Длительность")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                StyledTextField {
                    id: durationInput

                    objectName: "timerDuration"
                    Layout.fillWidth: true
                    type: StyledTextField.Filled
                    leadingIcon: "schedule"
                    trailingIcon: root.timer.editable ? "edit" : "lock"
                    placeholderText: ""
                    text: root.timer.durationText()
                    font: Tokens.font.headline.medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalPadding: Tokens.padding.medium
                    maximumLength: 8
                    readOnly: !root.timer.editable
                    inputMethodHints: Qt.ImhPreferNumbers
                    validate: text => root.timer.validDurationText(text)
                    emptyIsValid: false
                    errorText: root.timer.tr("Use mm:ss or hh:mm:ss · up to 24 h", "мм:сс или чч:мм:сс · до 24 ч")
                    Accessible.name: root.timer.tr("Timer duration", "Длительность таймера")

                    function commitValue(): bool {
                        if (!valid) {
                            isError = true;
                            return false;
                        }
                        root.timer.setDurationText(text);
                        text = root.timer.durationText();
                        isError = false;
                        return true;
                    }

                    onEditingFinished: commitValue()

                    Connections {
                        target: root.timer
                        function onStateChanged(): void {
                            if (!durationInput.activeFocus || !root.timer.editable) {
                                durationInput.text = root.timer.durationText();
                                durationInput.isError = false;
                            }
                        }
                    }
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "restart_alt"
                    type: IconButton.Tonal
                    disabled: !root.timer.ready || root.timer.phase === "idle"
                    onClicked: root.timer.reset()
                    Accessible.name: root.timer.tr("Reset timer", "Сбросить таймер")
                }

                IconTextButton {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    icon: root.timer.running ? "pause" : "play_arrow"
                    text: root.timer.running ? root.timer.tr("Pause", "Пауза") :
                        root.timer.phase === "paused" ? root.timer.tr("Resume", "Продолжить") : root.timer.tr("Start", "Начать")
                    font: Tokens.font.title.medium
                    disabled: !root.timer.ready || !durationInput.valid
                    onClicked: {
                        if (durationInput.commitValue())
                            root.timer.running ? root.timer.pause() : root.timer.start();
                    }
                }

                IconButton {
                    icon: root.timer.state.soundEnabled ? "volume_up" : "volume_off"
                    type: IconButton.Tonal
                    activeColour: Colours.palette.m3secondaryContainer
                    activeOnColour: Colours.palette.m3onSecondaryContainer
                    inactiveColour: Colours.palette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    isToggle: true
                    checked: root.timer.state.soundEnabled
                    onClicked: root.timer.setSound(!root.timer.state.soundEnabled)
                    Accessible.name: root.timer.tr("Sound", "Звук")
                }

                IconButton {
                    icon: root.timer.state.notificationsEnabled ? "notifications_active" : "notifications_off"
                    type: IconButton.Tonal
                    activeColour: Colours.palette.m3secondaryContainer
                    activeOnColour: Colours.palette.m3onSecondaryContainer
                    inactiveColour: Colours.palette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    isToggle: true
                    checked: root.timer.state.notificationsEnabled
                    onClicked: root.timer.setNotifications(!root.timer.state.notificationsEnabled)
                    Accessible.name: root.timer.tr("Notifications", "Уведомления")
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.timer.storageError.length > 0
                text: root.timer.storageError
                font: Tokens.font.body.small
                color: Colours.palette.m3error
                wrapMode: Text.Wrap
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 290
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: root.timer.tr("Presets", "Пресеты")
                    font: Tokens.font.title.medium
                }

                IconButton {
                    icon: root.editingPresets ? "check" : "tune"
                    type: IconButton.Text
                    disabled: !root.timer.ready
                    onClicked: {
                        forceActiveFocus();
                        root.editingPresets = !root.editingPresets;
                    }
                    Accessible.name: root.timer.tr("Edit presets", "Настроить пресеты")
                }
            }

            GridLayout {
                visible: !root.editingPresets
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Tokens.spacing.small
                rowSpacing: Tokens.spacing.small

                Repeater {
                    model: 4
                    delegate: PresetButton {
                        required property int index
                        Layout.fillWidth: true
                        Layout.minimumWidth: 100
                        label: root.timer.presetLabel(root.timer.state.presets[index].label)
                        minutes: root.timer.state.presets[index].seconds / 60
                        selected: root.timer.state.durationSeconds === root.timer.state.presets[index].seconds
                        disabled: !root.timer.editable
                        onClicked: {
                            durationInput.focus = false;
                            root.timer.setDuration(root.timer.state.presets[index].seconds);
                        }
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

                            objectName: "presetName" + presetRow.index
                            Layout.minimumWidth: 90
                            Layout.fillWidth: true
                            verticalPadding: Tokens.padding.medium
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
                            from: 1
                            to: 1440
                            stepSize: 1
                            sourceValue: Math.round(root.timer.state.presets[presetRow.index].seconds / 60)
                            onValueModified: root.timer.updatePreset(presetRow.index, presetName.text, Math.round(value) * 60)
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
        inactiveColour: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.82)
        activeOnColour: Colours.palette.m3onSecondaryContainer
        inactiveOnColour: Colours.palette.m3onSurface
        implicitWidth: 136
        implicitHeight: 98
        defaultRadius: Tokens.rounding.large
        horizontalPadding: Tokens.padding.medium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: Math.round(preset.minutes * 100) / 100
                    color: preset.disabled ? preset.disabledOnColour : preset.selected
                        ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3secondary
                    font: preset.minutes >= 1000 ? Tokens.font.title.large : Tokens.font.headline.small
                }

                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Tokens.padding.extraSmall
                    text: TimerService.tr("min", "мин")
                    color: preset.onColour
                    font: Tokens.font.body.small
                }

                Item { Layout.fillWidth: true }
            }

            StyledText {
                Layout.fillWidth: true
                text: preset.label
                color: preset.onColour
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }
    }
}
