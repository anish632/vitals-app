# Vita

Vita is a mobile-first wellness check-in prototype for iPhone. It includes:

- A daily readiness snapshot with heart rate, oxygen, blood pressure, energy, and restfulness cards.
- A camera check-in flow that requests the iPhone camera when the browser supports it.
- A guided scan state with progress feedback and refreshed sample measurements.
- Personalized hydration and rest recommendations.
- Responsive layout sized for a phone screen and wider desktop previews.

## Run locally

Open `index.html` directly for the UI, or serve this folder from a local HTTPS/static server so the browser can request camera permission:

```sh
python3 -m http.server 4173
```

Then visit `http://localhost:4173`.

## Important product note

The current readings are intentionally sample wellness values. A phone camera can support experimental pulse/PPG-style experiences, but it should not be presented as a validated blood-pressure or blood-oxygen device. A production version should use Apple Health and/or validated connected hardware, add consent and secure storage, and go through appropriate medical-device and privacy review before making health claims.
