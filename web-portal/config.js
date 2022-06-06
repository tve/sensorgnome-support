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

const config_html = Fs.readFileSync("public/config.html").toString()
const redirect_html = Fs.readFileSync("public/redirect.html").toString()
const redirecths_html = Fs.readFileSync("public/redirect-hs.html").toString()
const success_html = Fs.readFileSync("public/success.html").toString()
const top100k = Fs.readFileSync("top-100k-passwords.txt").toString().split('\n')
const sgid = Fs.readFileSync("/etc/sensorgnome/id").toString().trim()

//const dnsmasq_conf = "/etc/dnsmasq.d/wifi-button.conf"
const wifi_hotspot = "/opt/sensorgnome/wifi-button/scripts/wifi-hotspot.sh"
const deployment = "/etc/sensorgnome/deployment.json"

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

function check_pass(pwd) {

}

// respond using a string as a template and substituting fields <!--field--> from info.field
function respond(res, template, info) {
    info.ipaddrs = ifaces_list()
    info.sgid = "SG-"+sgid
    let html = template.replace(/<!--([a-z]+)-->/g, (m, p1) => info[p1]||"")
    html = html.replace(/\/\*([a-z]+)\*\//g, (m, p1) => info[p1]||"")
    res.end(html)
}

app.use(Morgan('tiny'))
app.use(BodyParser.urlencoded({extended: false}))

// get the config page with some placeholders filled in
app.get('/config', (req, res) => {
    if (!Fs.existsSync('public/need_init'))
        return respond(res, config_html,
            {message: "This Sensorgnome has already been initialized, use the std web UI to re-init"})
    respond(res, config_html, {})
})

app.post('/set-config', (req, res) => {
    if (!Fs.existsSync('public/need_init'))
        return respond(res, config_html,
            {message: "This Sensorgnome has already been initialized, use the std web UI to re-init"})
    //console.log("Body:", req.body)
    if (!(req.body.password?.length > 0 && req.body.short_name?.length > 0)) {
        return respond(res, config_html, {message: "Password and short-name required"})
    }
    let pw = req.body.password
    let sn = req.body.short_name
    if (pw.length < 8 || pw.length > 32)
        return respond(res, config_html, {message: "SG Password must be 8 to 32 characters long"})
    if (sn < 3 || sn > 20)
        return respond(res, config_html, {message: "Short-name must be 3 to 20 characters long"})
    if (!sn.match(/^[\u0000-\u0019\u0021-\uFFFF_0-9]+$/))
        return respond(res, config_html, {message: "Short-name must contain only letters, digits and underscore"})
    if (top100k.includes(pw))
        return respond(res, config_html, {message: "Please choose a less common Sensorgnome password :-)"})

    // figure out desired wifi
    let mode = "WPA-PSK"
    // if (req.body.wifi_mode == "wpa3open") mode = "OWE"
    // else if (req.body.wifi_mode == "wpa3sae") mode = "SAE"
    if (mode != "OWE") {
        let pw = req.body.password
        if (!(pw?.length > 0))
            return respond(res, config_html, {message: "Hot-Spot password required"})
        if (pw.length < 8 || pw.length > 32)
            return respond(res, config_html, {message: "Hot-Spot Password must be 8 to 32 characters long"})
        if (top100k.includes(pw))
            return respond(res, config_html, {message: "Please choose a less common Hot-Spot password :-)"})
    }

    try {
        CP.execFileSync(wifi_hotspot, ["mode", mode, pw||""])
    } catch(e) { console.log("Error setting WiFi mode:", e) }
    respond(res, config_html, {message: "Error setting WiFi mode"})

    // change the Sensorgnome password
    try {
        CP.execFileSync("/usr/sbin/chpasswd", { input: `pi:${pw}\n` })
    } catch(e) {
        return respond(res, config_html, {message: "Error changing password: " + e})
    }
    Fs.rmSync("public/need_init")

    // set the shortname
    if (!Fs.existsSync(deployment)) {
        try {
            Fs.writeFileSync(deployment, JSON.stringify({short_label: sn}))
            CP.execFileSync("systemctl", ["restart", "sg-control"]) // yuck...
        } catch(e) {
            return respond(res, config_html, {message: "Error changing password: " + e})
        }
    }        
    
    let ifaces = ifaces_list()
    respond(res, success_html, {shortname: sn})
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
