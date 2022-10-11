// hub-agent - simple log collector and remote execution agent
// Copyright ©2022 Thorsten von Eicken, see LICENSE

const https = require('https')
const fs = require('fs')
const process = require('process')
const Buffer = require('buffer').Buffer
const stateFile = '/data/hub-agent.json'
const logPrefixes = ['syslog', 'sg-control']
const sghub = "www.sensorgnome.net"
const period = 300 // in seconds +/-60

const sgid = fs.readFileSync('/etc/sensorgnome/id').toString().trim()
const sgkey = fs.readFileSync('/etc/default/telegraf').toString().
  replace(/.*SGKEY=([0-9a-f]+).*/s, '$1')
if (!sgid || !sgkey) {
  console.log("hub-agent: SGID or SGKEY not set, exiting")
  process.exit(1)
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
  sendData(file, reset, pos, len, data, cb) {
    //console.log("Sending", len, "bytes to", sghub)
    const options = {
      hostname: sghub,
      port: 443,
      path: `/agent/logs?file=${file}&pos=${pos}&reset=${reset}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': len,
      },
      auth: `${sgid}:${sgkey}`,
    }
    const req = https.request(options, res => {
      res.on('data', d => {
        process.stdout.write(d)
      })
      const ok = res.statusCode == 200 || res.statusCode == 204
      if (!ok) console.log(`${file} statusCode: ${res.statusCode}`)
      cb(ok)
    })
    req.on('error', error => {
      console.error(`${file}: ${error}`)
      cb(false)
    })
    req.write(data)
    req.end()
  }

  // process one log file
  // when done, call cb with true->success, false->failure
  processFile(f, cb) {
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
    if (pos == size) return cb(true)
    // read the file chunk
    const len = Math.min(size - pos, 16*1024)
    if (len < size-pos) console.log(`${f}: sending ${len} of ${size-pos} bytes`)
    else console.log(`${f}: sending ${len} bytes`)
    const fd = fs.openSync(path, 'r')
    const buf = Buffer.alloc(len)
    const rlen = fs.readSync(fd, buf, 0, len, pos)
    // send log file chunk
    this.sendData(f, reset, pos, rlen, buf, (result) => {
      if (result) {
        this.state.logs[f].pos = pos + rlen
        cb(true)
      } else {
        cb(false)
      }
    })
  }

  // process all log files
  processAll(cb) {
    
    const processOne = (cb) => {
      const f = logFiles.shift()
      if (!f) return cb(true)
      this.processFile(f, (result) => {
        if (result) processOne(cb)
        else cb(false)
      })
    }
    
    const logFiles = this.logFileList()
    const now = (new Date()).toTimeString().replace(/ .*/, '')
    console.log(`${now}: Processing ${logFiles.length} log files`)
    //console.log(logFiles.join(', '))

    processOne((result) => {
      if (result) {
        fs.writeFileSync(stateFile, JSON.stringify(this.state))
        console.log("Done")
      } else {
        console.log("Aborting")
      }
      cb()
    })
  }
  
}

const shipper = new LogShipper()
function doit() {
  shipper.processAll(() => {
    const delay = period - 30 + Math.random()*60
    setTimeout(doit, delay*1000)
  })
}
doit()
