# 2021-04-04: Tweet Via Github Actions
[<- back](../../README.md)

Github Actions are a really powerful (relatively) new tool for running continuous integration (CI) type automation. There are many published free actions to use on the [Github Actions Marketplace](https://github.com/marketplace?type=actions), but this post will instead focus on executing a custom shell script. The goal of this automation is that whenever I post a new blog post, I want github to automatically tweet that there is a new blog post on my personal twitter account. I will do another post on the go-binary that updates my twitter status, but this post will explain the usage. The process with twitter was the most elaborate experience I have ever had trying to acquire an key for an API. Once I had the api keys saved as github secrets I needed to post a twitter status update programmatically, I [forked](https://github.com/mathew-fleisch/twitter-action) a [repository](https://github.com/xorilog/twitter-action), and modified it to generate a [go-binary](https://github.com/mathew-fleisch/twitter-action/releases) that I could use in the github action I would use to automatically tweet. I then set up a github action to download and execute the go-binary on new git tags.

## The Details

I searched the [Github Actions Marketplace](https://github.com/marketplace?type=actions) for an [existing action](https://github.com/marketplace/actions/twitter-action) that would do what I wanted it to do, but I wanted a go-binary to test and use outside of the github-action itself. So, I [forked](https://github.com/mathew-fleisch/twitter-action) [this repository](https://github.com/xorilog/twitter-action), and added a github-action that would build the go-binary and save it as a release artifact anytime a new git tag was pushed, as well as build/push a container to [my docker hub account](https://hub.docker.com/u/mathewfleisch/twitter-action/tags?page=1&ordering=last_updated). Usage of the go-binary to update a twitter status (tweet) would look like this:

```
export TWITTER_CONSUMER_KEY=xxx
export TWITTER_CONSUMER_SECRET=xxx
export TWITTER_ACCESS_TOKEN=xxx
export TWITTER_ACCESS_SECRET=xxx
./twitter-action -message "Hello Twitter :)"
```

**Trigger**

The repository has five tokens saved as github secrets that are used in the [Github Action](../../.github/workflows/tweet-new-blog-post.yaml) to access the github and twitter APIs. There are three main sections of a github action yaml file: the trigger, environment set up, and the actual scripts that are run. In this first section, the trigger is defined to run anytime a tag is pushed that starts with the letter 'v'.

```
name: Tweet New Blog Post
on:
  push:
    tags:
      - 'v*'
```

**Environment Setup**

This next section defines what system type the code will run on (ubuntu-latest), as well as setting github secrets to environment variables.


```
jobs:
  build:
    name: Tweet New Blog Post
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Tweet New Blog Post
        env:
          TWITTER_CONSUMER_KEY: ${{ secrets.TWITTER_CONSUMER_KEY }}
          TWITTER_CONSUMER_SECRET: ${{ secrets.TWITTER_CONSUMER_SECRET }}
          TWITTER_ACCESS_TOKEN: ${{ secrets.TWITTER_ACCESS_TOKEN }}
          TWITTER_ACCESS_SECRET: ${{ secrets.TWITTER_ACCESS_SECRET }}
          GIT_TOKEN: ${{ secrets.GIT_TOKEN }}
```

**Custom script**

This final section will run some bash to test if the proper environment variables have been set, download the tweet go-binary from github, and execute it using the commit message of the git tag.

```
        run: |
          twitter_action_tag=v1.0.1
          echo "Check environment variables are set..."
          expected="TWITTER_CONSUMER_KEY TWITTER_CONSUMER_SECRET TWITTER_ACCESS_TOKEN TWITTER_ACCESS_SECRET GIT_TOKEN"
          for expect in $expected; do
            if [[ -z "${!expect}" ]]; then
              echo "Missing Github Secret: $expect"
              echo "See read-me about automation to set this up in your fork"
              exit 1
            fi
          done
          echo "git fetch --prune --unshallow (to make sure all tags are downloaded to action)"
          git fetch --prune --unshallow
          tag=$(git describe --tags)
          commit_message="$(git for-each-ref refs/tags/$tag --format='%(contents)' | head -n1)"
          echo "Pull twitter-action: $twitter_action_tag"
          curl -sL -H "Authorization: token $GIT_TOKEN" \
            "https://api.github.com/repos/mathew-fleisch/twitter-action/releases/tags/$twitter_action_tag" \
            | jq -r '.assets[] | select(.name == "twitter-action").browser_download_url' \
            | xargs -I {} curl -sL -H "Authorization: token $GIT_TOKEN" -H "Accept:application/octet-stream" -O {}
          chmod +x twitter-action
          ./twitter-action -message "New blog post: $commit_message"
```

**Usage**

Running the following code triggered the automation to tweet the commit message and a link back to the blog.

```
git add blog
git commit -m "Automated Tweeting via Github Actions"
git push origin main
git tag v1.0.20210404
git push origin v1.0.20210404
```
**Github Action Console Output**

<img src="https://i.imgur.com/NeCJmWo.png" width="%100">

**Tweet**

<img src="https://i.imgur.com/EOFv5VE.png" width="40%">
