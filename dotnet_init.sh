#!/bin/bash
# .Net app install
declare repo_version=$(if command -v lsb_release &> /dev/null; then lsb_release -r -s; else grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"'; fi)
wget https://packages.microsoft.com/config/ubuntu/$repo_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update &&   sudo apt-get install -y aspnetcore-runtime-8.0 nginx -qq
sudo mkdir /opt/TodoApp
sudo echo '
[Unit]
Description=Example .NET Web API App running on Ubuntu 22.04

[Service] 
WorkingDirectory=/opt/TodoApp
ExecStart=/usr/bin/dotnet /opt/TodoApp/TodoApp.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dotnet-TodoApp
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_NOLOGO=true
Environment=ASPNETCORE_URLS="http://*:5000" ' > /etc/systemd/system/TodoApp.service
sudo systemctl daemon-reload