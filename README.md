
# Mini Web Application Framework

ultra fast h2o and mruby based rails like minimal framework
aimed to create web app for embedded sbc (raspberry pi)

## Installation
```
$ sudo rake install_with_h2o
```

This will download h2o and compile it with Mwarf included, then install everything in /usr/local

## Create web app
You can create a new app with the mwaf command
```
$ mwaf new myapp
```
And then launch it with h2o
```
$ cd myapp
$ h2o -c myapp.conf
```

## Dependencies / third party
https://github.com/fukaoi/mruby-erb
https://github.com/asfluido/mruby-sqlite
https://github.com/CicholGricenchos/Mrouter (included)
