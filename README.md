# IADAUDIT

IADAUDIT: a tool for auditing ads in iOS apps against abusive practices

**Project Files**:

- This repository contains the following files:
  - Ad_Interaction_Simulator: Source code for simulating app interactions to trigger and monitor ad displays.
  - Ad_Traffic_Interceptor: Source code for collecting and analyzing in-app ad network traffic.
  - Abusive_Ad_Practice_Detector:  Module for detecting and classifying various abusive ad practices.
  - AppCrawer: Tools for automating app downloads and scraping metadata from the App Store.
  - Dataset: Contains the bundle IDs of 6,322 apps used in the experiment.
  - ViolatingVideoAdInKidsApp.mp4: Example of a sexually suggestive ad found in a children's app.

---

## A Sexually Suggestive Ad Found in Children's app

This ad can be viewed in this https://youtu.be/ke8wMB6xB0g or [IADAUDIT/ViolatingVideoAdInKidsApp.mp4 at main · IADAUDIT/IADAUDIT (github.com)](https://github.com/IADAUDIT/IADAUDIT/blob/main/ViolatingVideoAdInKidsApp.mp4). It appeared in a children's gaming app, featuring inappropriate content delivered through AdMob, falsely promoting a TV casting app with sexually suggestive material.

## AppCrawler

We used [ipatool-py](https://github.com/NyaMisty/ipatool-py) to download apps from the App Store to build our dataset, while using [app-store-scraper](https://github.com/facundoolano/app-store-scraper) to scrape app metadata.

## Ad Interaction Simulator

This module is responsible for dynamically running the app, monitoring ad loading, and simulating user interactions with ads to trigger advertised content. We modified a simplified version of the iOS testing tool [Cydios](https://github.com/SoftWare2022Testing/CydiOS). To run this module, you need a jailbroken iPhone. After jailbreaking, install some tweaks in the cydia:

1. OpenSSH
2. Substrate Safe mode
3. Theos Dependencies

To install our iPhone extension, run the following commands in a termnial window (the computer should connect to the same local netwrok with the iphone ):

```
cd Ad_Interaction_Simulator
make package
make install
```

note that

1. you should specify the bundle ID of the test app in **travseiosapp.plist**
2. you should change the ip address of the iPhone in **Makefile**, like THEOS_DEVICE_IP = 172.19.193.18

## Ad Traffic Interceptor

This module captures and analyzes network traffic related to in-app advertising by instrumenting network APIs on iOS. It leverages Frida to hook into specific API calls and mitmproxy to intercept and inspect the traffic, providing a comprehensive view of the ad-related data flow.

## Abusive Ad Practice Detector

This module leverages the ad contents collected from the previous two modules to identify and classify various abusive ad practices based on predefined criteria and heuristics. It mainly contains three parts:

- gpt.py: Leverages large language models (LLMs) to analyze ad widget screenshots and detect deceptive or disruptive elements.
- googleCloud.py: Uses the Google Cloud Vision API's SafeSearch Detection feature to identify explicit content in ad multimedia files.
- virustotal.py: Integrates with VirusTotal to analyze URLs linked in app ads, detecting malicious web pages.