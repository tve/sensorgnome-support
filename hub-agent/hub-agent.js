// hub-agent - simple log collector and remote execution agent
// Copyright ©2022 Thorsten von Eicken, see LICENSE

// this agent only uses modules built-into node.js, there is no npm install...

const http2 = require("http2")
const http = require("http")
const fs = require("fs")
const process = require("process")
const Buffer = require("buffer").Buffer
const cp = require("child_process")
const zlib = require("zlib")

const stateFile = "/var/lib/sensorgnome/hub-agent.json"
const logPrefixes = ["syslog", "sg-control", "upgrade.log"]
const keyFile = "/etc/sensorgnome/local-ip.key"
const certFile = "/etc/sensorgnome/local-ip.pem"
const sghub = "https://www.sensorgnome.net"
const sgmon = "http://localhost:8080/monitoring"
const min_period = 120 // minimum period in seconds +/-60
let period = min_period
const max_period = 3600 // period increases by 1.5x until max_period
const chunkSize = 128 * 1024 // upload at most this much per log file at a time
const connCheck = "/opt/sensorgnome/cellular/check-modem.sh"
const remote = "/etc/sensorgnome/remote.json"

const sgid = fs.readFileSync("/etc/sensorgnome/id").toString().trim()
const sgkey = fs
  .readFileSync("/etc/default/telegraf")
  .toString()
  .replace(/.*SGKEY=([0-9a-f]+).*/s, "$1")
if (!sgid || !sgkey) {
  console.log("hub-agent: SGID or SGKEY not set, exiting")
  process.exit(1)
}
console.log("hub-agent starting for: SGID", sgid, "SGKEY", sgkey)

// ensure the remote management config file exists
if (!fs.existsSync(remote)) {
  try {
    fs.writeFileSync(remote, JSON.stringify({ commands: true, webui: true, support: 0 }))
  } catch (err) {
    console.log("failed to create remote.json:", err)
  }
}

// async execFile
function execFile(cmd, args) {
  return new Promise((resolve, reject) => {
    cp.execFile(cmd, args, (code, stdout, stderr) => {
      //console.log(`Exec "${cmd} ${args.join(" ")}" -> code=${code} stdout=${stdout} stderr=${stderr}`)
      let txt = stdout ? stdout.trim()+'\n' : ''
      txt += stderr && `--- Stderr:\n${stderr}`
      if (code) reject(new Error(`Command "${cmd} ${args.join(" ")}" failed:\n${txt}`))
      else resolve(txt)
    })
  })
}

// async sleep
function sleep(time) {
  return new Promise(resolve => setTimeout(resolve, time))
}

let clients = {}

// async http2 request
function request(url, method = "GET", options = {}, postData) {
  const m = url.match(/^(https?:\/\/[^/]+)(\/.*)$/)
  if (!m) throw new Error(`Invalid URL: ${url}`)

  const hostport = m[1]
  const path = m[2] || "/"

  return new Promise((resolve, reject) => {
    // establish a connection (client)
    let client = clients[hostport]
    if (!client) {
      try {
        client = http2.connect(hostport)
        clients[hostport] = client
        console.log("Opened client for ", hostport)
      } catch (err) {
        console.log(`http2 connect error: ${err}`)
        delete clients[hostport]
        reject(err)
      }
      client.on("error", err => {
        console.log(`http2 client error: ${err}`)
        delete clients[hostport]
        reject(err)
      })
    }

    // send the request
    let headers = options?.headers || {}
    Object.assign(headers, {
      ":method": method,
      ":path": path,
    })
    if (options.auth) {
      Object.assign(headers, {
        Authorization: "Basic " + Buffer.from(options.auth).toString("base64")
      })
    }
    //console.log("Headers: ", JSON.stringify(headers))
    const req = client.request(headers)
    req.on("error", err => {
      console.log(`http2 request error: ${err}`)
      delete clients[hostport]
      reject(err)
    })
    req.on("response", headers => {
      const status = headers[":status"]
      const data = []
      req.on("data", chunk => {
        data.push(chunk)
      })
      req.on("end", () => {
        const body = Buffer.concat(data).toString()
        if (status < 200 || status >= 300) {
          reject(new Error(`HTTP status ${status}: ${body.trim()}`))
        } else {
          resolve(body)
        }
      })
    })
    if (postData) req.write(postData)
    req.end()
  })
}

function close_clients() {
  for (const hostport in clients) {
    console.log("Closing client for ", hostport)
    clients[hostport].close()
    delete clients[hostport]
  }
}

// async http 1.1 request from
// https://medium.com/@gevorggalstyan/how-to-promisify-node-js-http-https-requests-76a5a58ed90c
function request1(url, method = "GET", options = {}, postData) {
  const m = url.match(/^(https?):\/\/([^:/]+)(:[0-9]+)?(\/.*)$/)
  if (!m) throw new Error(`Invalid URL: ${url}`)
  const lib = m[1] == "https" ? https : http
  const host = m[2]
  const port = m[3] ? m[3].substr(1) : m[1] == "https" ? 443 : 80
  const path = m[4] || "/"
  const params = { method, host, port, path, ...options }

  return new Promise((resolve, reject) => {
    const req = lib.request(params, res => {
      const data = []
      res.on("data", chunk => {
        data.push(chunk)
      })
      res.on("end", () => {
        const body = Buffer.concat(data).toString()
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`HTTP status ${res.statusCode}: ${body.trim()}`))
        } else {
          resolve(body)
        }
      })
    })
    req.on("error", reject)
    if (postData) {
      req.write(postData)
    }
    req.end()
  })
}

class LogShipper {
  constructor() {
    // read state file - keeps track of what we've already read
    this.state = { logs: {} }
    try {
      const s = JSON.parse(fs.readFileSync(stateFile, { encoding: "utf8" }))
      if (s && s.logs) this.state = s
    } catch (e) {}
    //console.log(`state: ${JSON.stringify(this.state)}`)
  }

  // get list of log files to process
  logFileList() {
    const logFiles = []
    const files = fs.readdirSync("/var/log")
    for (const f of files) {
      for (const p of logPrefixes) {
        if (f.startsWith(p)) {
          logFiles.push(f)
          break
        }
      }
    }
    return logFiles
  }

  // perform an http request to send data to sghub
  // when done, calls cb with true->success, false->failure
  async sendData(file, reset, pos, data) {
    //console.log("Sending", len, "bytes to", sghub)
    const path = `/agent/logs?file=${file}&pos=${pos}&reset=${reset}`
    const gzip = !file.endsWith(".gz")
    if (gzip) data = zlib.gzipSync(data)
    const options = {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Length": data.length,
      },
      auth: `${sgid}:${sgkey}`,
    }
    if (gzip) options.headers["Content-Encoding"] = "gzip"
    try {
      return await request(sghub + path, "POST", options, data)
    } catch (e) {
      console.log(`${file}: ${e}`)
      throw new Error("sendData failed")
    }
  }

  // process one log file
  async processFile(f) {
    const path = "/var/log/" + f
    const stat = fs.statSync(path)
    const size = stat.size
    if (!(f in this.state.logs)) this.state.logs[f] = { pos: 0 }
    let pos = this.state.logs[f].pos
    let reset = false
    // handle log file reset
    if (pos > size) {
      console.log(`${f}: reset from ${pos} to ${size} bytes`)
      pos = this.state.logs[f].pos = 0
      reset = true
    }
    if (pos == size) return
    // read the file chunk
    const len = Math.min(size - pos, chunkSize)
    if (len < size - pos) console.log(`${f}: sending ${len} of ${size - pos} bytes`)
    else console.log(`${f}: sending ${len} bytes`)
    const fd = fs.openSync(path, "r")
    const buf = Buffer.alloc(len)
    const rlen = fs.readSync(fd, buf, 0, len, pos)
    // send log file chunk
    await this.sendData(f, reset, pos, buf)
    this.state.logs[f].pos = pos + rlen
  }

  // process all log files
  async processAll() {
    const logFiles = this.logFileList()
    const now = new Date().toISOString()
    console.log(`${now}: Processing ${logFiles.length} log files`)
    //console.log(logFiles.join(', '))

    for (const f of logFiles) {
      await this.processFile(f)
    }
    fs.writeFileSync(stateFile, JSON.stringify(this.state))
  }
}

function remoteFeatures() {
  try {
    const r = JSON.parse(fs.readFileSync(remote)) || {}
    let f = ""
    if (r.commands) f += 'c'
    if (r.webui) f += 'w'
    if (r.support) f += 's'
    console.log(`Remote features: ${f}`)
    return f
  } catch (e) {
    console.log("failed to read remote features config: " + e)
    return ""
  }
}

// run collect.sh to collect information about the system, post it to the server, and return
// any response received (may include a command to execute)
async function shipInfo() {
  // run collect.sh for general OS info
  let info = await execFile("/usr/bin/bash", ["collect.sh"])
  // query sg-control for its monitoring contribution
  try {
    const i = await request1(sgmon)
    info += `\n\json: ${i}`
  } catch (e) {
    info += `\n\njson: { "error": "${e.message.replace(/"/g, '"')}" }`
    console.log("shipInfo: " + e)
  }
  // get current remote management
  // send the data to the hub
  const gzinfo = zlib.gzipSync(info)
  const options = {
    headers: {
      "Content-Type": "application/octet-stream",
      "Content-Length": gzinfo.length,
      "Content-Encoding": "gzip",
    },
    auth: `${sgid}:${sgkey}`,
  }
  const f = remoteFeatures()
  // f=feature flags, c=cmds, w=webui, s=support
  return await request(sghub + `/agent/info?features=${f}`, "POST", options, gzinfo)
}

async function checkCerts() {
  try {
    const opts = { auth: `${sgid}:${sgkey}` }
    const serverMD5 = (await request(sghub + "/agent/tls-key-md5", "GET", opts)).trim()
    const localMD5 = (await execFile("/usr/bin/md5sum", [keyFile])).replace(/ .*/, "").trim()
    if (serverMD5 == localMD5) return
    console.log("Updating TLS cert & key")
    const cert = await request(sghub + "/agent/tls-cert", "GET", opts)
    const key = await request(sghub + "/agent/tls-key", "GET", opts)
    fs.writeFileSync(certFile, cert)
    fs.writeFileSync(keyFile, key)
    await execFile("systemctl", ["reload", "caddy.service"])
  } catch (e) {
    console.log(`checkCerts: ${e}`)
  }
}

async function logcmd(seq, status, output) {
  try {
    const opts = { auth: `${sgid}:${sgkey}` }
    let gzout = undefined
    opts.headers = { "Content-Type": "application/octet-stream" }
    if (output) {
      if (output.length > 1024*1024) output = output.substring(0, 1024*1024) + "\n...\n"
      gzout = zlib.gzipSync(output)
      opts.headers["Content-Length"] = gzout.length
      opts.headers["Content-Encoding"] = "gzip"
    }
    await request(sghub + `/agent/cmdlog?seq=${seq}&status=${status}`, "POST", opts, gzout)
  } catch (e) {
    console.log(`logcmd post result: ${e}`)
  }
}

// run a commandline and send stdout/stderr back to the server
async function runcmd(seq, cmdline) {
  let status = "OK"
  let stdout
  try {
    stdout = await execFile("/usr/bin/bash", ["-c", cmdline])
  } catch (e) {
    console.log(`runcmd: ${e}`)
    status = "ERR"
    stdout = e.message
  }
  logcmd(seq, status, stdout)
}

// perform a command action requested by the server
async function doCommand(cmd) {
  const f = remoteFeatures()
  if (!f.includes('c')) {
    console.log(`Ignoring command '${cmd.action}' because remote commands are disabled`)
    logcmd(cmd.seq, "ERR", `Remote commands are disabled`)
    return
  }
  switch (cmd.action) {
    case "exec":
      console.log("Executing:", cmd.cmdline)
      await runcmd(cmd.seq, cmd.cmdline)
      break
    case "reboot":
      console.log("Performing reboot command")
      runcmd(cmd.seq, "/usr/sbin/shutdown -r +1") // ensure it happens soonish
      await execFile("/usr/sbin/shutdown", ["-r", "now"]) // don't wait longer
      break
    case "restart":
      console.log("Performing restart sg-control command")
      await runcmd(cmd.seq, "/usr/bin/systemctl restart sg-control")
      break
    case "test":
      console.log("Performing test command")
      await runcmd(cmd.seq, "/usr/bin/uptime")
      break
    case "hotspot":
      console.log(`Performing hotspot '${cmd.state}' command`)
      if (["on", "off"].includes(cmd.state)) {
        await runcmd(cmd.seq, `/opt/sensorgnome/wifi-button/wifi-hotspot.sh ${cmd.state}`)
      }
      break
    default:
      console.log("Unknown command:", cmd.action)
      logcmd(cmd.seq, "ERR", `Unknown command: ${cmd.action}`)
      break
  }
}

async function updateTunnel(tunnel) {}

const shipper = new LogShipper()

let failed = 0 // number of consecutive failed uploads

async function doit() {
  if (process.env.NOTIFY_SOCKET) await execFile("systemd-notify", ["--ready"])
  while (true) {
    try {
      // first ship the info
      const resp = await shipInfo()
      failed = 0
      // check whether we have some commands to execute
      if (resp && resp.length > 0 && resp.startsWith("{")) {
        const ctrl = JSON.parse(resp)
        if ("tunnel" in ctrl) await updateTunnel(ctrl.tunnel)
        if ("cmd" in ctrl) {
          await doCommand(ctrl.cmd)
          period = min_period
        }
      }
      // then ship log files
      await shipper.processAll()
    } catch (e) {
      failed++
      console.log(`Aborting: ${e.message}`)
    }
    // check whether there are new certs available
    await checkCerts()

    // notify systemd that we're alive
    if (process.env.NOTIFY_SOCKET) await execFile("systemd-notify", ["WATCHDOG=1"])
    
    // calculate the delay 'til the next iteration
    const delay = period - 30 + Math.random() * 60
    period = Math.min(max_period, period * 1.5)

    try {
      await request(sghub + `/agent/next?delay=${delay}`, "POST", { auth: `${sgid}:${sgkey}` })
    } catch (e) {}
    
    close_clients()

    console.log("Sleeping", delay, "seconds")
    await sleep(delay * 1000)
  }
}

doit().then(() => {
  console.log("Done")
})
