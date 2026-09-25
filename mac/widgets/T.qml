import QtQuick
import qs.services

// Text with system font defaults.
Text {
    font.family: Config.fontFamily
    font.pixelSize: 13
    color: Theme.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
