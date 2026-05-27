```yml
services:
  # ---- Vancouver (BC) ----
  gluetun-bc:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-bc
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=Canada
      - SERVER_CITIES=Vancouver
      - TZ=America/Toronto
    ports:
      - "4001:3001"

  brave-bc:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-bc
    restart: unless-stopped
    network_mode: "service:gluetun-bc"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-bc-data:/config
    shm_size: "1gb"

  # ---- United Kingdom ----
  gluetun-uk:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-uk
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=United Kingdom
      - SERVER_CITIES=London
      - TZ=America/Toronto
    ports:
      - "4002:3001"

  brave-uk:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-uk
    restart: unless-stopped
    network_mode: "service:gluetun-uk"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-uk-data:/config
    shm_size: "1gb"

  # ---- India ----
  gluetun-in:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-in
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=India
      - SERVER_CITIES=Mumbai
      - TZ=America/Toronto
    ports:
      - "4003:3001"

  brave-in:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-in
    restart: unless-stopped
    network_mode: "service:gluetun-in"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-in-data:/config
    shm_size: "1gb"

  # ---- USA ----
  gluetun-us:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-us
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=United States
      - SERVER_CITIES=New York
      - TZ=America/Toronto
    ports:
      - "4004:3001"

  brave-us:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-us
    restart: unless-stopped
    network_mode: "service:gluetun-us"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-us-data:/config
    shm_size: "1gb"

  # ---- Hong Kong ----
  gluetun-hk:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-hk
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=Hong Kong
      - TZ=America/Toronto
    ports:
      - "4005:3001"

  brave-hk:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-hk
    restart: unless-stopped
    network_mode: "service:gluetun-hk"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-hk-data:/config
    shm_size: "1gb"

volumes:
  brave-bc-data:
  brave-uk-data:
  brave-in-data:
  brave-us-data:
  brave-hk-data:
```
