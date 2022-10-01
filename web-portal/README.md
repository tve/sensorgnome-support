Sensorgnome Web Portal
=====================

The sensorgnome web portal implements the initial config and the http->https redirect.
Prerequisites:

- the DNS server must be configured to redirect a bunch of hostnames that are used for captive
  portal detection to the hotspot IP address (this is done in `wifi-button`)
- an iptables rule redirects any packet coming into the hotspot interface destined to port 80
  to local port 81 or 82 (this is done in `wifi-button` in the `wifi-hotspot` script)

Thereafter:

- Caddy listens on ports 80, 81, 82 and 443:
  - port 80: is redirected by Caddy to 443 by virtue of Caddy being configured to run HTTPS
  - port 81: receives connections to port 80 from ethernet and client wifi,
    it serves up a pretty basic "click here to redirect to HTTPS" page
  - port 82: receives connections to port 80 of the hotspot interface,
    it serves up a more involved redirect page that allows the captive portal stuff to be
    enabled/disabled
  - port 443: is configured to auto-issue self-signed certs 
- port 443 serves up local files (in the public subdir), or reverse-proxies to the config.js
  web app, or to the main sg-control web app
- if `public/need_init` exists, then / shows the initial config page, otherwise it reverse-proxies
  to sg-control 
- all `/init/*` paths are either served as files out of the public subdir or are reverse-proxied to
  the initial config app
- if `public/need_init` exists everything else errors, and if that file does not exist then
  everything else goes to the sg-control app
- in addition to all this, the issuance of TLS certs is gated on `init/ip-ok`, which is handled
  by the initial config app
- the `public/need_init` file is set before the initial config app starts and is deleted by the
  initial config app once a password is set.

A typical config flow using the hotspot is:

- the user joins the wifi, the user's device requests a connectivity check URL, that is redirected
  causing the user device to pop-up the browser so the user can log into the captive portal
- the `public/need_init` file exists, thus caddy serves up the `config.html` file
- the user fills out the form, which is posted to `https://192.168.7.2/init/set-config`, which
  is handled by the config app, which sets the password, deletes the `need_init` file, and
  redirects to `/`
- the browser requests `https://192.168.7.2/` which is not reverse-proxied to the sg-control
  app, which serves up the Sensorgnome web ui
