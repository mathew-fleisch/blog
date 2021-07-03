# 2021-07-02: Automatic asdf Dependency Updates

[<- back](../../README.md)

Keeping tools up to date and managing versions can be a little less painful with [the asdf version manager](https://asdf-vm.com/#/) and a github-action, on a cron schedule. Some useful tools are not available through the host package manager (apt), and remote environments sometimes require specific versions of these tools. I have posted about the asdf version manager in previously, and this modification expands on the [docker-dev-env](https://github.com/mathew-fleisch/docker-dev-env) project to check for new versions of dependencies listed in the asdf config, and builds a new container, if any dependency has a new version listed. The next time the docker-dev-env is requested, it will prompt the user to overwrite the existing container to apply these updates automatically.

## The Details

Using a [self-hosted github-action runner](../2021-05-17/self-hosted-github-action-runners-on-self-hosted-kubernetes-cluster.md), with asdf pre-installed, a [script](https://github.com/mathew-fleisch/docker-dev-env/blob/main/scripts/update-asdf-versions.sh) is executed daily on a cron-schedule, to compare the versions saved in the asdf config file ([.tool-versions](https://github.com/mathew-fleisch/docker-dev-env/blob/main/.tool-versions)), to the latest version available for each tool. There is also a [pin](https://github.com/mathew-fleisch/docker-dev-env/blob/main/pin) file that can prevent this update process from happening, and "pin" a tool to only install one or more specific versions. The cron will run daily in a convenient time for my timezone, so that if there is a problem, I am awake to address it.

```yaml
name: Update asdf versions
on:
  schedule: # trigger daily at 11:20am PT (18:20UTC)
    - cron:  '20 18 * * *'
jobs:
  build:
    name: Update asdf versions
    runs-on: self-hosted
```

The [update-asdf-versions.sh](https://github.com/mathew-fleisch/docker-dev-env/blob/main/scripts/update-asdf-versions.sh) script will loop through the [.tool-versions](https://github.com/mathew-fleisch/docker-dev-env/blob/main/.tool-versions) file and compare each version listed to the latest version that asdf returns for each tool. If there isn't an exact string match, it will update that version directly in the .tool-versions file. For instance, if a new version of awscli was released (to check manually `asdf latest awscli` (as of this writing) => `awscli 2.2.16`) from the version listed in .tool-versions `awscli 2.2.15` and the script will update that version in the .tool-versions file. A `git tag` (semver: patch) is pushed to github, that automatically triggers the build/push process, and new container is saved to docker hub.

```yaml
name: Release docker-dev-env
on:
  push:
    tags:
      - 'v*'
jobs:
  build:
    name: Release docker-dev-env
    runs-on: self-hosted
```

To detect the latest version when running the docker-dev-env project, I created two new scripts to manage the state and version of the container. Now, a user will copy two bash scripts to their /usr/local/bin directory that will start/stop the container, and check for new versions with a curl to github.

```bash
# Skip pulling latest version, and run existing/running docker-dev-env container
me@computer ~ % dockstart
Download latest version v1.2.1 and remove current? n
Skipping latest version for existing version: v1.2.0
root@c97bcdd5624f:~$

# Stop/remove existing/running docker-dev-env container
me@computer ~ % dockstart
Download latest version v1.2.1 and remove current? y
Downloading latest version: v1.2.1
Removing container: c97bcdd5624f
Unable to find image 'mathewfleisch/docker-dev-env:v1.2.1' locally
v1.2.1: Pulling from mathewfleisch/docker-dev-env
c549ccf8d472: Already exists
...
6e58334f7f6e: Pull complete
Digest: sha256:2a8b3934e97faf841a47178ae56903f159ee2b7693822b7f5d6e454e9d4f6e86
Status: Downloaded newer image for mathewfleisch/docker-dev-env:v1.2.1
root@9b5cd9d9c292:~$ 
```

The `dockstart` and `dockstop` helper scripts can be installed with a couple of wgets

```bash
# Install helper scripts
wget https://raw.githubusercontent.com/mathew-fleisch/docker-dev-env/main/scripts/dockstart -P /usr/local/bin
wget https://raw.githubusercontent.com/mathew-fleisch/docker-dev-env/main/scripts/dockstop -P /usr/local/bin
chmod +x /usr/local/bin/dockstart
chmod +x /usr/local/bin/dockstop

# Run dockstart for the first time
me@computer ~ % dockstart
Download latest version v1.2.1 and remove current? y
Downloading latest version: v1.2.1
Unable to find image 'mathewfleisch/docker-dev-env:v1.2.1' locally
v1.2.1: Pulling from mathewfleisch/docker-dev-env
c549ccf8d472: Pulling fs layer
...
6e58334f7f6e: Pull complete
Digest: sha256:2a8b3934e97faf841a47178ae56903f159ee2b7693822b7f5d6e454e9d4f6e86
Status: Downloaded newer image for mathewfleisch/docker-dev-env:v1.2.1
root@bf15e5e7b277:~$ 
```

The helper scripts will ensure only one of these containers are running at a time and that they persist until explicitly stopped.

```bash
# Check running docker containers
me@computer ~ % docker ps
CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS         PORTS     NAMES
bf15e5e7b277   mathewfleisch/docker-dev-env:v1.2.1   "/bin/sh -c '/bin/ba…"   7 seconds ago   Up 6 seconds             docker-dev-env

# Stop docker-dev-env container
me@computer ~ % dockstop
Removing container: bf15e5e7b277

# Check running docker containers
me@computer ~ % docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

To switch between versions in a running container, use the `asdf global` command to set the version

```bash
# Start a container
me@computer ~ % dockstart

# Check installed versions
root@b36362bfbe52:~$ asdf list terraform
  0.12.30
  1.0.1

# Check currently set version
root@b36362bfbe52:~$ terraform version
Terraform v0.12.30
Your version of Terraform is out of date! The latest version
is 1.0.1. You can update by downloading from https://www.terraform.io/downloads.html

# Set new version
root@b36362bfbe52:~$ asdf global terraform 1.0.1

# Confirm new version is set
root@b36362bfbe52:~$ terraform version
Terraform v1.0.1
on linux_amd64
```

