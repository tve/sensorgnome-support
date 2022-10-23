// hub-agent - simple log collector and remote execution agent
// Copyright ©2022 Thorsten von Eicken, see LICENSE

// this agent only uses modules built-into node.js, there is no npm install...

const https = require('https')
const http = require('http')
const fs = require('fs')
const process = require('process')
const Buffer = require('buffer').Buffer
const cp = require('child_process')
const stateFile = '/var/lib/sensorgnome/hub-agent.json'
const logPrefixes = ['syslog', 'sg-control', 'upgrade.log']
const sghub = "https://www.sensorgnome.net"
const sgmon = "http://localhost:8080/monitoring"
let period = 300 // starting period in seconds +/-60
const max_period = 3600 // period increases by 1.5x until max_period
const chunkSize = 128*1024 // upload at most this much per log file at a time

const sgid = fs.readFileSync('/etc/sensorgnome/id').toString().trim()
const sgkey = fs.readFileSync('/etc/default/telegraf').toString().
  replace(/.*SGKEY=([0-9a-f]+).*/s, '$1')
if (!sgid || !sgkey) {
  console.log("hub-agent: SGID or SGKEY not set, exiting")
  process.exit(1)
}

// async execFile
function execFile(cmd, args) {
  return new Promise((resolve, reject) => {
      cp.execFile(cmd, args, (code, stdout, stderr) => {
          //console.log(`Exec "${cmd} ${args.join(" ")}" -> code=${code} stdout=${stdout} stderr=${stderr}`)
          if (code || stderr)  reject(new Error(`${cmd} ${args.join(" ")} failed: ${stderr||code}`))
          else resolve(stdout)
      })
  })
}

// async sleep
function sleep(time) { return new Promise(resolve => setTimeout(resolve, time)) }

// async http request from https://medium.com/@gevorggalstyan/how-to-promisify-node-js-http-https-requests-76a5a58ed90c
function request(url, method='GET', options={}, postData) {
  const m = url.match(/^(https?):\/\/([^:/]+)(:[0-9]+)?(\/.*)$/)
  if (!m) throw new Error(`Invalid URL: ${url}`)
  const lib = m[1] == 'https' ? https : http
  const host = m[2]
  const port = m[3] ? m[3].substr(1) : (m[1] == 'https' ? 443 : 80)
  const path = m[4] || '/'
  const params = { method, host, port, path, ...options }

  return new Promise((resolve, reject) => {
    const req = lib.request(params, res => {
      const data = []
      res.on('data', chunk => { data.push(chunk) })
      res.on('end', () => {
        const body = Buffer.concat(data).toString()
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`HTTP status ${res.statusCode}: ${body.trim()}`))
        } else {
          resolve(body)
        }
      })
    })
    req.on('error', reject)
    if (postData) { req.write(postData) }
    req.end()
  })
}

class LogShipper {

  constructor () {
    // read state file - keeps track of what we've already read
    this.state = { logs: {} }
    try {
      const s = JSON.parse( fs.readFileSync(stateFile, { encoding: 'utf8' }) )
      if (s && s.logs) this.state = s
    } catch (e) { }
    console.log(`state: ${JSON.stringify(this.state)}`)
  }

  // get list of log files to process
  logFileList() {
    const logFiles = []
    const files = fs.readdirSync('/var/log')
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
  async sendData(file, reset, pos, len, data) {
    //console.log("Sending", len, "bytes to", sghub)
    const path = `/agent/logs?file=${file}&pos=${pos}&reset=${reset}`
    const options = {
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': len,
      },
      auth: `${sgid}:${sgkey}`,
    }
    try {
      return await request(sghub + path, 'POST', options, data)
    } catch (e) {
      console.log(`${file}: ${e}`)
      throw new Error("sendData failed")
    }
  }

  // process one log file
  async processFile(f) {
    const path = '/var/log/'+f
    const stat = fs.statSync(path)
    const size = stat.size
    if (!(f in this.state.logs)) this.state.logs[f] = {pos: 0}
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
    if (len < size-pos) console.log(`${f}: sending ${len} of ${size-pos} bytes`)
    else console.log(`${f}: sending ${len} bytes`)
    const fd = fs.openSync(path, 'r')
    const buf = Buffer.alloc(len)
    const rlen = fs.readSync(fd, buf, 0, len, pos)
    // send log file chunk
    await this.sendData(f, reset, pos, rlen, buf)
    this.state.logs[f].pos = pos + rlen
  }

  // process all log files
  async processAll() {
        const logFiles = this.logFileList()
    const now = (new Date()).toTimeString().replace(/ .*/, '')
    console.log(`${now}: Processing ${logFiles.length} log files`)
    //console.log(logFiles.join(', '))

    for (const f of logFiles) {
      await this.processFile(f)
    }
    fs.writeFileSync(stateFile, JSON.stringify(this.state))
  }
}

async function shipInfo() {
  try {
    // run collect.sh for general OS info
    let info = await execFile('/usr/bin/bash', ['collect.sh'])
    // query sg-control for its monitoring contribution
    try {
      const i = await request(sgmon)
      info += `\n\json: ${i}`
    } catch (e) {
      info += `\n\njson: { error: ${e.message} }`
      console.log('shipInfo: ' + e)
    }
    // send the data to the hub
    const options = {
      headers: {
        'Content-Type': 'application/text',
        'Content-Length': info.length,
      },
      auth: `${sgid}:${sgkey}`,
    }
    await request(sghub + `/agent/info`, 'POST', options, info)
  } catch (e) {
    console.log(`shipInfo: ${e}`)
    throw new Error("shipInfo failed")
  }
}

const shipper = new LogShipper()
async function doit() {
  while (true) {
    try { await shipInfo() } catch(e) {}
    try {
      await shipper.processAll()
    } catch (e) {
      console.log("Aborting", e)
    }
    const delay = period - 30 + Math.random()*60
    period = Math.min(max_period, period * 1.5)
    console.log("Sleeping", delay, "seconds")
    await sleep(delay*1000)
  }
}
doit().then(()=>{console.log("Done")})
