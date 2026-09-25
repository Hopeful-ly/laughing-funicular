import QtQuick
import qs.services

// Menu bar item with hover capsule.
Hoverable {
    id: b
    implicitHeight: 24
    radius: 7
    hoverColor: Theme.barHover
    pressColor: Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.24)
    activeColor: Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.2)
}
