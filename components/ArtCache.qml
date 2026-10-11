pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Artwork is never decoded in the shell as it comes. Album art from media
// players (and images on the shelf) can be anything: a tiny progressive
// JPEG declaring 30000x30000 pixels makes Qt allocate for every coefficient
// whatever sourceSize says, and the whole shell goes with it.
// bin/dynamic-island-art reads the original in its own process, under
// limits, and writes a 256px PNG; only that PNG reaches an Image.
//
//   ArtCache.request(url)          start (once per URL)
//   ArtCache.lookup(url, revision) the safe file:// URL, or "" for none yet
Singleton {
  id: cache

  readonly property string helper: {
    var u = String(Qt.resolvedUrl("../bin/dynamic-island-art"))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
  }

  // url -> safe URL ("" when the helper refused it). Bumped on every result
  // so bindings that pass it to lookup() re-evaluate.
  property var results: ({})
  property int revision: 0
  property var order: []       // oldest first, to keep the map small
  readonly property int keep: 64

  property var queue: []
  property string current: ""   // the URL the helper is working on
  property bool busy: false

  function lookup(url, rev) {
    return url && results.hasOwnProperty(url) ? results[url] : ""
  }

  function request(url) {
    if (!url || results.hasOwnProperty(url) || (busy && url === current) || queue.indexOf(url) !== -1) return
    queue.push(url)
    next()
  }

  function next() {
    if (busy || proc.running || !queue.length) return
    busy = true
    current = queue.shift()
    proc.stdinEnabled = true
    proc.running = true
  }

  function store(url, safe) {
    results[url] = safe
    order.push(url)
    while (order.length > keep) delete results[order.shift()]
    revision++
  }

  Process {
    id: proc
    command: [cache.helper]
    // The URL goes over stdin, not as an argument (arguments are visible to
    // other users, and say what is playing).
    onStarted: { write(cache.current + "\n"); stdinEnabled = false }
    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.slice(0, 4096).split("\n")[0]
        cache.store(cache.current, line.indexOf("file:///") === 0 && /\/dynamic-island\/art\/[0-9a-f]{32}\.png$/.test(line) ? line : "")
        cache.busy = false
        Qt.callLater(cache.next)
      }
    }
    onExited: Qt.callLater(cache.next)
  }
}
