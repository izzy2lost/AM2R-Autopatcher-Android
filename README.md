# AM2R-Autopatcher-Android
A repository containing patch data and scripts in order to automatically install the latest AM2R Community Updates on Android via Termux.

### You must have the AM2R_11.zip (case sensitive) in your downloads directory ###

### How to use
Open up Termux and execute the following command to install the latest Community Updates:  

AM2R 1.5.5

```
pkg install -y wget && wget -O patcher.sh https://github.com/izzy2lost/AM2R-Autopatcher-Android/raw/main/patcher.sh && chmod +x patcher.sh && ./patcher.sh
```

Multitroid, unofficial version:
```
pkg install -y wget && wget -O multitroid.sh https://github.com/izzy2lost/AM2R-Autopatcher-Android/raw/main/multitroid.sh && chmod +x multitroid.sh && ./multitroid.sh
```

