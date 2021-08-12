# Mathew's Blog

My name is Mathew Fleisch, and I am a programmer and musician from the bay area in California. I started my career as a developer, and in the past few years shifted to infrastructure/devops. I love creating automation and optimizing automation pipelines. I will use this "blog" to share stories, experiences and I am starting in March of 2021, in the midst of the global coronavirus pandemic.

## [2021-08-11: Bashbot](blog/2021-08-1/bashbot.md)

[Bashbot](https://github.com/mathew-fleisch/bashbot) is a chat-ops tool I built, to automate tasks that are common to infrastructure/devops teams. There are often scripts or CI (continuous integration) jobs that are run on behalf of developers, with elevated privileges, and Bashbot can trigger these actions via slack. Private slack channels can be used to restrict Bashbot commands to only those invited to the private channels, and the declarative configuration makes it easy to deploy as a scalable service. Bashbot provides an audit trail in slack, and via logs of the slack user that initiates each command, and allows users to trigger restricted commands, without elevating their privileges. I have used Bashbot to trigger CI-jobs (via `curl`), check status of cloud resources (via awscli), and execute scripts that would grant temporary access to production servers (via bash/python). Bashbot can be run as a go-binary or as a container with extra tools preinstalled that Bashbot can leverage when running commands. Bashbot uses a slash-command-like syntax to trigger commands `bashbot [command] [parameter1] [parameter2]` where commands and parameters must be explicitly defined in a configuration file, and contain no spaces or quotes.

<img src="https://i.imgur.com/s0cf2Hl.gif" />

[Read More...](blog/2021-08-1/bashbot.md)

---------------------------------------------------------------------

## [2021-07-02: Automatic asdf Dependency Updates](blog/2021-07-02/automatic-asdf-dependency-updates.md)

Keeping tools up to date and managing versions can be a little less painful with [the asdf version manager](https://asdf-vm.com/#/) and a github-action, on a cron schedule. Some useful tools are not available through the host package manager (apt), and remote environments sometimes require specific versions of these tools. I have posted about the asdf version manager in previously, and this modification expands on the [docker-dev-env](https://github.com/mathew-fleisch/docker-dev-env) project to check for new versions of dependencies listed in the asdf config, and builds a new container, if any dependency has a new version listed. The next time the docker-dev-env is requested, it will prompt the user to overwrite the existing container to apply these updates automatically.

[Read More...](blog/2021-07-02/automatic-asdf-dependency-updates.md)

---------------------------------------------------------------------

## [2021-05-17: Self-Hosted GitHub Action Runners On Self-Hosted Kubernetes Cluster](blog/2021-05-17/self-hosted-github-action-runners-on-self-hosted-kubernetes-cluster.md)

In this post, I will describe how I self-hosted Github Action runners on my home Raspberry pi k3s cluster, as my main method of continuous integration. I will use these runners to build and push multi-arch docker containers and go-binaries for all of my personal projects, going forward. To start, I followed [Jeff Geerling's k3s series](https://www.youtube.com/playlist?list=PL2_OBreMn7Frk57NLmLheAaSSpJLLL90G) to build the kubernetes cluster (using this [ansible playbook](https://github.com/k3s-io/k3s-ansible)), and installed the prometheus+grafana stack using a fork of the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) project by [Carlos Eduardo](https://carlosedp.medium.com/) called [cluster monitoring](https://github.com/carlosedp/cluster-monitoring). I then removed the cluster monitoring project because Prometheus took up too many resources for the pretty graphs and alerts to be worth the CPU cycles, in my two node k3s cluster. Next, I needed to build a container that would include any tools that I might use in automation, as well as the [Github Action runner agent](https://github.com/actions/runner), and host that container in a container registry (docker hub). Finally, I created a kubernetes deployment with the environment variables, the entry-point expects, and tested everything was working by rebuilding the runner's container.

<img src="https://i.imgur.com/Hj2cNJN.png" width="100%" />

[Read More...](blog/2021-05-17/self-hosted-github-action-runners-on-self-hosted-kubernetes-cluster.md)

---------------------------------------------------------------------

## [2021-04-07: Dev in a Can](blog/2021-04-07/dev-in-a-can.md)

For the past few years I have been using docker on my macs as a local development environment, rather than installing and maintaining tools directly on the mac itself. Essentially I only install Docker and my IDE of choice, and use docker for everything else. I will mount source code and private keys into a linux container that has all of the tools I might need, and from inside the container, I can run tools like terraform, helm and kubectl. This method can help align teammates on the same versions of tools, and the (likely) operating system the tools will be run on, in automation/CI. Using the [asdf version manager](https://asdf-vm.com/#/) can help when multiple versions of tools like terraform or kubectl are used in different environments. The tool provides methods to install multiple versions of select tools, and the ability to switch between versions of the same tool.

<img src="https://i.imgur.com/AGLznZ4.gif" width="100%" />

[Read More...](blog/2021-04-07/dev-in-a-can.md)

---------------------------------------------------------------------

## [2021-04-04: Tweet Via Github Actions](blog/2021-04-04/tweet-via-github-actions.md)

Github Actions are a really powerful (relatively) new tool for running continuous integration (CI) type automation. There are many published free actions to use on the [Github Actions Marketplace](https://github.com/marketplace?type=actions), but this post will instead focus on executing a custom shell script. The goal of this automation is that whenever I post a new blog post, I want github to automatically tweet that there is a new blog post on my personal twitter account. I will do another post on the go-binary that updates my twitter status, but this post will explain the usage. The process with twitter was the most elaborate experience I have ever had trying to acquire an key for an API. Once I had the api keys saved as github secrets I needed to post a twitter status update programmatically, I [forked](https://github.com/mathew-fleisch/twitter-action) a [repository](https://github.com/xorilog/twitter-action), and modified it to generate a [go-binary](https://github.com/mathew-fleisch/twitter-action/releases) that I could use in the github action I would use to automatically tweet. I then set up a github action to download and execute the go-binary on new git tags.

<img src="https://i.imgur.com/EOFv5VE.png" width="40%">

[Read More...](blog/2021-04-04/tweet-via-github-actions.md)

---------------------------------------------------------------------

## [2021-03-22: Automated Appointment Checker](blog/2021-03-22/automated-appointment-checker.md)

At this stage in the covid-19 pandemic, 25-30% of Americans have been vaccinated, starting with the most at-risk groups, and is now opening up to the general population. I just received my first dose now that I am eligible through my counties rules, but was having trouble finding an appointment at first. Local pharmacies are helping to administer the vaccines, and Walgreens is releasing batches of appointments, at random times throughout the day. Rather than clicking refresh over and over, to check for new appointments, I wanted to automate the process of checking for available appointments. All my script would need to do is alert me when there were any appointments at all, and I would pick the best time/location manually. I used a developer tool within the browser, Google Chrome, to isolate the request to Walgreen's server, that returns available appointment times in my area. Most of the time, the browser and this specific request would essentially return "no appointments available." This request contains "cookies" that are how Walgreen's server knows the request came from me, being logged in to the website. A feature of this browser tool allows you to "copy as cURL" to replay that same request in a terminal, including all of my Walgreens user's unique cookies. Wrapping that command in a 10 second loop allowed this script to alert me when the response changed from "no available appointments" to anything different. This script wouldn't need to decipher what appointments there were, just that there were any available appointments at all. I would then (and did) pick the specific appointments manually by jumping on the website as quickly as possible, after the alert triggered.

[Read More...](blog/2021-03-22/automated-appointment-checker.md)