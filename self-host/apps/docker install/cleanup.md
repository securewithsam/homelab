
```bash
sudo docker ps
```
```bash
sudo docker stop a609bf88ce48d e0323a1811e1 4e61287b9942 7aea2ac10795
sudo docker rm 609bf88ce48d e0323a1811e1 4e61287b9942 7aea2ac10795
sudo docker rmi 609bf88ce48d e0323a1811e1 4e61287b9942 7aea2ac10795
```
```bash
sudo docker system prune -a --volumes -f
```
## or
### cd into the specific app folder

```bash
docker compose down -v
sudo docker system prune -a --volumes -f
```

### Safely Remove stopped containers and unused networks.
```sh
docker system df
docker system prune -f
docker image prune -a -f
docker builder prune -a -f
```
