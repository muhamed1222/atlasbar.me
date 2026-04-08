# LimitBar Promo Site

Standalone static promo page for LimitBar.

## Purpose

This folder contains the one-screen marketing page for LimitBar. It is intentionally separate from the Swift app code in `LimitBar/`.

## Files

- `index.html` — semantic page structure and outbound links
- `styles.css` — layout, color tokens, button styling, theme rules, and reveal motion
- `script.js` — theme persistence and reveal activation
- `assets/` — local static assets if the promo page later needs an icon or OG image

## Run locally

```bash
cd website
python3 -m http.server 4173
```

Open `http://localhost:4173`.

## Editing rules

- Keep the page one-screen and one-section only
- Do not add feature grids or extra marketing sections
- Keep `Download for macOS` as the primary CTA
- Keep `Rate & Review` as the secondary CTA

## Download routing

- The primary CTA points to `/download/macos`
- Netlify redirects `/download/macos` to the latest GitHub Release asset
- The release asset name must stay exactly `LimitBar-macOS.zip`
