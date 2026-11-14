# TODO

Gaps between the container image and the old BDAI base image.

## Packages and Tools

- [x] Install `git-lfs` and run `git lfs install --skip-repo` for the user
- [x] Install `htop`
- [x] Install `tmux`
- [x] Install `net-tools`
- [x] Install `usbutils`
- [x] Install `p7zip-full` (only `p7zip` is installed)
- [ ] Install `patchelf`
- [ ] Install `ffmpeg` and the `libav*-dev` libraries (`libavcodec-dev`, `libavdevice-dev`,
      `libavfilter-dev`, `libavformat-dev`, `libavutil-dev`, `libswscale-dev`)
- [ ] Install `equivs` and `fakeroot`
- [ ] Install `gke-gcloud-auth-plugin`
- [ ] Install `ros-humble-rmw-cyclonedds-cpp`
- [ ] Install `python3-pytest-cov`
- [ ] Add a CUDA toolkit option (`nvcc` and `/usr/local/cuda/bin` on `PATH`)

## Runtime

- [ ] Set `--shm-size` in `run.sh` (the old default was 512m, Docker defaults to 64M)
- [ ] Add an entry point that warns when shared memory is too small
- [ ] Add an opt-in DNS fix entry point that overwrites `/etc/resolv.conf` with known-good
      nameservers, since the VPN rewrites the host `resolv.conf` and breaks DNS in the container
- [ ] DNS has a search for `theaiinstitute.local` (opt-in)
- [ ] Forward the SSH agent (`SSH_AUTH_SOCK`) in `run.sh`
- [ ] Set `QT_X11_NO_MITSHM=1` so Qt apps (e.g., RViz) render over X11
- [ ] Make Git HTTPS authentication use the GitHub CLI (e.g., `gh auth setup-git`), instead of
      relying on the host `~/.gitconfig`
- [ ] Persist caches across runs (e.g., prek, pip, and uv caches)
- [ ] Set `PYTHONWARNINGS` to hide the ament/setuptools deprecation warnings in ROS 2 Humble
- [ ] Add the user to the `adm`, `dialout`, `plugdev`, `video`, and `render` groups (e.g., so
      serial devices passed with `--device` are accessible)
- [ ] Add an entry point that writes an apt auth file for Artifactory from the `jf` config
- [ ] Add a verbose mode for the entry points (e.g., `ENTRYPOINT_VERBOSE`) to log each step
- [ ] Fix X11 auth in `run.sh`: mount `$XAUTHORITY` into the user's home (not `/root`) and set
      `XAUTHORITY`, handle `XAUTHORITY` being unset, and drop the unused `~/.Xauthority` file
      (X11 only works now because of `xhost` local user access)
- [ ] Mount `/tmp/.X11-unix` so X11 does not depend on the abstract socket and `--network=host`

## Setup

- [ ] Have `setup.sh` install the GPG extra socket drop-in from `gpg/gnupg-extra.conf`, reload
      systemd, and restart `gpg-agent-extra.socket`
- [ ] Have `setup.sh` check that `pubring.kbx` and `trustdb.gpg` exist in the host GnuPG directory
- [ ] Have `setup.sh` install `pass`, check that the password store is initialized, and create the
      `container` subdirectory
- [ ] Have `setup.sh` warn about missing password store entries (`github/token`,
      `atlassian/token`, `atlassian/site`, and `atlassian/email`)
- [ ] Have `setup.sh` provide an SSH agent socket in a dedicated directory, so `run.sh` can bind
      mount the directory (the GNOME Keyring socket directory also holds other keyring sockets)
- [ ] Have `setup.sh` install `hn2b.sh`, which `build.sh` requires
- [ ] Have `setup.sh` check that the host `~/.gitconfig` sets `user.name`, `user.email`, and
      `user.signingkey`, since it is mounted into the container
- [ ] Replace the manual GPG and password store steps in `containers/README.md` with `setup.sh`

## Misc

- [ ] Switch the MD5 download checks to SHA-256 (emacs, emsdk, misc, and emacs builder layers)
- [ ] Add checksums for unverified downloads (IWYU tarball and Nerd Font)
- [ ] Pin URLs that track `master` or `main` (ROS key, colcon mixin and metadata indexes, Xpra
      sources, and Nerd Font)
- [x] Add the strict `SHELL` line (`bash -euo pipefail`) to the emsdk layer
- [x] Fix the header comments in the agent and Xpra Containerfiles
- [x] Fix the "Projecs" typo in `run.sh`

## Upgrades

- [ ] Upgrade Emscripten from 3.1.40 to 6.0.13, and replace its Node 15
- [ ] Upgrade ripgrep from 13.0.0 to 15.2.0
- [ ] Upgrade fd from 8.2.1 to 10.5.0
- [ ] Upgrade LLVM from 16 to 23
- [ ] Upgrade IWYU from 0.20 to the release matching the new LLVM version
- [ ] Upgrade Emacs from 29.4 to 31.1
- [x] Upgrade Bazel from 9.2.0 to 9.3.2
