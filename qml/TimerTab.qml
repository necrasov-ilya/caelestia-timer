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
                property real elapsedSinceFrame: 0
                running: root.visible && root.presented && root.timer.phase !== "paused"
                    && Tokens.anim.durations.scale > 0
                onTriggered: {
                    elapsedSinceFrame += Math.min(frameTime, 0.05);
                    if (elapsedSinceFrame < 1 / 60)
                        return;
                    backdrop.rotation = (backdrop.rotation + elapsedSinceFrame * 10 / Tokens.anim.durations.scale) % 360;
                    elapsedSinceFrame = 0;
                }
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

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
            columns: 2
            columnSpacing: Tokens.spacing.extraLarge
            rowSpacing: Tokens.spacing.medium

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 310
                Layout.minimumWidth: actions.implicitWidth
                implicitHeight: Math.max(presetBody.implicitHeight, controlColumn.implicitHeight)

                ColumnLayout {
                    id: controlColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.medium

                    TextFieldBase {
                        id: durationInput

                        objectName: "timerDuration"
                        Layout.fillWidth: true
                        property bool isError: false
                        readonly property bool valid: root.timer.validDurationText(text)
                        readonly property string errorText: root.timer.tr("Use mm:ss or hh:mm:ss · up to 24 h", "мм:сс или чч:мм:сс · до 24 ч")
                        leftPadding: Tokens.padding.large * 2 + Tokens.padding.medium
                        rightPadding: leftPadding
                        topPadding: Tokens.padding.medium
                        bottomPadding: topPadding
                        text: root.timer.durationText()
                        font: Tokens.font.headline.medium
                        horizontalAlignment: Text.AlignHCenter
                        maximumLength: 8
                        readOnly: !root.timer.editable
                        inputMethodHints: Qt.ImhPreferNumbers
                        onTextEdited: isError = false

                        background: StyledRect {
                            radius: Tokens.rounding.large
                            color: durationInput.activeFocus ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh
                            border.width: durationInput.isError || durationInput.activeFocus ? 2 : 0
                            border.color: durationInput.isError ? Colours.palette.m3error : Colours.palette.m3primary
                        }

                        MaterialIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "schedule"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        MaterialIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.timer.editable ? "edit" : "lock"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }
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


                    RowLayout {
                        id: actions
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
                        visible: text.length > 0
                        text: root.timer.storageError || (durationInput.isError ? durationInput.errorText : "")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3error
                        wrapMode: Text.Wrap
                    }
                }
            }

            Item {
                id: presetBody

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 290
                implicitHeight: root.editingPresets ? presetEditor.implicitHeight : presetGrid.implicitHeight

                GridLayout {
                    id: presetGrid
                    visible: !root.editingPresets
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
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
                    id: presetEditor
                    visible: root.editingPresets
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
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
    }
    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.large
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.large
        icon: root.editingPresets ? "check" : "tune"
        type: IconButton.Text
        disabled: !root.timer.ready
        onClicked: {
            forceActiveFocus();
            root.editingPresets = !root.editingPresets;
        }
        Accessible.name: root.timer.tr("Edit presets", "Настроить пресеты")
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
