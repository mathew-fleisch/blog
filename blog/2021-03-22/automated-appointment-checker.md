
# 2021-03-22: Automated Appointment Checker
[<- back](../../README.md)

At this stage in the covid-19 pandemic, 25-30% of Americans have been vaccinated, starting with the most at-risk groups, and is now opening up to the general population. I just received my first dose now that I am eligible through my counties rules, but was having trouble finding an appointment at first. Local pharmacies are helping to administer the vaccines, and Walgreens is releasing batches of appointments, at random times throughout the day. Rather than clicking refresh over and over, to check for new appointments, I wanted to automate the process of checking for available appointments. All my script would need to do is alert me when there were any appointments at all, and I would pick the best time/location manually. I used a developer tool within the browser, Google Chrome, to isolate the request to Walgreen's server, that returns available appointment times in my area. Most of the time, the browser and this specific request would essentially return "no appointments available." This request contains "cookies" that are how Walgreen's server knows the request came from me, being logged in to the website. A feature of this browser tool allows you to "copy as cURL" to replay that same request in a terminal, including all of my Walgreens user's unique cookies. Wrapping that command in a 10 second loop allowed this script to alert me when the response changed from "no available appointments" to anything different. This script wouldn't need to decipher what appointments there were, just that there were any available appointments at all. I would then (and did) pick the specific appointments manually by jumping on the website as quickly as possible, after the alert triggered.

<img src="https://i.imgur.com/E8zUbob.gif">

## The Details

There are many tools to isolate the requests going back and forth between you, the client, and servers "in my butt." Most modern browsers can show you this information, and in this case, I used [Chrome's DevTools](https://developers.google.com/web/tools/chrome-devtools) to copy the specific request that was checking for available appointments in the network tab. Once I found the request that was returning information about no appointments, I used "copy as cURL" to replay that request in a terminal. I pasted the cURL command into a .sh file to make it easier to manipulate, and automate. There are two scripts to this method: One to hold the cURL command that contains my logged in credentials in the form of cookies, and another to contain the loop logic. I separated the cURL command because I would get logged out of their website, and need to log back in, and re-copy the cURL command again. The loop logic calls the request script, and compares the result to the first time it was called. If request's response changes at all, the alert is triggered, and since the script was run on a mac, would play noises through the speakers from the `say` and `open` commands.

**Note: Some information has been redacted/altered for security purposes**

<img src="https://i.imgur.com/vBG8nem.png">

<img src="https://i.imgur.com/gr68eTS.png">

**request.sh**

One minor modification I've made to the cURL that comes from chrome is to replace "--compressed" flag with "-s" flag. The curl should not be compressed to analyze the response as plain text, and the silent flag will omit meta-data about the request process itself (remove the silent flag to debug the curl request).  

```
curl 'https://www.walgreens.com/hcschedulersvc/svc/v2/immunizationLocations/timeslots' \
  -s \
  -H 'authority: www.walgreens.com' \
  -H 'sec-ch-ua: "Google Chrome";v="89", "Chromium";v="89", ";Not A Brand";v="99"' \
  -H 'accept: application/json, text/plain, */*' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'user-agent: REDACTED' \
  -H 'transactionid: REDACTED' \
  -H 'content-type: application/json; charset=UTF-8' \
  -H 'origin: https://www.walgreens.com' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-dest: empty' \
  -H 'referer: https://www.walgreens.com/findcare/vaccination/covid-19/appointment/next-available' \
  -H 'accept-language: en-US,en;q=0.9,la;q=0.8' \
  -H 'cookie: REDACTED' \
  --data-raw '{"position":{"latitude":37.768772,"longitude":-122.475971},"state":"CA","vaccine":{"productId":""},"appointmentAvailability":{"startDateTime":"2021-03-22"},"radius":25,"size":25,"serviceId":"99"}'
```

**example request payload (pretty)**
```
{
  "position": {
    "latitude": 37.768772,
    "longitude": -122.475971
  },
  "state": "CA",
  "vaccine": {
    "productId": ""
  },
  "appointmentAvailability": {
    "startDateTime": "2021-03-22"
  },
  "radius": 25,
  "size": 25,
  "serviceId": "99"
}
```


**loop.sh**

```
#!/bin/bash
compare=$(./request.sh)
while true; do
  raw=$(./request.sh)
  if [[ "$raw" != "$compare" ]]; then
      sayThis="THERE ARE APPOINTMENTS AVAILABLE"
      echo "$sayThis"
      say "$sayThis"
      open -a "Google Chrome" "https://www.youtube.com/watch?v=bxqLsrlakK8"
      exit 0
    fi
  fi
  echo "$(date) - No Appointments Available: $raw"
  sleep 10
done
```


## Revisions

I have modified this script to notify slack when action needs to be taken. To run these scripts, you will need a slack token, channel and user id added to the sample-env file for it to work. 
 - [sample-env](sample-env)
 - [request.sh](request.sh)
 - [loop.sh](loop.sh)
