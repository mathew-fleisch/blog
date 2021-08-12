# 2021-08-11: Bashbot

[<- back](../../README.md)

[Bashbot](https://github.com/mathew-fleisch/bashbot) is a chat-ops tool I built, to automate tasks that are common to infrastructure/devops teams. There are often scripts or CI (continuous integration) jobs that are run on behalf of developers, with elevated privileges, and Bashbot can trigger these actions via slack. Private slack channels can be used to restrict Bashbot commands to only those invited to the private channels, and the declarative configuration makes it easy to deploy as a scalable service. Bashbot provides an audit trail in slack, and via logs of the slack user that initiates each command, and allows users to trigger restricted commands, without elevating their privileges. I have used Bashbot to trigger CI-jobs (via `curl`), check status of cloud resources (via awscli), and execute scripts that would grant temporary access to production servers (via bash/python). Bashbot can be run as a go-binary or as a container with extra tools preinstalled that Bashbot can leverage when running commands. Bashbot uses a slash-command-like syntax to trigger commands `bashbot [command] [parameter1] [parameter2]` where commands and parameters must be explicitly defined in a configuration file, and contain no spaces or quotes.

<img src="https://i.imgur.com/s0cf2Hl.gif" />

## The Details

After configuring Bashbot to run in a slack workspace, a socket connection ([RTM](https://api.slack.com/rtm)) provides Bashbot with a stream of text, in every channel it is a member of. Bashbot uses regular expressions on each message, to determine if a command should be executed, and ignores normal chat. When Bashbot detects a command sequence, it will execute a command, corresponding to the configuration for that command. The configuration for each command is saved a json object that defines how it is triggered, what parameters there might be, a location to run the command, and the command itself. 

<img src="https://i.imgur.com/w3wouOR.gif" />

```json
{
  "name": "Get Latest Bashbot Version",
  "description": "Returns the latest version of Bashbot via curl",
  "help": "bashbot latest-release",
  "trigger": "latest-release",
  "location": "./",
  "setup": "latest_version=$(curl -s https://api.github.com/repos/mathew-fleisch/bashbot/releases/latest | grep tag_name | cut -d '\"' -f 4)",
  "command": "echo \"The latest version of <https://github.com/mathew-fleisch/bashbot|Bashbot>: <https://github.com/mathew-fleisch/bashbot/releases/tag/$latest_version|$latest_version>\"",
  "parameters": [],
  "log": false,
  "ephemeral": false,
  "response": "text",
  "permissions": ["all"]
}
```

 In this [example](https://github.com/mathew-fleisch/bashbot/tree/main/examples/latest-release), a slack user would type `bashbot latest-release` to trigger the command. The command essentially uses `curl` to get the latest release-tag from the Github API and formats a message containing that version/tag in a link. Unpacking this configuration a bit:

- The `name`, `description` and `help` fields, are messages that can display to the user.
- The `trigger` field is used as the main entry-point to trigger the command.
- The `location` field is used to run scripts from specific filepaths on the host system.
- The `setup` and `command` fields are passed to bash where the command would only run after setup completes successfully. In this case:
	- A bash variable `latest_version` is set in the `setup` field, by executing `latest_version=$(curl -s https://api.github.com/repos/mathew-fleisch/bashbot/releases/latest | grep tag_name | cut -d '\"' -f 4)`
	-  The bash variable set in the `setup` stage, is then used in the `command` in an `echo` command `echo \"The latest version of <https://github.com/mathew-fleisch/bashbot|Bashbot>: <https://github.com/mathew-fleisch/bashbot/releases/tag/$latest_version|$latest_version>\"`
			-  Note 1: Quotes are escaped because it is saved as a string in a json object
			-  Note 2: Slack's syntax for formatting links: `<url|My link>`
- The `parameters` section define valid parameters to each Bashbot command, and in this case, the command takes no parameters.
- The `log` flag will define an audit trail (or not) for those who executes each command and what the output was.
- The `ephemeral` flag will send back any output as an ephemeral message to the user who executed it, and not the channel (default). Useful for sending back credentials, passwords or tokens.
- The `response` field accepts two possible values: `text` or `code`
	- The `text` option will send back the `STDOUT` of the `setup` and `command` fields as raw text
	- The `code` option will send back the `STDOUT` of the `setup` and `command` fields formatted as a code block
- The `permissions` field defines an array of channel ids where specific commands can be restricted to. 

In the [previous example](https://github.com/mathew-fleisch/bashbot/tree/main/examples/latest-release), the command provides a quick way to get up-to-date-information from an external resource. Parameters can be hard-coded values or built from the output of another command. These next two examples work in tandem for lists of key/value pairs. The first [example](https://github.com/mathew-fleisch/bashbot/tree/main/examples/list) `bashbot list` will list the available commands, and the [second](https://github.com/mathew-fleisch/bashbot/tree/main/examples/describe) `bashbot describe [command]` will use that list to validate a secondary parameter 	`[command]`.

```json
{
  "name": "List Available Bashbot Commands",
  "description": "List all of the possible commands stored in bashbot",
  "help": "bashbot list",
  "trigger": "list",
  "location": "./",
  "setup": "echo \"\"",
  "command": "jq -r '.tools[] | .trigger' ${BASHBOT_CONFIG_FILEPATH}",
  "parameters": [],
  "log": false,
  "ephemeral": false,
  "response": "code",
  "permissions": ["all"]
}
```

Running `bashbot list` will use the command-line tool `jq` to pull out all of the `.tools[].trigger` values into a list and look something like

```
help  
info  
list  
describe  
version  
ping  
latest-release  
trigger-github-action
```

<img src="https://i.imgur.com/HHzHlFK.gif" />

The companion command to the `bashbot list` command is `bashbot describe [command]` and uses the list command to build a list of valid parameters for the `[command]` value. Running `bashbot describe describe` would display itself:

```json
{
  "name": "Describe Bashbot [command]",
  "description": "Show the json object for a specific command",
  "help": "bashbot describe [command]",
  "trigger": "describe",
  "location": "./",
  "setup": "echo \"\"",
  "command": "jq '.tools[] | select(.trigger==\"${command}\")' ${BASHBOT_CONFIG_FILEPATH}",
  "parameters": [
    {
      "name": "command",
      "allowed": [],
      "description": "a command to describe ('bashbot list')",
      "source": "jq -r '.tools[] | .trigger' ${BASHBOT_CONFIG_FILEPATH}"
    }
  ],
  "log": false,
  "ephemeral": false,
  "response": "code",
  "permissions": ["all"]
}
```

<img src="https://i.imgur.com/bQZKRjX.gif" />

When a user triggers any command, the slack user id and channel id can be used in scripts and a `curl` can also be used to trigger CI jobs (jenkins, Github actions etc). In the next [example](https://github.com/mathew-fleisch/bashbot/tree/main/examples/github-action), a Github action job (similar process for jenkins jobs) is triggered when a user types `bashbot trigger-github-action` Metadata about the user that triggers that command is used ***within the job*** to send a message back to the user upon success/failure. 

```json
{
  "name": "Trigger a Github Action",
  "description": "Triggers an example Github Action job by repository dispatch",
  "help": "bashbot trigger-github-action",
  "trigger": "trigger-github-action",
  "location": "./examples/github-action",
  "setup": "export REPO_OWNER=mathew-fleisch && export REPO_NAME=bashbot && export SLACK_CHANNEL=${TRIGGERED_CHANNEL_ID} && export SLACK_USERID=${TRIGGERED_USER_ID}",
  "command": "./trigger.sh",
  "parameters": [],
  "log": false,
  "ephemeral": false,
  "response": "text",
  "permissions": ["all"]
}
```

There are two scripts associated with this Bashbot command: [trigger.sh](https://github.com/mathew-fleisch/bashbot/blob/main/examples/github-action/trigger.sh) and [github-action.sh](https://github.com/mathew-fleisch/bashbot/blob/main/examples/github-action/github-action.sh). The`trigger.sh` script sends off a POST request via `curl` to the repository's dispatch function, to trigger a Github action. The [github-action](../.github/workflows/example-bashbot-github-action.yaml) uses the `github-action.sh` script to simulate a long running job, and return back status to slack via Bashbot binary.

***trigger.sh*** - This script is used to trigger the Github action.

```bash
curl -s \
  -X POST \
  -H "Accept: application/vnd.github.everest-preview+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  --data '{"event_type":"trigger-github-action","client_payload": {"channel":"'${SLACK_CHANNEL}'", "user_id": "'${SLACK_USERID}'"}}' \
  "https://${github_base}/repos/${REPO_OWNER}/${REPO_NAME}/dispatches"

```

***github-action.sh*** - Within the github action, the Bashbot binary can used to send back status information about the job, at any point in the job.

```bash
# Do a devops
./bashbot \
    --send-message-channel ${SLACK_CHANNEL} \
    --send-message-text "<@${SLACK_USERID}> Bashbot triggered this job"
```

<img src="https://i.imgur.com/s0cf2Hl.gif" />

I've used this method to trigger "on-demand" cloud development environments for developers to test new changes. Bashbot would trigger a CI job that would build out a cloud environment, using the slack username that triggered the command as a sub-domain for the developer to use as an entry-point into their environment: `[slack-username].dev.[company].com` After a developer's environment was up and running, they would get a DM with credentials/passwords and could test new-features/bug-fixes in a production-like environment. Developers could build, destroy, and check status of their personalized cloud infrastructure with separate Bashbot commands.

I've also used this method to trigger security scans on containers, run terraform, run kubectl commands, and download/execute files from private repositories. Bashbot is not a replacement for a CI system, but can bridge the gap between Slack and privileged jobs, while providing an audit trail of commands and using Slack's private channels to restrict commands. 

Read more [Bashbot](https://github.com/mathew-fleisch/bashbot) commands examples at:
[https://github.com/mathew-fleisch/bashbot/tree/main/examples](https://github.com/mathew-fleisch/bashbot/tree/main/examples)