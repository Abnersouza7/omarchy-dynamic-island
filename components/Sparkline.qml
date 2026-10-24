import QtQuick
import QtQuick.Shapes

// A history line with a faint fill under it. `values` are 0..1 unless `max`
// is given (network rates scale to their own peak).
Shape {
  id: line

  property var values: []
  property real max: 1
  property int slots: 60
  property color color: Theme.fg

  preferredRendererType: Shape.CurveRenderer

  readonly property var points: {
    var out = []
    var n = values.length
    var top = Math.max(max, 1e-9)
    for (var i = 0; i < n; i++)
      out.push(Qt.point(width * (slots - n + i) / Math.max(1, slots - 1),
                        height - 1 - (height - 2) * Math.min(1, values[i] / top)))
    return out
  }

  ShapePath {
    strokeWidth: 0
    strokeColor: "transparent"
    fillColor: Qt.rgba(line.color.r, line.color.g, line.color.b, 0.16)
    startX: line.points.length ? line.points[0].x : 0
    startY: line.height
    PathLine { x: line.points.length ? line.points[0].x : 0; y: line.points.length ? line.points[0].y : line.height }
    PathPolyline { path: line.points }
    PathLine { x: line.width; y: line.height }
  }
  ShapePath {
    strokeWidth: 1.5
    strokeColor: line.color
    fillColor: "transparent"
    joinStyle: ShapePath.RoundJoin
    capStyle: ShapePath.RoundCap
    PathPolyline { path: line.points }
  }
}
