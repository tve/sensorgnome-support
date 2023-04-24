// web portal - "Simple" web portal implementing captive portal type of functionality to perform
// initial configuration of a sensorgnome. This is a node.js app.
// Copyright ©2022 Thorsten von Eicken, see LICENSE

const Fs = require('fs')
const OS = require('os')
const Express = require('express')
const BodyParser = require('body-parser')
const Morgan = require("morgan")  // request logger middleware
const app = Express()
const CP = require('child_process')
const crypto = require("crypto")

const config_html = Fs.readFileSync("public/config.html").toString()
const config2_html = Fs.readFileSync("public/config2.html").toString()
const redirect_html = Fs.readFileSync("public/redirect.html").toString()
const redirecths_html = Fs.readFileSync("public/redirect-hs.html").toString()
const success_html = Fs.readFileSync("public/success.html").toString()
const top100k = Fs.readFileSync("top-100k-passwords.txt").toString().split('\n')
const sgid = Fs.readFileSync("/etc/sensorgnome/id").toString().trim()

//const dnsmasq_conf = "/etc/dnsmasq.d/wifi-button.conf"
const wifi_hotspot = "/opt/sensorgnome/wifi-button/wifi-hotspot.sh"
const acquisition = "/etc/sensorgnome/acquisition.json"

// return list of interface ip addresses as HTML list
function ifaces_list() {
    let ifaces = ""
    const ifmap = { 'eth0': 'Ethernet', 'wlan0': 'WiFi Client', 'ap0': 'WiFi Hotspot' }
    for (let e of Object.entries(OS.networkInterfaces())) {
        let ifn = ifmap[e[0]] || e[0]
        for (let ifc of e[1]) {
            if (ifn !== 'lo' && ifc.family == 'IPv4') {
                let addr = ifc.address.replace(/\./g, '-') + ".my.local-ip.co"
                ifaces += `<li>${ifn}: <a href="https://${addr}/">https://${addr}/</a></li>\n`
            }
        }
    }
    return ifaces
}

// return true if captive portal is enabled
function cap_enabled() {
    try {
        let info = CP.execFileSync(wifi_hotspot, ["capinfo"])
        return info.toString().includes("on")
    } catch(e) { console.log("Error checking captive portal:", e) }
    return false
}

// check whether hotspot password is set
function hs_pw_set() {
    try {
        let info = CP.execFileSync(wifi_hotspot, ["pwinfo"])
        return info.toString().startsWith("set")
    } catch(e) { console.log("Error checking hostspot password:", e) }
    return false
}

// get user name given a user id
function get_user(id) {
    const pwdfile = Fs.readFileSync("/etc/passwd").toString()
    const username = new RegExp(`^([^:]+):[^:]*:${id}:`, 'm').exec(pwdfile)?.[1]
    console.log(username)
    if (!username) throw new Error(`User with id ${id} does not exist`)
    return username
}

// extract the password field from /etc/shadow for the specific user
function shadow_hash(user) {
     const data = Fs.readFileSync("/etc/shadow").toString()
     const lines = data.split('\n')
     const line = lines.find(l => l.startsWith(`${user}:`))
     if (!line) throw new Error(`User '${user}' does not exist`)
     const fields = line.split(':')
     if (fields.length < 2) throw new Error(`User '${user}' has no password`)
     const hash = fields[1]
     if (hash == '*') throw new Error(`User '${user}' has no password`)
     return hash
}

// use python's crypt function to verify the password,
// see https://www.baeldung.com/linux/shadow-passwords
function py_auth(user, pass) {
    const verifier = shadow_hash(user)
    const method_salt = verifier.replace(/\$[^$]+$/, '$')
    const args = ["-c", `import crypt; print(crypt.crypt("${pass}", "${method_salt}"))`]
    const stdout = CP.execFileSync("/usr/bin/python3", args).toString()
    if (stdout.trim() != verifier) throw new Error(`Wrong password for user '${user}'`)
    return true
}

// respond using a string as a template and substituting fields <!--field--> from info.field
function respond(res, template, info) {
    info.ipaddrs = ifaces_list()
    info.sgid = sgid
    let html = template.replace(/<!--([a-z]+)-->/g, (m, p1) => info[p1]||"")
    html = html.replace(/\/\*([a-z]+)\*\//g, (m, p1) => info[p1]||"")
    res.end(html)
}

app.use(Morgan('tiny'))
app.use(BodyParser.urlencoded({extended: false}))

// get the config page with some placeholders filled in
app.get('/config', (req, res) => {
    if (!Fs.existsSync('public/need_init')) {
        // nothing to config
        return respond(res, config_html,
            {message: "This Sensorgnome has already been initialized, use the std web UI to re-init"})
    }
    // password set, but not for hotspot, needs password check to set hotspot pw
    try {
        const user = get_user(1000)
        const verifier = shadow_hash(user)
        if (verifier?.length > 20) {
            // unit password set, just set hotspot pw
            return respond(res, config2_html, {})
        } else {
            // password not set, needs the full init
            return respond(res, config_html, {})
        }
    } catch(err) {
        return respond(res, config_html, {message: err.message})
    }
})

// set the full config: unix password, short name, wifi mode, wifi password
app.post('/set-config', (req, res) => {
    if (!Fs.existsSync('public/need_init'))
        return respond(res, config_html,
            {message: "This Sensorgnome has already been initialized, use the std web UI to re-init"})
    //console.log("Body:", req.body)
    if (!(req.body.password?.length > 0)) { // } && req.body.short_name?.length > 0)) {
        return respond(res, config_html, {message: "Password required"})
    }
    // let sn = req.body.short_name
    // if (sn < 3 || sn > 20)
    //     return respond(res, config_html, {message: "Short-name must be 3 to 20 characters long"})
    // if (!sn.match(/^[\u0000-\u0019\u0021-\uFFFF_0-9]+$/))
    //     return respond(res, config_html, {message: "Short-name must contain only letters, digits and underscore"})
    let pw = req.body.password
    if (pw.length < 8 || pw.length > 32)
        return respond(res, config_html, {message: "SG Password must be 8 to 32 characters long"})
    if (top100k.includes(pw))
        return respond(res, config_html, {message: "Please choose a less common Sensorgnome password :-)"})

    // figure out desired wifi
    let mode = "WPA-PSK"
    // if (req.body.wifi_mode == "wpa3open") mode = "OWE"
    // else if (req.body.wifi_mode == "wpa3sae") mode = "SAE"
    let wpw = ""
    if (mode != "OWE") {
        wpw = pw // req.body.wifi_pass
        if (!(wpw?.length > 0))
            return respond(res, config_html, {message: "Hot-Spot password required"})
        if (wpw.length < 8 || wpw.length > 32)
            return respond(res, config_html, {message: "Hot-Spot Password must be 8 to 32 characters long"})
        if (top100k.includes(wpw))
            return respond(res, config_html, {message: "Please choose a less common Hot-Spot password :-)"})
        wpw = crypto.pbkdf2Sync(wpw, sgid, 4096, 256 / 8, "sha1").toString("hex")
    }
    
    // change the Sensorgnome password
    try {
        const pwdfile = Fs.readFileSync("/etc/passwd").toString()
        const username = /^([^:]+):[^:]*:1000:/m.exec(pwdfile)?.[1] || "gnome"
        CP.execFileSync("/usr/sbin/chpasswd", { input: `${username}:${pw}\n` })
    } catch(e) {
        return respond(res, config_html, {message: "Error changing password: " + e})
    }
    Fs.rmSync("public/need_init")

    // set the shortname
    // try {
    //     let acq = Fs.readFileSync(acquisition, {encoding: 'utf8'})
    //     acq = acq.replace(/"label":\s*"[^"]*"/s, `"label": "${sn}"`)
    //     Fs.writeFileSync(acquisition, acq)
    //     CP.execFileSync("systemctl", ["restart", "sg-control"]) // yuck...
    //     CP.execFileSync("systemctl", ["restart", "sg-hub-agent"]) // yuck...
    // } catch(e) {
    //     return respond(res, config_html, {message: "Error changing short-name: " + e})
    // }

    // change the wifi async after a short delay so we can send a response back
    setTimeout(() => {
        try {
            CP.execFileSync(wifi_hotspot, ["mode", mode, wpw||""])
        } catch(e) {
            console.log("Error setting WiFi mode:", e)
            respond(res, config_html, {message: "Error setting WiFi mode"})
        }
    }, 5000)
    
    respond(res, success_html, {}) // {shortname: sn})
})

// check unix password and set hotspot password to the same value
app.post('/chk-config', (req, res) => {
    if (hs_pw_set())
        return respond(res, config2_html,
            {message: "This Sensorgnome has already been initialized, use the std web UI to re-init"})

    // check the password
    try {
        const user = get_user(1000)
        py_auth(user, req.body.password)
    } catch(err) {
        return respond(res, config2_html, {message: err.message})
    }

    // change the wifi async after a short delay so we can send a response back
    let mode = "WPA-PSK"
    const wpw = crypto.pbkdf2Sync(req.body.password, sgid, 4096, 256 / 8, "sha1").toString("hex")
    setTimeout(() => {
        try {
            CP.execFileSync(wifi_hotspot, ["mode", mode, wpw||""])
        } catch(e) {
            console.log("Error setting WiFi mode:", e)
            respond(res, config2_html, {message: "Error setting WiFi mode"})
        }
    }, 5000)
    Fs.rmSync("public/need_init")
    
    respond(res, success_html, {}) // {shortname: sn})
})

app.get('/redirect', (req, res) => {
    respond(res, redirect_html, {})
})

app.get('/redirect-hs', (req, res) => {
    respond(res, redirecths_html, { captive: cap_enabled() ? "on": "off" })
})

// endpoint used by caddy to query whether it's OK to issue an HTTPS cert for a given domain
app.get('/ip-ok', (req, res) => {
    try {
        let domain = req.query.domain.toString().toLowerCase()
        // allow sgpi.local
        if (domain === "sgpi.local") {
            console.log("ip-ok: approved sgpi.local")
            return res.end("OK")
        }
        // allow the IP addresses of our interfaces
        let ifaces = Object.values(OS.networkInterfaces()).flat()
        if (ifaces.find(iface => iface.family == "IPv4" && iface.address == domain)) {
            console.log("ip-ok: approved " + domain)
            return res.end("OK")
        }
    } catch(e) {}
    return res.sendStatus(400)
})

// endpoint used before the redirect to https to ensure that the rPi's time is half-way reasonable
// so the browser will accept the cert generated by caddy
app.post('/set-time', (req, res) => {
    try {
        let ts = parseInt(req.query["ts"].toString(), 10)
        let now = Date.now()
        if (ts && ts > now + 22*3600*1000) {
            console.log(`Setting time from ${now/1000} to ${ts/1000}`)
            CP.execFileSync("/bin/date", ["-u", "-s@" + (ts/1000)])
            return res.end("Time changed")
        } else {
            return res.end("Time was OK")
        }
    } catch(e) { console.log("Error in set-time:", e) }
    return res.sendStatus(400)
})

// endpoint used to enable/disable the captive portal
app.get('/captive', (req, res) => {
    try {
        CP.execFileSync(wifi_hotspot, [req.query["sw"] === "off" ? "capoff" : "capon"])
    } catch(e) { console.log("Error switching captive portal:", e) }
    respond(res, redirecths_html, { captive: cap_enabled() ? "on": "off" })    
})

app.listen(8081, 'localhost', () => {
    console.log("Sensorgnome Initial Config listening on port 8081")
})
