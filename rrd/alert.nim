import common, osproc, os, json, strutils

proc get(file, value, time: string): float =
  let (output, errorCode) = execCmdEx(rrdtool & " graph x -s -" & time & " DEF:v=" & file & ":" & value & ":AVERAGE VDEF:vm=v,AVERAGE PRINT:vm:%lf")

  if errorCode != 0:
    raise newException(ValueError, "Error code " & $errorCode & " from rrdtool: " & output)

  result = output.splitLines[^2].parseFloat

if paramCount() != 1:
  echo "alert [1d|7d|49d]"
  quit 1

let statsJson = parseFile statsJsonFile
for server in statsJson["servers"]:
  let
    domain = server["type"].str
    name = server["name"].str
    fileNet = (rrdDir / domain) & "-net.rrd"
    fileCpu = (rrdDir / domain) & "-cpu.rrd"
    fileMem = (rrdDir / domain) & "-mem.rrd"

  template alert(s: string) = echo name, " ", s

  case paramStr(1)
  of "1d":
    if fileNet.get("network_rx", "3min") + fileNet.get("network_tx", "3min") > 2_000_000:
      alert "network traffic over 2 MB/s for 3 min"

    if fileMem.get("memory_used", "3min") + fileMem.get("swap_used", "3min") > 0.9 * (fileMem.get("memory_total", "3min") + fileMem.get("swap_total", "3min")):
      alert "memory and swap over 90% for 3 min"

  of "7d":
    if fileCpu.get("cpu", "21min") > 90.0:
      alert "CPU over 90% for 21 min"
    if fileCpu.get("load", "21min") > 10.0:
      alert "Load over 10 for 21 min"

  of "49d":
    let network_rx = fileNet.get("network_rx", "4410")
    if network_rx != network_rx: # NaN
      alert "unreachable for 1 hour"

  else:
    echo "unknown parameter ", paramStr(1)
    quit 1