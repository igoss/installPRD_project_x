# Использование 

`$ ./deployPrd.sh` 
<br>
<br>
**Скрипт вызывать с параметрами:**
* -u: DB user;
* -p: User password;
* -s: Hostname;
* -f: Frontent project name;
* -bb: Branch backend;
* -fb: Branch frontend.

Запуск скрипта делать под **root**-пользователем.

# Что делает?

Скрипт собирает и раскатывает проект для превью / прод среды на тачке с CentOS. 
<br>
В процессе работы скрипта, создается окружение django-проекта, выполняется установка
<br>
необходимых библиотек. Выполняется настройка демонов gunicorn и nginx, создается база данных.
<br>
* **OS configure**:
  * create user hotdog
* **OS app:**
  * python
  * postgresql 9.6
  * nginx
  * gcc
* **Python venv:**
  * django==1.9
  * psycopg2==2.7.1
  * django-ckeditor
  * django-resized
  * pillow
  * unicorns
* **Django configure:**
  * creata app
  * deploy frontend / backend
  * migrate database


