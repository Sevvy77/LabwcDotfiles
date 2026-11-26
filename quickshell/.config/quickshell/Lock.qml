// The lock screen (was gtklock), opened by Super+l:
//   quickshell ipc call lock lock
// It uses the ext-session-lock protocol, so labwc itself keeps the screen
// locked until the password is right: if the shell crashes or is killed,
// the screen stays locked (see the README for getting back in).
//
// The password is checked with PAM's "login" service, as gtklock's PAM file
// (auth include login) did, so it accepts whatever your login does.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    property string password: ""
    property bool checking: false
    property string message: ""
    property string pendingPassword: ""

    function lock() {
        password = ""
        message = ""
        sessionLock.locked = true
    }

    function submit() {
        if (checking || password.length === 0) return
        pendingPassword = password
        checking = true
        message = ""
        if (!pam.start()) {
            checking = false
            pendingPassword = ""
            message = "Couldn't start the password check"
        }
    }

    function respond() {
        if (checking && pam.active && pam.responseRequired && pendingPassword !== "") {
            pam.respond(pendingPassword)
            pendingPassword = ""
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return sessionLock.locked }
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: root.respond()
        onPamMessage: root.respond()
        onCompleted: result => {
            root.checking = false
            root.pendingPassword = ""
            root.password = ""
            if (result === PamResult.Success) {
                root.message = ""
                sessionLock.locked = false
            } else {
                root.message = "Wrong password"
            }
        }
        onError: error => {
            root.checking = false
            root.pendingPassword = ""
            root.password = ""
            root.message = "Couldn't check the password (" + PamError.toString(error) + ")"
        }
    }

    WlSessionLock {
        id: sessionLock

        // One per output.
        WlSessionLockSurface {
            id: surface
            color: Theme.solidBg

            Image {
                anchors.fill: parent
                source: "file://" + Theme.wallpaper
                fillMode: Image.PreserveAspectCrop   // like swaybg -m fill
                asynchronous: true
                cache: false
            }

            SystemClock {
                id: time
                precision: SystemClock.Minutes
            }

            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(time.date, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 72
                    font.weight: Font.Light
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    bottomPadding: 16
                    text: Qt.formatDate(time.date, "dddd d MMMM")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 18
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280
                    height: 38
                    radius: Theme.radius
                    color: Theme.panelBg
                    border.width: 1
                    border.color: root.message !== "" ? Theme.crimsonHot : Theme.crimson

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        enabled: !root.checking
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 15
                        clip: true
                        focus: true

                        // Every output's field shows the same text.
                        text: root.password
                        onTextEdited: {
                            root.password = text
                            if (root.message === "Wrong password") root.message = ""
                        }
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.password = ""

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: root.checking ? "Checking…" : "Password"
                            color: Theme.muted
                            font: field.font
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 20
                    text: root.message
                    color: Theme.match
                    font.family: Theme.font
                    font.pixelSize: 14
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }
            }

            // Clicking anywhere gives this output's field the keyboard.
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: field.forceActiveFocus()
            }

            Component.onCompleted: field.forceActiveFocus()
        }
    }
}
