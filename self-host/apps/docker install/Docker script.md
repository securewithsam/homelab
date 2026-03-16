```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker infra-admin
exit
su - infra-admin
sudo apt install docker-compose -y
```
