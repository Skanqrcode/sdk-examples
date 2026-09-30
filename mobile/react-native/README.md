# SkanQRCode React Native example

Single-screen QR scanner that gates opening a scanned URL on a `/v1/check` verdict, using
[`react-native-vision-camera`](https://github.com/mrousavy/react-native-vision-camera)'s
built-in code scanner. See [../../docs/api-contract.md](../../docs/api-contract.md) for the
full API contract and [../../sdk/javascript](../../sdk/javascript) for the `skanqrcode` client
used here.

## Install

```bash
npm install react-native-vision-camera skanqrcode
```

Follow `react-native-vision-camera`'s [installation guide](https://react-native-vision-camera.com/docs/guides)
for the native camera permission setup (`Info.plist` / `AndroidManifest.xml`).

## Usage

Drop `ScannerScreen.jsx` into your navigator:

```jsx
import ScannerScreen from './ScannerScreen';

<Stack.Screen name="Scanner" component={ScannerScreen} />;
```

Set `SKANQRCODE_API_KEY` via your usual RN env mechanism (e.g. `react-native-dotenv`, EAS
secrets) — see the comment in `ScannerScreen.jsx` for where it's read.

## Action handling

The screen branches on the `action` field of the `/v1/check` response:

- `allow` — opens the link immediately.
- `warn` — shows a modal with "Open anyway" / "Cancel".
- `block` — shows a hard-block alert with the reason codes; no way to proceed.
- Network/timeout/API error — fails closed: never auto-opens, prompts the user to decide
  instead of silently treating an unknown result as safe.

Use an `sk_test_` key (sandbox) while integrating and an `sk_live_` key in production.
Sandbox results come back with `licensedForProduction: false`; treat them as test output only.
