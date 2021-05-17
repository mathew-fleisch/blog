# Self-Hosted GitHub Action Runners On Self-Hosted Kubernetes Cluster
[<- back](../../README.md)

In this post, I will describe how I self-hosted Github Action runners on my home Raspberry pi k3s cluster, as my main method of continuous integration. I will use these runners to build and push multi-arch docker containers and go-binaries for all of my personal projects, going forward. To start, I followed [Jeff Geerling's k3s series](https://www.youtube.com/playlist?list=PL2_OBreMn7Frk57NLmLheAaSSpJLLL90G) to build the kubernetes cluster (using this [ansible playbook](https://github.com/k3s-io/k3s-ansible)), and installed the prometheus+grafana stack using a fork of the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) project by [Carlos Eduardo](https://carlosedp.medium.com/) called [cluster monitoring](https://github.com/carlosedp/cluster-monitoring). I then removed the cluster monitoring project because Prometheus took up too many resources for the pretty graphs and alerts to be worth the CPU cycles, in my two node k3s cluster. Next, I needed to build a container that would include any tools that I might use in automation, as well as the [Github Action runner agent](https://github.com/actions/runner), and host that container in a container registry (docker hub). Finally, I created a kubernetes deployment with the environment variables, the entry-point expects, and tested everything was working by rebuilding the runner's container.

<img src="https://i.imgur.com/Hj2cNJN.png" width="100%" />

**Plan Overview**
 1. [Create docker container that can run the Github actions agent](#create-docker-container)
 2. [Use container to build + push a new version of itself to docker-hub](#build-push-self)
 3. [Deploy runners in k3s cluster](#kubernetes-deployment)
 4. [Migrate existing job to self-hosted runner](#migrate-existing-ci)


## The Details

### <a name="create-docker-container" id="create-docker-container"></a>Create Docker Container

The first step was to build a docker container that had all of my build tools pre-installed, and that could run the Github actions runner agent. I also wanted this container to be flexible enough to work for multiple operating system architectures (MBP or a raspberry pi). After some [inspiration](http://smartling.com/resources/product/building-multi-architecture-docker-images-on-arm-64-bit-aws-graviton2/), among other tools, docker and a [docker plugin (buildx)](https://github.com/docker/buildx) were [built into a container](https://github.com/mathew-fleisch/github-actions-runner) and pushed to [docker hub](https://hub.docker.com/repository/docker/mathewfleisch/github-actions-runner/tags?page=1&ordering=last_updated). The buildx plugin works in conjunction with the apt packages `binfmt-support qemu-user-static` to emulate different OS architectures, to build multi-arch containers on a single OS architecture. Running this docker container, will automatically detect the host OS, and start listening for Github action jobs, for a specific owner/repository. Subsequent Github actions that are triggered with a "self-hosted" (or other custom) label will execute in that container.

At this stage, this [docker container](https://github.com/mathew-fleisch/github-actions-runner) is [hosted in docker hub](https://hub.docker.com/repository/docker/mathewfleisch/github-actions-runner/tags?page=1&ordering=last_updated) and can be run manually on a Raspberry Pi or MBP:


```bash
# From RPI
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  -e GIT_PAT="$GIT_TOKEN" \
  -e GIT_OWNER="mathew-fleisch" \
  -e GIT_REPO="github-actions-runner" \
  -e LABELS="gha-runner" \
  --name "gha-runner" \
  mathewfleisch/github-actions-runner:v0.1.0



# From Mac
docker run -it --rm \
  -v /var/run/docker.sock:/var/rund/docker.sock \
  -e GIT_PAT="$GIT_TOKEN" \
  -e GIT_OWNER="mathew-fleisch" \
  -e GIT_REPO="github-actions-runner" \
  -e LABELS="gha-runner" \
  --name "gha-runner" \
  mathewfleisch/github-actions-runner:v0.1.0

# --------------------------------------------------------------------------------
# |        ____ _ _   _   _       _          _        _   _                      |
# |       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
# |      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
# |      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
# |       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
# |                                                                              |
# |                       Self-hosted runner registration                        |
# |                                                                              |
# --------------------------------------------------------------------------------
# 
# # Authentication
# √ Connected to GitHub
# # Runner Registration
# √ Runner successfully added
# √ Runner connection is good
# # Runner settings
# √ Settings Saved.
# ./run.sh
# √ Connected to GitHub
# 2021-05-16 05:07:22Z: Listening for Jobs
# 2021-05-16 05:16:24Z: Running job: Release github-actions-runner
# 2021-05-16 05:49:22Z: Job Release github-actions-runner completed with result: Succeeded

```


### <a name="build-push-self" id="build-push-self"></a>Build And Push Self

Once one or more of these containers are running, with the correct environment variables set, the runners are listed on the `settings > actions > runners` page of the repository they are registered with

***Example Action:***

[This action](https://github.com/mathew-fleisch/github-actions-runner/blob/main/.github/workflows/tag-release.yaml) is triggered on new git tag versions, and creates a new git release, before a multi-arch docker build + push to docker hub, via [buildx](https://github.com/docker/buildx). The `runs-on` parameter has been set to `self-hosted` and will only execute on runners with that label. There are also two [Github Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) saved in this repository as push credentials to docker hub, that get injected to the job as environment variables.

```yaml
# Name:        tag-release.yaml
# Author:      Mathew Fleisch <mathew.fleisch@gmail.com>
# Description: This (abbreviated) action will build and push a multi-arch
#              docker container, when triggered by pushing a new git tag,
#              starting with the letter 'v'.
name: Release github-actions-runner
on:
  push:
    tags:
      - 'v*'
jobs:
  build:
    name: Release github-actions-runner
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v2
      - name: "Release github-actions-runner"
        env:
          REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
          REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
        run: |
          echo "Login to container registry"
          echo "$REGISTRY_PASSWORD" | docker login docker.io -u="$REGISTRY_USERNAME" --password-stdin
          echo "Build and push docker container"
          docker buildx build --platform linux/amd64,linux/arm64 -t mathewfleisch/github-actions-runner:$tag --push .

```

The trigger happens when a developer pushes a new tag to the target repository

```bash
git tag v0.1.0
git push origin v0.1.0
```

The console output from jobs can be expanded via the `Actions` tab of the target repository. 

<img src="https://i.imgur.com/RX72mdb.png" width="100%" />

Clicking each section in the actions ui will expand the console output for that job.

<img src="https://i.imgur.com/RAKJ7WC.png" width="100%" />

------------------------------

### <a name="kubernetes-deployment" id="kubernetes-deployment"></a>Kubernetes Deployment

The last step is to deploy this container in a kubernetes cluster to keep it persistent, and make it easier to add/remove runners. Ideally, a kubernetes operator, [like this one](https://github.com/evryfs/github-actions-runner-operator), would be used to manage the runners, but to prove the concept, and show the bare minimum requirements, this next section will show a manual deployment.

```bash
# Create a namespace to contain runners
kubectl create namespace github-actions
# namespace/github-actions created

# Create a secret to hold GIT_TOKEN
kubectl -n github-actions create secret generic git-token \
  --from-literal=GIT_TOKEN=Tm90IGFjdHVhbGx5IG15IHBhc3N3b3JkLi4uIG5pY2UgdHJ5IPCfmI8K
# secret/git-token created
```

Now that there is a [Github personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) saved as a kubernetes secret, in a new namespace, a deployment can be applied, to set up a persistent Github action runner. This container is a public image, and can be pulled from docker hub without credentials. The kubernetes secret holding the Github token is injected to the pod as an environment variable, along with other configuration variables to control the owner/repository information. This deployment.yaml file can be copied for use with other repositories, and run in the same namespace in either ARM64 or x86_64 based architectures.

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: github-actions-runner
  name: github-actions-runner
  namespace: github-actions
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: github-actions-runner
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: github-actions-runner
    spec:
      containers:
      - env:
        - name: GIT_PAT
          valueFrom:
            secretKeyRef:
              name: git-token
              key: GIT_TOKEN
        - name: GIT_OWNER
          value: mathew-fleisch
        - name: GIT_REPO
          value: github-actions-runner
        image: mathewfleisch/github-actions-runner:v0.1.0
        imagePullPolicy: IfNotPresent
        name: github-actions-runner
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
            - name: dockersock
              mountPath: "/var/run/docker.sock"
      volumes:
      - name: dockersock
        hostPath:
          path: /var/run/docker.sock
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      terminationGracePeriodSeconds: 30

```

To apply this deployment

```bash
kubectl -n github-actions apply -f deployment.yaml
# deployment.apps/github-actions-runner created

kubectl -n github-actions get pods
# NAME                                    READY   STATUS    RESTARTS   AGE
# github-actions-runner-b6ffc59df-jssjz   1/1     Running   0          21m


kubectl -n github-actions logs github-actions-runner-b6ffc59df-jssjz
# --------------------------------------------------------------------------------
# |        ____ _ _   _   _       _          _        _   _                      |
# |       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
# |      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
# |      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
# |       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
# |                                                                              |
# |                       Self-hosted runner registration                        |
# |                                                                              |
# --------------------------------------------------------------------------------
# 
# # Authentication
# √ Connected to GitHub
# # Runner Registration
# √ Runner successfully added
# √ Runner connection is good
# # Runner settings
# √ Settings Saved.
# ./run.sh
# √ Connected to GitHub
# 2021-05-16 21:08:46Z: Listening for Jobs

```

Verify it is connected via the Github UI under `settings > actions > runners`

<img src="https://i.imgur.com/FjVoMqM.png" width="100%" />

<center><img src="https://i.imgur.com/9RhCWsL.gif" /></center>

To delete this deployment/runner

```bash
kubectl -n github-actions delete -f deployment.yaml
# deployment.apps "github-actions-runner" deleted
```


### <a name="migrate-existing-ci" id="migrate-existing-ci"></a>Migrate Existing CI

To wrap this project up, I converted an existing CI automation to use one of these self-hosted runners. I copied the deployment.yaml for a new repository, and modified the existing job, to use a self-hosted runner, instead of a runner provided by Github.

```bash
kubectl -n github-actions get pods
# NAME                                    READY   STATUS    RESTARTS   AGE
# github-actions-runner-b6ffc59df-tw29j   1/1     Running   0          75m
# docker-dev-env-6f4c79698c-ngx4q         1/1     Running   0          36m
````

With the self-hosted Github action runner, running for the [docker-dev-env repository](https://github.com/mathew-fleisch/docker-dev-env/) a [pull request](https://github.com/mathew-fleisch/docker-dev-env/pull/3) details how the job points to a self-hosted runner. Pushing a new git tag triggers the Github action to build and push a new container, in this pod `docker-dev-env-6f4c79698c-ngx4q`

<img src="https://i.imgur.com/meIocp9.png" width="100%" />
