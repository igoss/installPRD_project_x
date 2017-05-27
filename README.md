# Использование 

Перед 1ой установкой: 
<br>
`$ yum install git`
<br>
`$ ssh-keygen` и `$ cat ~/.ssh/id_rsa.pub` для генерации rsa-ключа.
<br>
<br>
Скрипт выполняет установку окружения и проекта для **Preview** и **Production**.
<br>
Для корректной работы в **production** необходимо добавить SSL-сертификаты:
<br>
- Основная цепочка сертификатов (private.crt и bundle.crt)=chain.crt
- Закрытый ключ (private.key)
- dhparam.pem

Для генерации **dhparam.pem**:
`openssl dhparam -out /path_to_key/dhparam.pem 4096`
<br>
<br>
**Скрипт вызывать с параметрами:**
* -s: Hostname;
* -f: Frontent project name;
* -i: Install type (test | prod)
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

Для **Preview** версии подключение осуществляется через http, Debug = True
<br>
Для **Production** версии подключение выполняется через https, Debug = False + ALLOED_HOSTS.
<br><br>
**Проверка демонов:**
- systemctl status gunicorn
- systemctl status nginx

**Проверка SSL:**
- https://www.ssllabs.com/ssltest/analyze.html (Result: A+)
- `$ openssl s_client -connect hostname:443 -state -debug`

**После переустановки ОС:** 
- ssh-keygen -R host (на локальной машине)
- yum install git
- ssh-keygen
- cat ~/.ssh/id_rsa.pub 
- скопировать ключ и добавить его в репозиторий github

**Отводим релиз:**
- git checkout -b branch-name
- git push origin branch-name
