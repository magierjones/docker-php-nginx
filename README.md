# About this Repo
Minimal PHP and NGINX setup derived from official PHP and NGINX images built on Alpine 3.8.

[![Docker Stars](https://img.shields.io/docker/stars/pritkin/php-nginx.svg)](https://hub.docker.com/r/pritkin/php-nginx/)
[![Docker Pulls](https://img.shields.io/docker/pulls/pritkin/php-nginx.svg)](https://hub.docker.com/r/pritkin/php-nginx/)
[![Docker Automated build](https://img.shields.io/docker/automated/pritkin/php-nginx.svg)](https://hub.docker.com/r/pritkin/php-nginx/builds/)
[![Build Status](https://travis-ci.org/magierjones/docker-php-nginx.svg?branch=master)](https://travis-ci.org/magierjones/docker-php-nginx)

## Usage

### Server
* Pull docker image and run:
```
docker pull pritkin/php-nginx:7.2.9-fpm-nginx-1.15.3
docker run -d -p 80:80 pritkin/php-nginx:7.2.9-fpm-nginx-1.15.3
```
or 

* Build and run container from source:
```
docker build -t php-nginx .
docker run -d -p 80:80 php-nginx
```

* Run container from source with filemount to local php project:
```
docker run -d -p 80:80 -v <local path to mount folder>:/var/www/html php-nginx
```

## Resources
* https://alpinelinux.org/
* http://nginx.org
* https://github.com/docker-library/php/