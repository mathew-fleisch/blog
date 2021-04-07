# Mathew's Blog

My name is Mathew Fleisch, and I am a programmer and musician from the bay area in California. I started out as a developer and in the past few years shifted to infrastructure/devops. I love creating automation and optimizing automation pipelines. I will use this "blog" to share stories, experiences and I am starting in March of 2021, in the midst of the global coronavirus pandemic.

---------------------------------------------------------------------

## [2021-04-07: Dev in a Can](blog/2021-04-07/dev-in-a-can.md)

For the past few years I have been using docker on my macs as a local development environment, rather than installing and maintaining tools directly on the mac itself. Essentially I only install Docker and my IDE of choice, and use docker for everything else. I will mount source code and private keys into a linux container that has all of the tools I might need, and from inside the container, I can run tools like terraform, helm and kubectl. This method can help align teammates on the same versions of tools, and the (likely) operating system the tools will be run on, in automation/CI. Using the [asdf version manager](https://asdf-vm.com/#/) can help when multiple versions of tools like terraform or kubectl are used in different environments. The tool provides methods to install multiple versions of select tools, and the ability to switch between versions of the same tool.

<img src="https://i.imgur.com/AGLznZ4.gif" width="100%" />

---------------------------------------------------------------------

## [2021-04-04: Tweet Via Github Actions](blog/2021-04-04/tweet-via-github-actions.md)

Github Actions are a really powerful (relatively) new tool for running continuous integration (CI) type automation. There are many published free actions to use on the [Github Actions Marketplace](https://github.com/marketplace?type=actions), but this post will instead focus on executing a custom shell script. The goal of this automation is that whenever I post a new blog post, I want github to automatically tweet that there is a new blog post on my personal twitter account. I will do another post on the go-binary that updates my twitter status, but this post will explain the usage. The process with twitter was the most elaborate experience I have ever had trying to acquire an key for an API. Once I had the api keys saved as github secrets I needed to post a twitter status update programmatically, I [forked](https://github.com/mathew-fleisch/twitter-action) a [repository](https://github.com/xorilog/twitter-action), and modified it to generate a [go-binary](https://github.com/mathew-fleisch/twitter-action/releases) that I could use in the github action I would use to automatically tweet. I then set up a github action to download and execute the go-binary on new git tags.

<img src="https://i.imgur.com/EOFv5VE.png" width="40%">

[Read More...](blog/2021-04-04/tweet-via-github-actions.md)

---------------------------------------------------------------------

## [2021-03-22: Automated Appointment Checker](blog/2021-03-22/automated-appointment-checker.md)

At this stage in the covid-19 pandemic, 25-30% of Americans have been vaccinated, starting with the most at-risk groups, and is now opening up to the general population. I just received my first dose now that I am eligible through my counties rules, but was having trouble finding an appointment at first. Local pharmacies are helping to administer the vaccines, and Walgreens is releasing batches of appointments, at random times throughout the day. Rather than clicking refresh over and over, to check for new appointments, I wanted to automate the process of checking for available appointments. All my script would need to do is alert me when there were any appointments at all, and I would pick the best time/location manually. I used a developer tool within the browser, Google Chrome, to isolate the request to Walgreen's server, that returns available appointment times in my area. Most of the time, the browser and this specific request would essentially return "no appointments available." This request contains "cookies" that are how Walgreen's server knows the request came from me, being logged in to the website. A feature of this browser tool allows you to "copy as cURL" to replay that same request in a terminal, including all of my Walgreens user's unique cookies. Wrapping that command in a 10 second loop allowed this script to alert me when the response changed from "no available appointments" to anything different. This script wouldn't need to decipher what appointments there were, just that there were any available appointments at all. I would then (and did) pick the specific appointments manually by jumping on the website as quickly as possible, after the alert triggered.

[Read More...](blog/2021-03-22/automated-appointment-checker.md)