# Containers

These containers are intended to provide a stable and predictable development
environment. This includes an editor, in my case, that's currently Doom Emacs.
(Putting Doom Emacs inside a container is a good thing, because every other
update seems to break it in some way.)

There are a number of sub-containers. Each sub-container is meant to provide a
particular aspect of the development environment. The idea here is to have
orthogonal containers that can be layered in different ways. This is probably
not really necessary, but at least it helps organization.

## Building

To build the containers, use the following command:

```sh
./build.sh
```

## Running

To run the combined container, use the following command:

```sh
./run.sh
```
