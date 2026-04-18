# iPhone Testing Guide

## 1) Fast start (recommended)

```bash
cd /Users/centr/Desktop/gaussian
./scripts/start_iphone_backend.sh
```

Script prints ready-to-use URL, for example:

- `http://192.168.1.25:8000`
- `http://192.168.1.25:8000/docs`

Use the first value in Xcode as `GAUSSIAN_API_BASE_URL`.

## 2) If script cannot detect IP (rare)

```bash
ipconfig getifaddr en0
```

Then run:

```bash
MAC_IP=<YOUR_MAC_IP> ./scripts/start_iphone_backend.sh
```

## 3) Prepare iOS app in Xcode

- Create an iOS App project and copy files from `ios/GaussianScanMVP`.
- In target settings, set Deployment Target iOS 16+.
- Add `GAUSSIAN_API_BASE_URL` in Scheme > Run > Arguments > Environment:
  - `http://<YOUR_MAC_IP>:8000`
- If using HTTP in dev, add ATS exception in `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

- Add local network usage description in `Info.plist` (required on real device for LAN access):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>App uses local network to connect to your Mac backend during testing.</string>
```

- For WKWebView + remote module loading (Gaussian splat renderer), allow web content networking:

```xml
<key>NSAllowsArbitraryLoadsInWebContent</key>
<true/>
```

- If Xcode shows `@main attribute can only apply to one type in a module`, remove the default generated app file (for example `gaussianApp.swift`) and keep only `App/GaussianScanMVPApp.swift`.

## 4) Run on physical iPhone

- Connect iPhone via cable or enable wireless debugging.
- Select your Apple Team in Signing & Capabilities.
- Choose iPhone device and run app from Xcode.

## 5) Manual test scenario

1. Open `Capture` tab.
2. Tap `Select Real Photos` and choose several images from gallery.
3. Tap `Create Job and Upload Photos`.
4. Verify request completes and app shows `status: done`.
5. Check artifact link appears and is non-empty.

## 6) Troubleshooting

- If request fails: verify iPhone and Mac are on same Wi-Fi network.
- If error says `Local network prohibited`, open iPhone `Settings -> Privacy & Security -> Local Network` and enable access for your app.
- If timeout: check macOS firewall allows Python/uvicorn incoming connections.
- If decode error: inspect backend logs for response body or status code.
- If reconstruction fails, app returns `failure_reason` and `status_message` in `/jobs` response.
