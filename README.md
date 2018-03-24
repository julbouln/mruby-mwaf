## Mini Web Application Framework

ultra fast h2o and mruby based rails like minimal framework
aimed to create web app for embedded sbc (raspberry pi)

## Installation
get stable h2o release : https://github.com/h2o/h2o/releases

```
$ tar xvzf h2o-2.2.4.tar.gz
$ cd h2o-2.2.4/deps
$ git clone https://github.com/julbouln/mruby-mwaf
$ cd ..
$ cmake -DEXTRA_LIBS="-lsqlite3 -ldl" .
$ make -j8
$ sudo make install
```
## Create web app
copy example app into new directory
```
cp ../h2o-2.2.4/mruby/host/bin/mruby bin/
cp ../h2o-2.2.4/mruby/host/bin/mirb bin/
```
(TODO create a script)