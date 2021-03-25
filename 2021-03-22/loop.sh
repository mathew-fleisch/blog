#!/bin/bash
# shellcheck disable=SC2086

usage="./loop.sh [sample-env]"
dotenv="${1:-./.env}"
starting=$(pwd)
if ! [[ -f "$dotenv" ]]; then
  echo "Missing env file"
  echo "Usage: $usage"
  exit 1
fi
source $dotenv
if [[ -z "$SLACK_TOKEN" ]]; then
  echo "Missing SLACK_TOKEN environment variable."
  echo "Usage: $usage"
  exit 1
fi
if [[ -z "$target_channel" ]]; then
  echo "Missing target_channel environment variable."
  echo "Usage: $usage"
  exit 1
fi
if [[ -z "$notify_user" ]]; then
  echo "Missing notify_user environment variable."
  echo "Usage: $usage"
  exit 1
fi


function getLocations() {
  words=$1
  for row in "$(echo $words | jq -c '.locations[]')"; do
    address="$(echo $row | jq -r '.address.line1'), $(echo $row | jq -r '.address.city')"
    phone="$(echo $row | jq -r '.phone[0].number')"
    manufacturer="$(echo $row | jq -r '.manufacturer[0].name')"
    appointment_count="$(echo $row | jq -c '.appointmentAvailability[]' | wc -l)"
    appointment_label="$(echo $appointment_count) appointments"
    if [[ $appointment_count -eq 1 ]]; then
      appointment_label="$(echo $appointment_count) appointment"
    fi
    echo "$manufacturer | $appointment_label | $address | $phone"
  done
}


MESSAGE="Starting appointment checker: $(date)"
echo "$MESSAGE"
curl -s -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer '$SLACK_TOKEN \
  -d '{"text": "'" $MESSAGE"'", "channel": "'$target_channel'"}' \
  https://slack.com/api/chat.postMessage > /dev/null

compare=$(./request.sh)
if [[ -z "$compare" ]]; then
  MESSAGE="<@$notify_user> Must log in again..."
  echo "$MESSAGE"
  curl -s -X POST \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$SLACK_TOKEN \
    -d '{"text": "'" $MESSAGE"'", "channel": "'$target_channel'"}' \
    https://slack.com/api/chat.postMessage > /dev/null
  exit 1
fi
echo
while true; do
  raw=$(./request.sh)
  if [[ "$raw" != "$compare" ]]; then
    regex="participating|Insufficient"
    if [[ ! $raw =~ $regex ]]; then
      if [[ -z "$raw" ]]; then
        MESSAGE="<@$notify_user> Must log in again..."
        echo "$MESSAGE"
        curl -s -X POST \
          -H 'Content-Type: application/json' \
          -H 'Authorization: Bearer '$SLACK_TOKEN \
          -d '{"text": "'" $MESSAGE"'", "channel": "'$target_channel'"}' \
          https://slack.com/api/chat.postMessage > /dev/null
        exit 1
      fi
      pretty=$(echo "$raw" | jq '.')
      echo "$pretty"
      count=$(echo "$raw" | jq -c '.locations[]' | wc -l)
      echo
      echo
      MESSAGE="<@$notify_user> https://www.walgreens.com/findcare/vaccination/covid-19/appointment/next-available"
      echo "$MESSAGE"
      curl -s -X POST \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer '$SLACK_TOKEN \
        -d '{"text": "'" $MESSAGE"'", "channel": "'$target_channel'"}' \
        https://slack.com/api/chat.postMessage
      MESSAGE=$(getLocations "$raw")
      echo "$MESSAGE"
      curl -s -X POST \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer '$SLACK_TOKEN \
        -d '{"text": "'" $MESSAGE"'", "channel": "'$target_channel'"}' \
        https://slack.com/api/chat.postMessage
    fi
  fi
  echo "$(date) - No Appointments Available: $raw"
  sleep 10
done
