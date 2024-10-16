# IADAUDIT

IADAUDIT: a tool for auditing ads in iOS apps against abusive practices

---

## AppCrawler

We used [ipatool-py]([NyaMisty/ipatool-py: IPATool-py: download ipa easily (github.com)](https://github.com/NyaMisty/ipatool-py)) to download apps from the App Store to build our dataset, while using [app-store-scraper]([facundoolano/app-store-scraper: scrape data from the itunes app store (github.com)](https://github.com/facundoolano/app-store-scraper)) to scrape app metadata.

## Ad Interaction Simulator

This module is responsible for dynamically running the app, monitoring ad loading, and simulating user interactions with ads to trigger advertised content. We modified a simplified version of the iOS testing tool [Cydios]([SoftWare2022Testing/CydiOS: CydiOS: a model-based testing framework for iOS apps (github.com)](https://github.com/SoftWare2022Testing/CydiOS)). To run this module, you need a jailbroken iPhone. After jailbreaking, install some tweaks in the cydia:

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



---

- ViolatingVideoAdInKidsApp.mp4: This video was from an ad in a children's gaming app, which featured inappropriate content delivered through AdMob, falsely promoting a TV casting app with sexually suggestive material.