# Introduction

this example shows how to use both images [gissehel/nginx-with-reload] and [gissehel/expose-to-nginx] using [docker] command line only (no automation tool like [crane] or [docker-compose]/fig).

If you're reading this and want to execute the command, perhaps you want to change the following detail to the crane.yaml file before starting:

* The path `/opt/storage` is used in this example to storage all data for containers. Perhaps you want to change all occurences of that path in all command lines if you want to store the files elsewhere
* The name `.example.com` is used for vhosts. Perhaps yo want to use **your** domain here. If you don't have one, or you don't have one yet, you can edit `/etc/hosts` (or `c:\Windows\System32\drivers\etc\hosts`) to add the line `127.0.0.1 *.example.com`
* If your port 80 is already binded, change `"80:80"` in command lines to `"8000:80"` and use `http://ghost.example.com:8000/` instead of `http://ghost.example.com/` each time you want to test something in the browser

# Tutorial

## Pull all the images

```
$ sudo docker pull gissehel/nginx-with-reload
Pulling repository gissehel/nginx-with-reload
[...]
$ sudo docker pull gissehel/expose-to-nginx
Pulling repository gissehel/expose-to-nginx
[...]
$ sudo docker pull ghost
Pulling repository ghosrt
[...]
$ sudo docker pull crosbymichael/dockerui
Pulling repository crosbymichael/dockerui
[...]

```

## Start the web server

```bash
$ sudo docker run --name web -d -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" -p "80:80" --hostname "web" "gissehel/nginx-with-reload"
deb5a6c35d9f1a66f1d0f2349b7cd4594468f24382a7aef246e27d18d4ba86de
```

## Start "ghost"

Ghost is a simple blog platform.
```bash
$ sudo docker run --name ghost -d --hostname ghost -v "/opt/storage/ghost:/var/lib/ghost:rw" "ghost"
196f86252c0cc15b14cdb8e4e345286f930d788028b91d7153da9607582775d2
```

The url `http://ghost.example.com/` should **not** work right now.

## Configure nginx to proxy ghost

run container `ghost-expose` (it will end quickly):
```bash
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "ghost:slot" -e "NAME=ghost" -e "NAMES=ghost.example.com www.ghost.example.com" -e "PORT=2368" "gissehel/expose-to-nginx"
```

That's it... Now The url `http://ghost.example.com/` should work. (Note that example.com should either have been replaced by your domain, or you should have change your hosts file as stated in the introduction for this to work)

## How does that work ?

`web` container use 3 directories:

| host folder | container folder | usage |
| ----------- | ---------------- | ----- |
| /opt/storage/nginx/conf.d | /etc/nginx/conf.d | Used to store confgurations for vhosts or global nginx parameters |
| /opt/storage/nginx/log | /var/log/nginx | Log directory |
| /opt/storage/nginx/control | /etc/nginx/control | This is a folder that is used by [gissehel/nginx-with-reload] to create a fifo file for communication between containers |

`ghost` just publish it's http site on the port 2368. Note that this port isn't published by the host at all.

`ghost-expose` is linked to the container `ghost` with the name `slot`. There are env. variables that qualify how to create proxy redirection

| env name | value | meaning |
| -------- | ----- | ------- |
| NAME | ghost | used to identify the files `ghost.conf`, `ghost-upstream.conf` in `conf.d` and `access-ghost.log`, `error-ghost.log` in `/opt/storage/nginx/log` |
| NAMES | ghost.example.com www.ghost.example.com | the name/names used by the vhosts. You can put as many as -you- nginx wants here |
| PORT | 2368 | The port on the container linked under the name `slot` |

So the `ghost-expose` know exactly where to proxy, and what configuration files to create.

`ghost-expose` also share the 3 same folders as the `web` containers, this allow him to:
* write a new/overwrite a configuration file in the `/etc/nginx/conf.d` directory of the `web` container.
* put it's logs in the `/var/log/nginx` directory of the `web` container. (Well, it could be another directory here, it wouldn't change the face of the world).
* send a message in the `/etc/nginx/control/nginx-fifo` fifofile. This message will be read by a process in the nginx container, and it reload the configuration without restarting nginx.

## Start dockerui

[dockerui] is a web interface for docker.

We will use the official image `crosbymichael/dockerui`.

As this image will access all your docker containers, and will run in priviledge mode, you should not allow anyone on that site.

That's why we will use basic_auth. (Of course, in real life you'll also use https, and preferably https only. And also you won't leave a real vhost as the default vhost, but all that is basic nginx configuration that is out of the scope of this document. Still do it. Really)

We have a container `dui` that use the image `crosbymichael/dockerui`. It publish it's site on the port **9000** by default.

We have a container `dui-expose` that use the same image as before `gissehel/expose-to-nginx`. It's linked to the container `dui` under the name `slot` (see `ghost-expose`).
But we have one more env. variable.

| env name | value | meaning |
| -------- | ----- | ------- |
| NAME | dockerui | |
| NAMES | dui.example.com | |
| PORT | 9000 | |
| AUTHFILE | conf.d\\/dui-password-file | The file containing users and password allowed for this site |

Before starting dockerui we need to create a file `dui-password-file`. For that, we will use again the image `gissehel/expose-to-nginx`  but with other parameters.

```bash
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -e "AUTHFILE=conf.d/dui-password-file" "gissehel/expose-to-nginx" /bin/bash /newuser
User? test
New password:
Re-type new password:
Adding password for user test

```

just type the username you want to access to the site, type the password twice, and enter a blank line (I've totally no idea why I must enter a blank line by the way)

Now run the containers `dui` and `dui-expose`
```bash
$ sudo docker run --name=dui -d --privileged=true -v "/var/run/docker.sock:/var/run/docker.sock" "crosbymichael/dockerui"
b6e71a70aa11b62f817213ff91bf3b44553709b35eb7c8ab85d4193701848752
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "dui:slot" -e "NAME=dockerui" -e "NAMES=dui.example.com" -e  "PORT=9000" -e "AUTHFILE=conf.d\\/dui-password-file" "gissehel/expose-to-nginx"
```

and try the url `http//dui.example.com/`. A login/password will be prompt. Put the one you choose (In the previous example test/\*\*\*\*).

You can now try again `http://ghost.example.com/` it should not ask you for a password as the password was only requested for the vhost `dui.example.com`.

## Restart a container from scratch

To restart dockerui, do :
```bash
$ sudo docker stop dui
$ sudo docker rm -v dui
$ sudo docker run --name=dui -d --privileged=true -v "/var/run/docker.sock:/var/run/docker.sock" "crosbymichael/dockerui"
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "dui:slot" -e "NAME=dockerui" -e "NAMES=dui.example.com" -e  "PORT=9000" -e "AUTHFILE=conf.d\\/dui-password-file" "gissehel/expose-to-nginx"
```

to restart ghost, do :
```bash
$ sudo docker stop ghost
$ sudo docker rm -v ghost
$ sudo docker run --name ghost -d --hostname ghost -v "/opt/storage/ghost:/var/lib/ghost:rw" "ghost"
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "ghost:slot" -e "NAME=ghost" -e "NAMES=ghost.example.com www.ghost.example.com" -e "PORT=2368" "gissehel/expose-to-nginx"
```

Of course, if you restart the web container, it will still work :
```bash
$ sudo docker stop web
$ sudo docker rm -v web
$ sudo docker run --name web -d -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" -p "80:80" --hostname "web" "gissehel/nginx-with-reload"
```

# Quick version

If you want to have everything from this tutorial running without the step-by-step and the explainations, here are the commands :
```bash
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -e "AUTHFILE=conf.d/dui-password-file" "gissehel/expose-to-nginx" /bin/bash /newuser
User? test
New password:
Re-type new password:
Adding password for user test

$ sudo docker run --name web -d -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" -p "80:80" --hostname "web" "gissehel/nginx-with-reload"
$ sudo docker run --name ghost -d --hostname ghost -v "/opt/storage/ghost:/var/lib/ghost:rw" "ghost"
$ sudo docker run --name=dui -d --privileged=true -v "/var/run/docker.sock:/var/run/docker.sock" "crosbymichael/dockerui"
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw" -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "ghost:slot" -e "NAME=ghost" -e "NAMES=ghost.example.com www.ghost.example.com" -e "PORT=2368" "gissehel/expose-to-nginx"
$ sudo docker run -it --rm=true -v "/opt/storage/nginx/conf.d:/etc/nginx/conf.d:rw" -v "/opt/storage/nginx/log:/var/log/nginx:rw -v "/opt/storage/nginx/control:/etc/nginx/control:rw" --link "dui:slot" -e "NAME=dockerui" -e "NAMES=dui.example.com" -e  "PORT=9000" -e "AUTHFILE=conf.d\\/dui-password-file" "gissehel/expose-to-nginx"
```

Also, you should really consider an automation tool like [crane]/[docker-compose] or any classical tool like ansible/chef/pupper.

[gissehel/nginx-with-reload]:https://registry.hub.docker.com/u/gissehel/nginx-with-reload
[gissehel/expose-to-nginx]:https://registry.hub.docker.com/u/gissehel/expose-to-nginx
[docker]:http://docker.com/
[crane]:https://github.com/michaelsauter/crane
[dockerui]:https://github.com/crosbymichael/dockerui
[docker-compose]:https://docs.docker.com/compose


