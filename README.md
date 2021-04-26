# NKN

Script(s) to deploy mining nodes for the [New Kind of Network](https://nkn.org) (NKN)

  * `nkndeploy_raspi.sh`
    * I needed to add these three lines
      ```
      CapabilityBoundingSet=CAP_NET_BIND_SERVICE
      AmbientCapabilities=CAP_NET_BIND_SERVICE
      NoNewPrivileges=true
      ```
      to the `/etc/systemd/system/nkn-commercial.service` file under key `[Service]` in order for the certification to work and not throw `acme: error presenting token: could not start HTTP server for challenge: listen tcp :80: bind: permission denied`.
      
