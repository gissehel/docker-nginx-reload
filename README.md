# Urls

* https://registry.hub.docker.com/u/gissehel/nginx-with-reload
* https://registry.hub.docker.com/u/gissehel/expose-to-nginx
* https://github.com/gissehel/docker-nginx-reload

# The problem

Imagine you're in that situation:
* You're running a lot of different applications on your server
* They are hosted in docker containers and they all export a port accessible using HTTP
* You want to have a nginx as a front-end
* You obviously want that nginx to be hosted in a docker
* You don't want to restart the nginx container each time a configuration file has been changed, you just want to reload it.

Now, each time you remove/start a container, a new IP address will be allocated. You don't want to find it and write it in a config file by hand each time you restart a container.

You don't want your nginx container to explicitly depend upon all your other application because it will require to remove/restart your nginx each time you remove/restart any application container.

# The solution

This solution is composed of two images :
* [gissehel/ginx-with-reload](https://registry.hub.docker.com/u/gissehel/nginx-with-reload) that will contain the nginx process, and way to reload the nginx process.
* [gissehel/expose-to-nginx](https://registry.hub.docker.com/u/gissehel/expose-to-nginx) that will handle the proxy settings generation, and will send the appropriate reload to the nginx container.

# Examples

## Using crane
[Crane example](examples/crane)

## Using raw docker commands
[raw docker example](examples/raw)



