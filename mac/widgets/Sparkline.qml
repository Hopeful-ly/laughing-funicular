import QtQuick
import qs.services

// Filled line graph of 0..1 samples (newest on the right).
Canvas {
    id: c
    property var values: []
    property int capacity: 60
    property color color: Theme.accent
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (n < 2) return;
        const step = width / (capacity - 1);
        const x0 = width - (n - 1) * step;
        const y = v => height - 1 - v * (height - 2);
        ctx.beginPath();
        ctx.moveTo(x0, height);
        for (let i = 0; i < n; i++) ctx.lineTo(x0 + i * step, y(values[i]));
        ctx.lineTo(width, height);
        ctx.closePath();
        const g = ctx.createLinearGradient(0, 0, 0, height);
        g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.45));
        g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.02));
        ctx.fillStyle = g;
        ctx.fill();
        ctx.beginPath();
        for (let i = 0; i < n; i++) { const px = x0 + i * step, py = y(values[i]); if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py); }
        ctx.strokeStyle = color;
        ctx.lineWidth = 1.5;
        ctx.stroke();
    }
}
