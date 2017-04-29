#!/usr/bin/env bash

#Attention:
#DATABASE name is hardcoded (name: project_x)
#After install need collect staticfiles: venv python manage.py collectstatic

#Script options:
#Use -u  | --db_user        --> database username
#Use -p  | --db_passwd      --> database username password
#Use -f  | --frontend       --> git project name (app_django frontend part)
#Use -bb | --backend_branch --> backend deploy branch
#Use -fb | --frontend_branch--> frontend deploy branch
#Use -s  | --server         --> server hostname

#----------------------------------------------------------------------------
#option parser
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -u|--db_user)
    DB_USERNAME="$2"
    shift ;;
    -p|--db_passwd)
    DB_PASSWORD="$2"
    shift ;;
    -f|--frontend)
    FRONTEND="$2"
    shift ;;
    -bb|--backend_branch)
    BACKEND_BRANCH="$2"
    shift ;;
    -fb|--frontend_branch)
    FRONTEND_BRANCH="$2"
    shift ;;
    -s|--server)
    SERVER_NAME="$2"
    shift ;;
esac
shift
done


#----------------------------------------------------------------------------
#option validator
if [ -z ${DB_USERNAME} ] && [ -z ${DB_PASSWORD} ]; then
  echo "ERROR: DB user and user passwd are missed!"
  echo "--> use -u | -p options."
  exit
fi

if [ -z ${FRONTEND_BRANCH} ] && [ -z ${BACKEND_BRANCH} ]; then
  echo "ERROR: frontend or backend release branch is missed!"
  echo "--> use -fb | -bb options."
  exit
fi

if [ -z ${FRONTEND} ]; then
  echo "ERROR: Frontend project not defined!"
  echo "--> use -f option."
  exit
fi

if [ -z ${SERVER_NAME} ]; then
  echo "ERROR: Server hostname is missed!"
  echo "--> use -s option."
  exit
fi


#----------------------------------------------------------------------------
#work environment
wget -O ~/.vimrc http://dumpz.org/25712/nixtext/
update-alternatives --set editor /usr/bin/vim.basic

useradd -m hotdog -s /bin/bash
cp ~/.vimrc /home/hotdog
mkdir /home/hotdog/.ssh
~/.ssh/authorized_keys
chown -R hotdog:hotdog /home/hotdog


#----------------------------------------------------------------------------
#packages install
yes Y | yum install epel-release
yes Y | yum install gcc
yes Y | yum install systemd

yes Y | yum install postgresql-server
yes Y | yum install postgresql-devel
yes Y | yum install postgresql-contrib

yes Y | yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yes Y | yum -y install python35u
yes Y | yum -y install python35u-pip

yum -y install nginx


#----------------------------------------------------------------------------
#configure postgreSQL
postgresql-setup initdb
systemctl start postgresql

sudo sed -i "s/ident/md5/g" /var/lib/pgsql/data/pg_hba.conf

sudo systemctl restart postgresql
sudo systemctl enable postgresql

sudo -u postgres psql postgres -c "CREATE DATABASE project_x;"
sudo -u postgres psql postgres -c "CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';"
sudo -u postgres psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE project_x TO ${DB_USERNAME};"


#----------------------------------------------------------------------------
#initialize django
rm -rf /home/hotdog/projectX && mkdir /home/hotdog/projectX && cd "$_"

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


#----------------------------------------------------------------------------
#configure project
mkdir $PWD/app_django
django-admin startproject configuration $PWD/app_django && cd "$_"

sed -i -e "s/'UTC'/'Europe\/Moscow'/g" ./configuration/settings.py >> /dev/null
sed '31,40d' ./configuration/settings.py >> /dev/null
sed '45,59d' ./configuration/settings.py >> /dev/null
sed '49,57d' ./configuration/settings.py >> /dev/null
rm -rf settings.py-e

cat >> ./configuration/settings.py << EOF
INSTALLED_APPS = [
  'django.contrib.admin',
  'django.contrib.auth',
  'django.contrib.contenttypes',
  'django.contrib.sessions',
  'django.contrib.messages',
  'django.contrib.staticfiles',
  'backend',
  'ckeditor',
  'ckeditor_uploader',
]


DATABASES = {
  'default': {
    'ENGINE': 'django.db.backends.postgresql_psycopg2',
    'NAME': 'project_x',
    'USER': '${DB_USERNAME}',
    'PASSWORD': '${DB_PASSWORD}',
    'HOST': 'localhost',
    'PORT': '',
  }
}


TEMPLATES = [
{
  'BACKEND': 'django.template.backends.django.DjangoTemplates',
  'DIRS': [os.path.join(BASE_DIR, '${FRONTEND}/templates/')],
  'APP_DIRS': True,
  'OPTIONS': {
    'context_processors': [
      'django.template.context_processors.debug',
      'django.template.context_processors.request',
      'django.contrib.auth.context_processors.auth',
      'django.contrib.messages.context_processors.messages',
      ],
    },
  },
]

DATE_FORMAT = 'd E Y в G:i'

STATIC_URL  = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, '${FRONTEND}/static')

MEDIA_URL  = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, '../../media')
CKEDITOR_UPLOAD_PATH = 'uploads/'

EOF

rm -rf ./configuration/urls.py && touch ./configuration/urls.py
cat >> ./configuration/urls.py << EOF
# -*- coding: utf-8 -*-
from django.contrib import admin
from django.conf.urls import url, include

urlpatterns = [
  url(r"^admin/", admin.site.urls),
  url(r"^ckeditor/", include("ckeditor_uploader.urls")),
  url(r"", include("backend.urls")),
]

EOF

mkdir -p ../../media/tag_group_icons ../../media/uploads


#----------------------------------------------------------------------------
#deploy frontend / backend
git clone -b ${BACKEND_BRANCH} git@github.com:igoss/backend.git
rm -rf ./backend/.git ./backend/README.md ./backend/.gitignore
mkdir ./backend/migrations && touch ./backend/migrations/__init__.py

git clone -b ${FRONTEND_BRANCH} git@github.com:igoss/${FRONTEND}.git
rm -rf ./${FRONTEND}/.git ./${FRONTEND}/README.md ./${FRONTEND}/.gitignore

python manage.py makemigrations
python manage.py migrate

yes "yes" | python manage.py collectstatic


#----------------------------------------------------------------------------
#configure gunicorn daemon
rm -rf /etc/systemd/system/gunicorn.service
touch  /etc/systemd/system/gunicorn.service
cd ..

sudo chmod 0777 /etc/systemd/system/gunicorn.service
cat >> /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=gunicorn daemon
After=network.target
[Service]
User=root
Group=root
WorkingDirectory=$PWD/app_django
ExecStart=$PWD/venv_django/bin/gunicorn --workers 1 --bind \
  unix:$PWD/app_django/projectX.sock configuration.wsgi:application
[Install]
WantedBy=multi-user.target

EOF
sudo chmod 0644 /etc/systemd/system/gunicorn.service

systemctl daemon-reload
systemctl stop   gunicorn
systemctl start  gunicorn
systemctl enable gunicorn


#----------------------------------------------------------------------------
#configure nginx
mkdir -p $PWD/logs_django/nginx
rm -rf /etc/nginx/nginx.conf
touch  /etc/nginx/nginx.conf

chmod 0777 /etc/nginx/nginx.conf
cat >> /etc/nginx/nginx.conf << EOF
user root;
worker_processes 1;
error_log $PWD/logs_django/nginx/error.log warn;
events {
    worker_connections  1024;
}
http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;

  log_format   main '\$remote_addr - \$remote_user [\$time_local] \$status '
      '"\$request" \$body_bytes_sent "\$http_referer" '
      '"\$http_user_agent" "\$http_x_forwarded_for"';

  access_log $PWD/logs_django/nginx/access.log main;
  sendfile on;
  #tcp_nopush     on;
  keepalive_timeout  65;
  #gzip  on;
  include /etc/nginx/conf.d/*.conf;

  server{
    listen 80;
    server_name ${SERVER_NAME};
    client_max_body_size 20M;
    location /static {
      root $PWD/app_django/frontend;
    }
    location /media {
      root $PWD/../;
    }
    location / {
      proxy_set_header Host \$http_host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_pass http://unix:$PWD/app_django/projectX.sock;
    }
  }
}

EOF
chmod 0777 /etc/nginx/nginx.conf
sudo usermod -a -G hotdog nginx

service nginx restart
systemctl enable nginx


#----------------------------------------------------------------------------
#kill 80 process && accept tcp
iptables -I INPUT 4 -p tcp --dport 80 -j ACCEPT
fuser -k 80/tcp
