# 2021-04-07: Dev in a Can
[<- back](../../README.md)

For the past few years I have been using docker on my macs as a local development environment, rather than installing and maintaining tools directly on the mac itself. Essentially I only install Docker and my IDE of choice, and use docker for everything else. I will mount source code and private keys into a linux container that has all of the tools I might need, and from inside the container, I can run tools like terraform, helm and kubectl. This method can help align teammates on the same versions of tools, and the (likely) operating system the tools will be run on, in automation/CI. Using the [asdf version manager](https://asdf-vm.com/#/) can help when multiple versions of tools like terraform or kubectl are used in different environments. The tool provides methods to install multiple versions of select tools, and the ability to switch between versions of the same tool.

<img src="https://i.imgur.com/AGLznZ4.gif" width="100%" />

## The Details

  I have set up a [repository](https://github.com/mathew-fleisch/docker-dev-env) for this post and am hosting the docker container on my [docker hub account](https://hub.docker.com/r/mathewfleisch/docker-dev-env) and as a [github package](https://github.com/mathew-fleisch?tab=packages&repo_name=docker-dev-env). The `-v` flag mounts a file or directory from the host (mac) to inside the container. This flag is used to mount `~/.vimrc` and `~/.bash_aliases` files as well as the `~/.ssh` and `~/.kube` directories to access remote servers using credentials and my configuration preferences. Finally, the `~/src`  directory is mounted in the container so that source code files I have downloaded can be edited from the mac, via my IDE of choice, and changes are in sync with files in the container. Using this method, you can run ssh or kubectl commands from either the mac or from inside the container because the credentials and source code are mounted/in-sync.

```bash
docker run -it --rm \
  -v /Users/$(whoami)/.vimrc:/root/.vimrc \
  -v /Users/$(whoami)/.kube:/root/.kube \
  -v /Users/$(whoami)/.ssh:/root/.ssh \
  -v /Users/$(whoami)/.aliases:/root/.bash_aliases \
  -v /Users/$(whoami)/src:/root/src \
  --name linux-dev-env \
  mathewfleisch/docker-dev-env:latest
```


**Tools**

There are many tools preinstalled in the docker container using apt and the [asdf version manager](https://asdf-vm.com/#/). The [Dockerfile](https://github.com/mathew-fleisch/docker-dev-env/blob/main/Dockerfile) for this project first installs some dependencies with apt, then installs asdf via git, then installs plugins for asdf to use. Below are the tools currently installed in this container, as of this post:

apt | asdf
---------|-----
curl | awscli 2.1.32
wget | golang 1.16.2
apt-utils | helm 3.5.3
python3 | helmfile 0.138.7
python3-pip | k9s 0.24.6
make | kubectl 1.20.5
build-essential | kubectx 0.9.3
openssl | shellcheck 0.7.1
lsb-release | terraform 0.12.30
libssl-dev | terragrunt 0.28.18
apt-transport-https | tflint 0.25.0
ca-certificates | yq 4.0.0
iputils-ping |
git |
vim |
zip |

Adding a couple bash functions to the bashrc/zshrc files, as aliases, can make spinning the container up, and exec'ing into it, much faster and persistent. The `linux` function will first check if a `docker-dev-env` container is already running and exec into it. If there is no `docker-dev-env` container running, it will spin one up in detached mode, and then exec into it. Exiting out of these containers will not stop them because they are in detached mode. Running `linuxrm` will remove any running containers.

```bash
function linux() {
  container_name=docker-dev-env
  container_id=$(docker ps -aqf "name=$container_name")
  if [[ -z "$container_id" ]]; then
    container_id=$(docker run -dit \
      -v /Users/$(whoami)/.vimrc:/root/.vimrc \
      -v /Users/$(whoami)/.kube:/root/.kube \
      -v /Users/$(whoami)/.ssh:/root/.ssh \
      -v /Users/$(whoami)/.aliases:/root/.bash_aliases \
      -v /Users/$(whoami)/src:/root/src \
      --name $container_name \
      mathewfleisch/docker-dev-env:latest)
  fi
  docker exec -it $container_id bash
}
function linuxrm() {
  container_name=docker-dev-env
  container_id=$(docker ps -aqf "name=$container_name")
  if [[ -n "$container_id" ]]; then
    echo "Removing container: $(docker rm -f $container_id)"
  fi
}
```

<img src="https://i.imgur.com/eqGmgVF.gif" width="100%" />