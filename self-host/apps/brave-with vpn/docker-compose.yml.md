```yml
services:
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=your-private-key-here
      - SERVER_COUNTRIES=Canada
      - SERVER_CITIES=Vancouver
      - TZ=America/Toronto
    ports:
      - "3009:3001"

  brave:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-bc
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-bc-data:/config
    shm_size: "1gb"

volumes:
  brave-bc-data:

  ```
