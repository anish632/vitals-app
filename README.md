# Vita

Vita is a mobile-first wellness check-in app for iPhone. It includes:

- A daily readiness snapshot with heart rate, oxygen, blood pressure, energy, and restfulness cards.
- A camera check-in flow that requests the iPhone camera when the browser supports it.
- A real browser-side pulse estimate using camera-frame PPG signal processing.
- Personalized hydration and rest recommendations.
- Responsive layout sized for a phone screen and wider desktop previews.

## Run locally

Open `index.html` directly for a UI preview, or serve this folder locally:

```sh
python3 -m http.server 4173
```

Then visit `http://localhost:4173`. Camera access on an iPhone requires the deployed HTTPS URL (GitHub Pages), not a plain HTTP local-network address.

## Important product note

The camera pulse result is an estimate for personal trends, not a diagnosis. A phone camera should not be presented as a validated blood-pressure or blood-oxygen device; those cards intentionally remain unavailable until validated connected hardware is added. Sleep and energy history also need Apple Health or another authorized data source. A production health app needs consent and secure storage, extensive device testing, and appropriate medical-device and privacy review before making health claims.
