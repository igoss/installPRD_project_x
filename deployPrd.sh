#!/usr/bin/env bash

#Script installing environment and deploing project_x
#Use for CentOS
#After install:
# > #gunicorn --bind 0.0.0.0:8000 configuration.wsgi:application
# > systemctl status gunicorn

db_username=$1
db_password=$2
server_name=$3

if [ -z db_username ] && [ -z db_password ]; then
  echo 'enter username and password for db'
  exit
fi

if [ -z server_name ]; then
  echo 'enter server/domain name'
  exit
fi

#packages install
yes Y | sudo yum install epel-release
yes Y | sudo yum install gcc
yes Y | sudo yum install nginx

yes Y | sudo yum install postgresql-server
yes Y | sudo yum install postgresql-devel
yes Y | sudo yum install postgresql-contrib

yes Y | sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yes Y | sudo yum -y install python35u
yes Y | sudo yum -y install python35u-pip

#postgreSQL settings
sudo postgresql-setup initdb
sudo systemctl start postgresql

sudo sed -i "s/ident/md5/g" /var/lib/pgsql/data/pg_hba.conf

sudo systemctl restart postgresql
sudo systemctl enable postgresql

sudo -u postgres psql postgres -c "CREATE DATABASE project_x;"
sudo -u postgres psql postgres -c "CREATE USER $db_username WITH PASSWORD $db_password;"
sudo -u postgres psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE project_x TO $db_username;"

#init project
rm -rf $PWD/project_django && mkdir $PWD/project_django && cd "$_"
mkdir $PWD/venv_django

python3.5 -m venv $PWD/venv_django
source $PWD/venv_django/bin/activate

pip install django==1.9
pip install psycopg2==2.7.1
pip install django-ckeditor
pip install django-resized
pip install Pillow
pip install psycopg2
pip install gunicorn

#django
mkdir $PWD/app_django
django-admin startproject configuration $PWD/app_django && cd "$_"

cd $PWD/configuration
sed -i -e "s/sqlite3/postgresql_psycopg2/g" ./settings.py
sed -i -e "s/'NAME': os.path.join(BASE_DIR, 'db.postgresql_psycopg2'),/'NAME': 'django_db', 'USER': '$db_username', 'PASSWORD': '$db_password', 'HOST': 'localhost', 'PORT': '',/g" ./settings.py
sed -i -e "s/STATIC_URL = '\/static\/'/STATIC_URL = '\/static\/'; STATIC_ROOT = os.path.join(BASE_DIR, 'static\/'); MEDIA_ROOT = os.path.join(BASE_DIR, 'media'); MEDIA_URL = '\/media\/'; CKEDITOR_UPLOAD_PATH = 'uploads\/'/g" ./settings.py
sed -i -e "s/TIME_ZONE = 'UTC'/TIME_ZONE = 'Europe\/Moscow'; DATE_FORMAT = 'd E Y в G:i'/g" ./settings.py
sed -i -e "s/    'django.contrib.staticfiles',/    'django.contrib.staticfiles','project_x', 'ckeditor', 'ckeditor_uploader',/g" ./settings.py
rm -rf settings.py-e

rm -rf urls.py && touch urls.py
echo '# -*- coding: utf-8 -*-' >> urls.py
echo 'from django.contrib import admin' >> urls.py
echo 'from django.conf.urls import url, include' >> urls.py
echo '' >> urls.py
echo 'from django.conf import settings' >> urls.py
echo 'from django.conf.urls.static import static' >> urls.py
echo '' >> urls.py
echo 'urlpatterns = [' >> urls.py
echo '    url(r"^admin/", admin.site.urls),' >> urls.py
echo '    url(r"^ckeditor/", include("ckeditor_uploader.urls")),' >> urls.py
echo '    url(r"", include("project_x.urls")),' >> urls.py
echo '] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)' >> urls.py
echo '--> OK.'

cd .. && mkdir ./media ./media/tag_group_icons ./media/uploads

git init > /dev/null
git clone git@github.com:igoss/project_x.git
rm -rf .git
mkdir $PWD/project_x/migrations && touch $PWD/project_x/migrations/__init__.py

python manage.py makemigrations
python manage.py migrate

#make unicorn daemon
sudo rm -rf /etc/systemd/system/gunicorn.service
sudo touch /etc/systemd/system/gunicorn.service
sudo chmod 0777 /etc/systemd/system/gunicorn.service
sudo echo '[Unit]' >> /etc/systemd/system/gunicorn.service
sudo echo 'Description=gunicorn daemon' >> /etc/systemd/system/gunicorn.service
sudo echo 'After=network.target' >> /etc/systemd/system/gunicorn.service
sudo echo '[Service]' >> /etc/systemd/system/gunicorn.service
sudo echo 'User=root' >> /etc/systemd/system/gunicorn.service
sudo echo 'Group=root' >> /etc/systemd/system/gunicorn.service
sudo echo "WorkingDirectory=$PWD" >> /etc/systemd/system/gunicorn.service
sudo echo "ExecStart=$PWD/../venv_django/bin/gunicorn --workers 3 --bind unix:$PWD.sock configuration.wsgi:application" >> /etc/systemd/system/gunicorn.service
sudo echo '[Install]' >> /etc/systemd/system/gunicorn.service
sudo echo 'WantedBy=multi-user.target' >> /etc/systemd/system/gunicorn.service
sudo chmod 0644 /etc/systemd/system/gunicorn.service

# run daemon
sudo systemctl daemon-reload
sudo systemctl stop gunicorn
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# nginx settings
cd ../
sudo rm -rf /etc/nginx/nginx.conf
sudo touch /etc/nginx/nginx.conf
sudo chmod 0777 /etc/nginx/nginx.conf
sudo echo 'user  nginx;' >> /etc/nginx/nginx.conf
sudo echo 'worker_processes  1;' >> /etc/nginx/nginx.conf
sudo echo 'error_log  /var/log/nginx/error.log warn;' >> /etc/nginx/nginx.conf
sudo echo 'pid        /var/run/nginx.pid;' >> /etc/nginx/nginx.conf
sudo echo 'events {' >> /etc/nginx/nginx.conf
sudo echo '    worker_connections  1024;' >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo echo 'http {' >> /etc/nginx/nginx.conf
sudo echo '    include       /etc/nginx/mime.types;' >> /etc/nginx/nginx.conf
sudo echo '    default_type  application/octet-stream;' >> /etc/nginx/nginx.conf
sudo echo '    log_format  main  $remote_addr - $remote_user [$time_local] "$request"' >> /etc/nginx/nginx.conf
sudo echo '                      $status $body_bytes_sent "$http_referer"' >> /etc/nginx/nginx.conf
sudo echo '                      "$http_user_agent" "$http_x_forwarded_for";' >> /etc/nginx/nginx.conf
sudo echo '    access_log  /var/log/nginx/access.log  main;' >> /etc/nginx/nginx.conf
sudo echo '    sendfile        on;' >> /etc/nginx/nginx.conf
sudo echo '    #tcp_nopush     on;' >> /etc/nginx/nginx.conf
sudo echo '    keepalive_timeout  65;' >> /etc/nginx/nginx.conf
sudo echo '    #gzip  on;' >> /etc/nginx/nginx.conf
sudo echo '    include /etc/nginx/conf.d/*.conf;' >> /etc/nginx/nginx.conf
sudo echo 'server {' >> /etc/nginx/nginx.conf
sudo echo '    listen 80;' >> /etc/nginx/nginx.conf
sudo echo "    server_name $server_name;" >> /etc/nginx/nginx.conf
sudo echo '    location /static/ {' >> /etc/nginx/nginx.conf
sudo echo "        root $PWD/..;" >> /etc/nginx/nginx.conf
sudo echo '    }' >> /etc/nginx/nginx.conf
sudo echo '    location / {' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header Host $http_host;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Forwarded-Proto $scheme;' >> /etc/nginx/nginx.conf
sudo echo "        proxy_pass http://unix:$PWD/$project.sock;" >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo chmod 0644 /etc/nginx/nginx.conf

sudo usermod -a -G $USER nginx
chmod 710 /home/$USER

sudo service nginx restart
sudo systemctl enable nginx
