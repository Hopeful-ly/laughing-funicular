import QtQuick
import QtQuick.Effects
import qs.services

// macOS "Liquid Glass" material. Real background blur comes from the
// Hyprland layer rule (see hypr/theme.lua); this draws tint, rim and sheen.
Item {
    id: g
    property real radius: Theme.radiusPanel
    property color tint: Theme.glass
    property bool shadow: true
    property real shadowStrength: 1
    property bool sheen: true
    property bool absorb: true          // swallow clicks so overlays don't close
    default property alias content: inner.data

    RectangularShadow {
        visible: g.shadow
        anchors.fill: bg
        offset.y: 8
        blur: 28
        spread: -4
        radius: g.radius
        color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.32 : 0.16) * g.shadowStrength)
    }

    // Hairline outline that separates glass from bright wallpapers.
    Rectangle {
        anchors.fill: bg
        anchors.margins: -1
        radius: g.radius + 1
        color: "transparent"
        border.width: 1
        border.color: Theme.outline
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: g.radius
        color: g.tint
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.55)

        // Specular sheen along the top edge.
        Rectangle {
            visible: g.sheen
            anchors.fill: parent
            anchors.margins: 1
            radius: g.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        // Brighter rim highlight on the top edge.
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - g.radius * 2
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Theme.rimTop }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: g.absorb
        acceptedButtons: Qt.AllButtons
        hoverEnabled: false
        onWheel: w => w.accepted = true
    }

    Item { id: inner; anchors.fill: parent }
}
