#!/usr/bin/env bash

#Script installing environment and deploing backend and frontend
#Use for CentOS
#After install:
# > #gunicorn --bind 0.0.0.0:8000 configuration.wsgi:application
# > systemctl status gunicorn

db_username=$1
db_password=$2
server_name=$3

frontend_project=$4
frontend_branch=$5
backend_branch=$6

if [ -z $db_username ] && [ -z $db_password ]; then
  echo 'ERROR: input username and password for db - 1st\2nd param'
  exit
fi

if [ -z $server_name ]; then
  echo 'ERROR: input server/domain name - 3rd param'
  exit
fi

if [ -z $frontend_project == 'master' ]; then
  echo 'ERROR: input forntend project - 4th param'
  exit
fi

if [ -z $frontend_branch ] || [ $frontend_branch == 'master' ]; then
  echo 'ERROR: input forntend release branch - 5th param'
  exit
fi

if [ -z $backend_branch ] || [ $backend_branch == 'master' ]; then
  echo 'ERROR: input backend release branch - 6th param'
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
rm -rf $PWD/projectX && mkdir $PWD/projectX && cd "$_"
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
sed -i -e "s/DEBUG = True/DEBUG = False/g"  ./settings.py
sed -i -e "s/ALLOWED_HOSTS = \\[\\]/ALLOWED_HOSTS = [$server_name]/g"
sed -i -e "s/'NAME': os.path.join(BASE_DIR, 'db.postgresql_psycopg2'),/'NAME': 'project_x', 'USER': '$db_username', 'PASSWORD': '$db_password', 'HOST': 'localhost', 'PORT': '',/g" ./settings.py
sed -i -e "s/TIME_ZONE = 'UTC'/TIME_ZONE = 'Europe\/Moscow'; DATE_FORMAT = 'd E Y в G:i'/g"                                                                             ./settings.py
sed -i -e "s/    'django.contrib.staticfiles',/    'django.contrib.staticfiles','backend', 'ckeditor', 'ckeditor_uploader',/g"                                          ./settings.py
sed -i -e "s/        'DIRS': \\[\\],/'DIRS': [os.path.join(BASE_DIR, '$frontend\/templates\/')],/g"                                                                     ./settings.py
rm -rf settings.py-e
echo "STATIC_URL = '/static/'"                                                        >> settings.py
echo "STATIC_ROOT = os.path.join(BASE_DIR, '$frontend/static/root')"                  >> settings.py
echo "MEDIA_URL = '/media/'"                                                          >> settings.py
echo "MEDIA_ROOT = os.path.join(BASE_DIR, 'media')"                                   >> settings.py
echo "CKEDITOR_UPLOAD_PATH = 'uploads/'"                                              >> settings.py
echo "STATICFILES_DIRS = (os.path.join(BASE_DIR, '$frontend/static/'),)"              >> settings.py

rm -rf urls.py && touch urls.py
echo '# -*- coding: utf-8 -*-'                                                        >> urls.py
echo 'from django.contrib import admin'                                               >> urls.py
echo 'from django.conf.urls import url, include'                                      >> urls.py
echo ''                                                                               >> urls.py
echo 'from django.conf import settings'                                               >> urls.py
echo 'from django.conf.urls.static import static'                                     >> urls.py
echo ''                                                                               >> urls.py
echo 'urlpatterns = ['                                                                >> urls.py
echo '    url(r"^admin/", admin.site.urls),'                                          >> urls.py
echo '    url(r"^ckeditor/", include("ckeditor_uploader.urls")),'                     >> urls.py
echo '    url(r"", include("backend.urls")),'                                         >> urls.py
echo ']'                                                                              >> urls.py

cd .. && mkdir ./media ./media/tag_group_icons ./media/uploads

git clone -b $backend_branch git@github.com:igoss/backend.git
rm -rf ./backend/.git ./backend/README.md ./backend/.gitignore
mkdir $PWD/backend/migrations && touch $PWD/backend/migrations/__init__.py

git clone -b $frontend_branch git@github.com:igoss/$frontend_project.git
rm -rf ./$frontend_project/.git ./$frontend_project/README.md ./$frontend_project/.gitignore

python manage.py makemigrations
python manage.py migrate
cd ..
#make unicorn daemon
sudo rm -rf /etc/systemd/system/gunicorn.service
sudo touch /etc/systemd/system/gunicorn.service
sudo chmod 0777 /etc/systemd/system/gunicorn.service
sudo echo '[Unit]' >> /etc/systemd/system/gunicorn.service
sudo echo 'Description=gunicorn daemon' >> /etc/systemd/system/gunicorn.service
sudo echo 'After=network.target' >> /etc/systemd/system/gunicorn.service
sudo echo '[Service]' >> /etc/systemd/system/gunicorn.service
sudo echo 'User=sir.igoss' >> /etc/systemd/system/gunicorn.service
sudo echo 'Group=sir.igoss' >> /etc/systemd/system/gunicorn.service
sudo echo "WorkingDirectory=$PWD" >> /etc/systemd/system/gunicorn.service
sudo echo "ExecStart=$PWD/venv_django/bin/gunicorn --workers 3 --bind unix:$PWD/app_django/projectX.sock configuration.wsgi:application" >> /etc/systemd/system/gunicorn.service
sudo echo '[Install]' >> /etc/systemd/system/gunicorn.service
sudo echo 'WantedBy=multi-user.target' >> /etc/systemd/system/gunicorn.service
sudo chmod 0644 /etc/systemd/system/gunicorn.service

# run daemon
sudo systemctl daemon-reload
sudo systemctl stop gunicorn
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# nginx settings
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
sudo echo '    server {' >> /etc/nginx/nginx.conf
sudo echo '        listen 80;' >> /etc/nginx/nginx.conf
sudo echo "        server_name $server_name;" >> /etc/nginx/nginx.conf
sudo echo '        location /static/ {' >> /etc/nginx/nginx.conf
sudo echo "        alias $PWD/..;" >> /etc/nginx/nginx.conf
sudo echo '    }' >> /etc/nginx/nginx.conf
sudo echo '    location / {' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header Host $http_host;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/nginx.conf
sudo echo '        proxy_set_header X-Forwarded-Proto $scheme;' >> /etc/nginx/nginx.conf
sudo echo "        proxy_pass http://unix:$PWD/projectX.sock;" >> /etc/nginx/nginx.conf
sudo echo '    }' >> /etc/nginx/nginx.conf
sudo echo '    location /static {' >> /etc/nginx/nginx.conf
sudo echo '        autoindex on;' >> /etc/nginx/nginx.conf
sudo echo "        alias $PWD/app_django/$frontend_project/static;" >> /etc/nginx/nginx.conf
sudo echo '    }' >> /etc/nginx/nginx.conf
sudo echo '    location /media {' >> /etc/nginx/nginx.conf
sudo echo '        autoindex on;' >> /etc/nginx/nginx.conf
sudo echo "        alias $PWD/app_django/media;" >> /etc/nginx/nginx.conf
sudo echo '    }' >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo echo '}' >> /etc/nginx/nginx.conf
sudo chmod 0644 /etc/nginx/nginx.conf

sudo usermod -a -G $USER nginx
chmod 710 /home/$USER

sudo service nginx restart
sudo systemctl enable nginx
