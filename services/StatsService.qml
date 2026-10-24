import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, network and disk, sampled every two seconds from /proc (read
// in-process, no subprocess) so the stats page opens onto a graph that
// already has history. `top(kind)` lists the apps using the most CPU or
// memory, every process of an app (browser tabs, Electron helpers) counted
// together.
Item {
  id: stats

  readonly property int samples: 60
  property real cpu: 0                 // 0..1 of the whole machine
  property real mem: 0                 // 0..1
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real rx: 0                  // bytes/s
  property real tx: 0
  property real disk: 0                // 0..1 of /
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property var cpuHistory: []
  property var memHistory: []
  property var netHistory: []          // rx + tx
  property var topList: []             // [{ name, value }]
  property string topKind: ""          // "cpu" | "mem" while a list is loading/shown

  property var lastCpu: null
  property var lastNet: null
  property double lastAt: 0

  function push(list, v) {
    var out = list.concat([v])
    return out.length > samples ? out.slice(out.length - samples) : out
  }

  function rate(bytes) {
    if (bytes < 1024) return Math.round(bytes) + " B/s"
    if (bytes < 1048576) return (bytes / 1024).toFixed(bytes < 10240 ? 1 : 0) + " KB/s"
    return (bytes / 1048576).toFixed(1) + " MB/s"
  }

  FileView { id: procStat; path: "/proc/stat"; printErrors: false; blockLoading: true }
  FileView { id: procMem; path: "/proc/meminfo"; printErrors: false; blockLoading: true }
  FileView { id: procNet; path: "/proc/net/dev"; printErrors: false; blockLoading: true }

  function sample() {
    procStat.reload(); procMem.reload(); procNet.reload()
    var now = Date.now()

    var f = String(procStat.text()).split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
    if (f.length >= 4) {
      var idle = f[3] + (f[4] || 0)
      var total = f.reduce((a, b) => a + b, 0)
      if (lastCpu && total > lastCpu.total) cpu = 1 - (idle - lastCpu.idle) / (total - lastCpu.total)
      lastCpu = { idle: idle, total: total }
    }

    var m = String(procMem.text())
    var kb = k => { var r = new RegExp("^" + k + ":\\s+(\\d+)", "m").exec(m); return r ? Number(r[1]) : 0 }
    var memTotal = kb("MemTotal"), memAvail = kb("MemAvailable")
    if (memTotal > 0) {
      mem = 1 - memAvail / memTotal
      memTotalGb = memTotal / 1048576
      memUsedGb = (memTotal - memAvail) / 1048576
    }

    var rxb = 0, txb = 0
    var lines = String(procNet.text()).split("\n").slice(2)
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].trim().split(/[:\s]+/)
      if (p.length < 10 || p[0] === "lo") continue
      rxb += Number(p[1]); txb += Number(p[9])
    }
    if (lastNet && now > lastAt) {
      var dt = (now - lastAt) / 1000
      rx = Math.max(0, (rxb - lastNet.rx) / dt)
      tx = Math.max(0, (txb - lastNet.tx) / dt)
    }
    lastNet = { rx: rxb, tx: txb }
    lastAt = now

    cpuHistory = push(cpuHistory, cpu)
    memHistory = push(memHistory, mem)
    netHistory = push(netHistory, rx + tx)
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: stats.sample()
  }

  Process {
    id: df
    command: ["df", "-B1", "--output=used,size", "/"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.trim().split("\n").pop().trim().split(/\s+/).map(Number)
        if (p.length === 2 && p[1] > 0) {
          stats.disk = p[0] / p[1]
          stats.diskUsedGb = p[0] / 1073741824
          stats.diskTotalGb = p[1] / 1073741824
        }
      }
    }
  }
  Timer {
    interval: 60000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: df.running = true
  }

  // CPU as measured over the last second (top's second pass), not ps's
  // lifetime average; memory as resident size now.
  Process {
    id: topProc
    stdout: StdioCollector {
      onStreamFinished: {
        var sums = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab < 0) continue
          var name = lines[i].substring(0, tab).trim(), v = Number(lines[i].substring(tab + 1))
          if (!name || isNaN(v)) continue
          sums[name] = (sums[name] || 0) + v
        }
        var out = Object.keys(sums).map(k => ({ name: k, value: sums[k] }))
        out.sort((a, b) => b.value - a.value)
        stats.topList = out.slice(0, 6)
      }
    }
  }
  function top(kind) {
    topKind = kind
    topList = []
    topProc.command = kind === "cpu"
      // Per-process %CPU is of one core; divide by the core count for "of the machine".
      ? ["sh", "-c", "n=$(nproc); top -b -n 2 -d 1 -w 512 | awk -v n=\"$n\" '/^ *PID/{p++; next} p==2 && NF>=12 {s=$12; for (i=13; i<=NF; i++) s=s \" \" $i; print s \"\\t\" $9/n}'"]
      : ["sh", "-c", "ps -eo rss=,comm= | awk '{s=$2; for (i=3; i<=NF; i++) s=s \" \" $i; print s \"\\t\" $1/1048576}'"]
    topProc.running = true
  }
}
