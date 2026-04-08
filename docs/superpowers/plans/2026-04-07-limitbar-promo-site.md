# LimitBar Promo Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone one-screen promo page for LimitBar in `website/` that matches the approved editorial-minimal direction and is fully isolated from the Swift app code.

**Architecture:** Implement the page as a plain static site with one HTML entrypoint, one CSS stylesheet, one small JavaScript file, and optional local assets. Keep all product messaging and visual structure inside a single centered hero block, with theme switching and restrained motion layered on top without introducing any framework or build step.

**Tech Stack:** Static HTML, CSS, vanilla JavaScript, local asset files, Python `http.server` for local verification

---

## File Map

### New Files

- `website/index.html` — semantic one-page promo markup
- `website/styles.css` — layout, tokens, type, buttons, themes, and reveal motion
- `website/script.js` — theme toggle, reveal activation, reduced-motion handling
- `website/README.md` — local run instructions and file ownership notes
- `website/assets/.gitkeep` — keeps asset folder in git until real assets are added

### Existing Files Not To Touch

- `LimitBar/**` — Swift application code
- `LimitBar.xcodeproj/**` — Xcode project
- `project.yml` — XcodeGen configuration

## Task 1: Scaffold The Standalone Website Folder

**Files:**
- Create: `website/index.html`
- Create: `website/styles.css`
- Create: `website/script.js`
- Create: `website/README.md`
- Create: `website/assets/.gitkeep`

- [ ] **Step 1: Create the website directory layout**

Run:

```bash
mkdir -p website/assets
touch website/index.html website/styles.css website/script.js website/README.md website/assets/.gitkeep
find website -maxdepth 2 -type f | sort
```

Expected:

```text
website/README.md
website/assets/.gitkeep
website/index.html
website/script.js
website/styles.css
```

- [ ] **Step 2: Seed `website/index.html` with the semantic shell**

Write:

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>LimitBar</title>
    <meta
      name="description"
      content="A quiet macOS menu bar app for keeping an eye on your Codex and Claude usage."
    />
    <link rel="stylesheet" href="./styles.css" />
  </head>
  <body>
    <script src="./script.js" defer></script>
  </body>
</html>
```

- [ ] **Step 3: Seed `website/styles.css` with the initial strict reset**

Write:

```css
*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  color-scheme: light;
}

body {
  margin: 0;
}
```

- [ ] **Step 4: Seed `website/script.js` with a safe no-op bootstrap**

Write:

```js
document.addEventListener("DOMContentLoaded", () => {
  document.documentElement.dataset.js = "ready";
});
```

- [ ] **Step 5: Document the folder purpose in `website/README.md`**

Write:

```md
# LimitBar Promo Site

Standalone static promo page for LimitBar.

## Files

- `index.html` — page structure
- `styles.css` — page styling
- `script.js` — theme and motion behavior
- `assets/` — local static assets

## Run locally

```bash
cd website
python3 -m http.server 4173
```

Open `http://localhost:4173`.
```

- [ ] **Step 6: Verify the scaffold exists**

Run:

```bash
find website -maxdepth 2 -type f | sort
```

Expected:

```text
website/README.md
website/assets/.gitkeep
website/index.html
website/script.js
website/styles.css
```

- [ ] **Step 7: Commit the scaffold**

Run:

```bash
git add website
git commit -m "feat: scaffold limitbar promo site"
```

Expected:

```text
[<branch> <sha>] feat: scaffold limitbar promo site
```

## Task 2: Build The One-Screen Editorial HTML Structure

**Files:**
- Modify: `website/index.html`

- [ ] **Step 1: Replace the HTML shell with the full semantic page markup**

Write:

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>LimitBar</title>
    <meta
      name="description"
      content="A quiet macOS menu bar app for keeping an eye on your Codex and Claude usage."
    />
    <meta
      property="og:title"
      content="LimitBar"
    />
    <meta
      property="og:description"
      content="Track sessions, weekly limits, renewals, and account context without opening dashboards all day."
    />
    <link rel="stylesheet" href="./styles.css" />
  </head>
  <body>
    <button
      class="theme-toggle"
      type="button"
      aria-label="Toggle color theme"
      data-theme-toggle
    >
      <span class="theme-toggle__dot" aria-hidden="true"></span>
    </button>

    <main class="page-shell">
      <section class="hero" aria-labelledby="hero-title">
        <header class="hero__header">
          <h1 id="hero-title" class="hero__title">
            <span class="hero__title-primary">LimitBar,</span>
            <span class="hero__title-secondary">menu bar app</span>
          </h1>
        </header>

        <div class="hero__body">
          <p class="hero__copy" data-reveal>
            A <span class="hero__accent">quiet</span> macOS menu bar app for
            keeping an eye on your Codex and Claude usage.
          </p>
          <p class="hero__copy hero__copy--muted" data-reveal>
            Track sessions, weekly limits, renewals, and account context
            without opening dashboards all day.
          </p>
        </div>

        <div class="hero__actions" data-reveal>
          <a
            class="button button--primary"
            href="https://github.com/muhamed1222/atlasbar.me/releases"
            target="_blank"
            rel="noreferrer"
          >
            Download for macOS
          </a>
          <a
            class="button button--secondary"
            href="https://github.com/muhamed1222/atlasbar.me"
            target="_blank"
            rel="noreferrer"
          >
            GitHub
          </a>
        </div>
      </section>
    </main>

    <script src="./script.js" defer></script>
  </body>
</html>
```

- [ ] **Step 2: Run a quick structural grep on the HTML**

Run:

```bash
rg -n "theme-toggle|hero__title|hero__copy|Download for macOS|GitHub" website/index.html
```

Expected:

```text
<line>:      class="theme-toggle"
<line>:          <h1 id="hero-title" class="hero__title">
<line>:          <p class="hero__copy" data-reveal>
<line>:            Download for macOS
<line>:            GitHub
```

- [ ] **Step 3: Commit the semantic HTML**

Run:

```bash
git add website/index.html
git commit -m "feat: add limitbar promo page markup"
```

Expected:

```text
[<branch> <sha>] feat: add limitbar promo page markup
```

## Task 3: Implement The Editorial Layout, Themes, And Motion Styles

**Files:**
- Modify: `website/styles.css`

- [ ] **Step 1: Replace `website/styles.css` with the full page stylesheet**

Write:

```css
:root {
  --background: #ffffff;
  --foreground: #111111;
  --muted: #6b6b6b;
  --line: rgba(17, 17, 17, 0.12);
  --button-primary-bg: #171717;
  --button-primary-fg: #ffffff;
  --button-secondary-bg: #f3f3f3;
  --button-secondary-fg: #171717;
  --focus: rgba(17, 17, 17, 0.2);
  --shadow-soft: 0 12px 40px rgba(17, 17, 17, 0.04);
  --page-padding: clamp(24px, 4vw, 40px);
  --content-width: min(100%, 28rem);
  --title-size: clamp(1rem, 0.92rem + 0.45vw, 1.15rem);
  --body-size: 1rem;
  --body-line: 1.5;
  --button-size: 0.9375rem;
  --radius-pill: 999px;
  --motion-duration: 360ms;
  --motion-ease: cubic-bezier(0.22, 1, 0.36, 1);
}

html[data-theme="dark"] {
  --background: #0f0f10;
  --foreground: #f6f6f4;
  --muted: #a1a1a1;
  --line: rgba(246, 246, 244, 0.12);
  --button-primary-bg: #f6f6f4;
  --button-primary-fg: #111111;
  --button-secondary-bg: #1a1a1b;
  --button-secondary-fg: #f6f6f4;
  --focus: rgba(246, 246, 244, 0.22);
  --shadow-soft: 0 12px 40px rgba(0, 0, 0, 0.18);
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  color-scheme: light;
}

html[data-theme="dark"] {
  color-scheme: dark;
}

body {
  margin: 0;
  min-height: 100vh;
  background: var(--background);
  color: var(--foreground);
  font-family: "Helvetica Neue", "Neue Haas Grotesk Display Pro", "Arial", sans-serif;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
}

a {
  color: inherit;
  text-decoration: none;
}

button {
  font: inherit;
}

.theme-toggle {
  position: fixed;
  top: 1rem;
  right: 1rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  border: 1px solid var(--line);
  border-radius: var(--radius-pill);
  background: transparent;
  color: var(--foreground);
  cursor: pointer;
  transition:
    transform 160ms ease,
    background-color 160ms ease,
    border-color 160ms ease;
}

.theme-toggle:hover {
  background: rgba(127, 127, 127, 0.08);
}

.theme-toggle:active {
  transform: scale(0.97);
}

.theme-toggle:focus-visible,
.button:focus-visible {
  outline: none;
  box-shadow: 0 0 0 4px var(--focus);
}

.theme-toggle__dot {
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.9;
}

.page-shell {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: var(--page-padding);
}

.hero {
  width: var(--content-width);
  display: grid;
  gap: 1.2rem;
}

.hero__header,
.hero__body,
.hero__actions {
  width: 100%;
}

.hero__title {
  margin: 0;
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.35rem;
  font-size: var(--title-size);
  font-weight: 500;
  line-height: 1.45;
  letter-spacing: -0.01em;
}

.hero__title-primary {
  color: var(--foreground);
}

.hero__title-secondary {
  color: color-mix(in srgb, var(--foreground) 72%, transparent);
}

.hero__body {
  display: grid;
  gap: 0.25rem;
}

.hero__copy {
  margin: 0;
  font-size: var(--body-size);
  line-height: var(--body-line);
  font-weight: 500;
  color: var(--foreground);
}

.hero__copy--muted {
  color: var(--muted);
}

.hero__accent {
  display: inline-block;
  padding-right: 0.125rem;
  font-family: "Caveat", "Brush Script MT", cursive;
  font-size: 1.2em;
  font-weight: 700;
  line-height: 1;
}

.hero__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.625rem;
  align-items: center;
}

.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 2.625rem;
  padding: 0 0.95rem;
  border: 1px solid transparent;
  border-radius: var(--radius-pill);
  font-size: var(--button-size);
  font-weight: 500;
  transition:
    transform 160ms ease,
    background-color 160ms ease,
    border-color 160ms ease,
    color 160ms ease;
  box-shadow: var(--shadow-soft);
}

.button:active {
  transform: scale(0.97);
}

.button--primary {
  background: var(--button-primary-bg);
  color: var(--button-primary-fg);
}

.button--secondary {
  background: var(--button-secondary-bg);
  color: var(--button-secondary-fg);
  box-shadow: none;
}

[data-reveal],
.hero__title,
.theme-toggle {
  opacity: 0;
  transform: translateY(8px);
  filter: blur(5px);
  transition:
    opacity var(--motion-duration) var(--motion-ease),
    transform var(--motion-duration) var(--motion-ease),
    filter var(--motion-duration) var(--motion-ease);
}

body.is-ready [data-reveal],
body.is-ready .hero__title,
body.is-ready .theme-toggle {
  opacity: 1;
  transform: translateY(0);
  filter: blur(0);
}

body.is-ready .hero__body .hero__copy:nth-child(1) {
  transition-delay: 70ms;
}

body.is-ready .hero__body .hero__copy:nth-child(2) {
  transition-delay: 120ms;
}

body.is-ready .hero__actions {
  transition-delay: 170ms;
}

@media (max-width: 640px) {
  .theme-toggle {
    top: 0.875rem;
    right: 0.875rem;
  }

  .hero {
    gap: 1rem;
  }

  .hero__actions {
    gap: 0.5rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 1ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 1ms !important;
    scroll-behavior: auto !important;
  }

  [data-reveal],
  .hero__title,
  .theme-toggle {
    opacity: 1;
    transform: none;
    filter: none;
  }
}
```

- [ ] **Step 2: Verify key style hooks exist**

Run:

```bash
rg -n "data-theme=\"dark\"|hero__accent|button--primary|prefers-reduced-motion|color-mix" website/styles.css
```

Expected:

```text
<line>:html[data-theme="dark"] {
<line>:.hero__accent {
<line>:.button--primary {
<line>:@media (prefers-reduced-motion: reduce) {
<line>:  color: color-mix(in srgb, var(--foreground) 72%, transparent);
```

- [ ] **Step 3: Commit the styling layer**

Run:

```bash
git add website/styles.css
git commit -m "feat: style limitbar promo page"
```

Expected:

```text
[<branch> <sha>] feat: style limitbar promo page
```

## Task 4: Add Theme Persistence And Reveal Behavior

**Files:**
- Modify: `website/script.js`

- [ ] **Step 1: Replace `website/script.js` with the interactive behavior**

Write:

```js
const STORAGE_KEY = "limitbar-promo-theme";

function getPreferredTheme() {
  const stored = window.localStorage.getItem(STORAGE_KEY);

  if (stored === "light" || stored === "dark") {
    return stored;
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme === "dark" ? "dark" : "light";
  const next = current === "dark" ? "light" : "dark";

  applyTheme(next);
  window.localStorage.setItem(STORAGE_KEY, next);
}

document.addEventListener("DOMContentLoaded", () => {
  try {
    applyTheme(getPreferredTheme());
  } catch {
    applyTheme("light");
  }

  const toggle = document.querySelector("[data-theme-toggle]");

  if (toggle) {
    toggle.addEventListener("click", toggleTheme);
  }

  window.requestAnimationFrame(() => {
    document.body.classList.add("is-ready");
  });
});
```

- [ ] **Step 2: Verify the script references are correct**

Run:

```bash
rg -n "STORAGE_KEY|data-theme-toggle|requestAnimationFrame|is-ready|prefers-color-scheme" website/script.js
```

Expected:

```text
<line>:const STORAGE_KEY = "limitbar-promo-theme";
<line>:  const toggle = document.querySelector("[data-theme-toggle]");
<line>:  window.requestAnimationFrame(() => {
<line>:    document.body.classList.add("is-ready");
<line>:  return window.matchMedia("(prefers-color-scheme: dark)").matches
```

- [ ] **Step 3: Commit the interaction layer**

Run:

```bash
git add website/script.js
git commit -m "feat: add promo page theme interactions"
```

Expected:

```text
[<branch> <sha>] feat: add promo page theme interactions
```

## Task 5: Verify The Static Site End To End And Finalize Documentation

**Files:**
- Modify: `website/README.md`
- Verify: `website/index.html`
- Verify: `website/styles.css`
- Verify: `website/script.js`

- [ ] **Step 1: Expand `website/README.md` with final run and edit notes**

Replace with:

```md
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
- Keep `GitHub` as the secondary CTA
```

- [ ] **Step 2: Run the site locally**

Run:

```bash
cd website
python3 -m http.server 4173
```

Expected:

```text
Serving HTTP on :: port 4173 (http://[::]:4173/) ...
```

- [ ] **Step 3: Verify the rendered page manually in a browser**

Run in a separate terminal:

```bash
open http://localhost:4173
```

Manual checks:

- page is vertically centered
- only one main content block is visible
- background is pure white in light mode
- dark mode toggles correctly
- `quiet` uses the handwritten accent
- both buttons are visible without scrolling on desktop
- layout remains readable around mobile width

- [ ] **Step 4: Stop the local server after manual verification**

Run:

```bash
pkill -f "python3 -m http.server 4173"
```

Expected:

```text
```

- [ ] **Step 5: Confirm the final file set**

Run:

```bash
find website -maxdepth 2 -type f | sort
```

Expected:

```text
website/README.md
website/assets/.gitkeep
website/index.html
website/script.js
website/styles.css
```

- [ ] **Step 6: Commit the final documentation and verification pass**

Run:

```bash
git add website/README.md website/index.html website/styles.css website/script.js website/assets/.gitkeep
git commit -m "docs: finalize limitbar promo site"
```

Expected:

```text
[<branch> <sha>] docs: finalize limitbar promo site
```

## Self-Review

### Spec Coverage

- Separate `website/` folder: covered by Task 1
- One-screen and one-section structure: covered by Task 2 and Task 5 manual verification
- White background and restrained editorial layout: covered by Task 3
- Primary `Download for macOS` CTA and secondary `GitHub` CTA: covered by Task 2
- Theme toggle with light/dark behavior: covered by Task 4
- Minimal JavaScript and restrained reveal motion: covered by Task 3 and Task 4
- Documentation for local running and editing constraints: covered by Task 1 and Task 5

### Placeholder Scan

- No `TODO` or `TBD` plan markers remain
- All file paths are explicit
- All commands are explicit
- All code-writing steps include concrete code

### Type Consistency

- Theme selector uses `data-theme` consistently in HTML, CSS, and JavaScript
- Toggle hook uses `data-theme-toggle` consistently in HTML and JavaScript
- Reveal state uses `is-ready` consistently in CSS and JavaScript
