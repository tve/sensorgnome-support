Sensorgnome SSH tunnel
======================

Maintain an SSH tunnel to sensorgnome.org to send data as well as status info:
- sg-register performs initial registration to get an SSH key and a tunnel port
- ssh-tunnel opens the SSH tunnel and keeps it going

Dev notes
---------
(See also top-level README.)

The `sg-ssh-tunnel.deb` package can be installed and tested on a vanilla rPi with the following
considerations:
- the `sg-boot` service is a prereq
