# LimitBar Promo Site Design

Date: 2026-04-07
Status: Draft approved in chat, awaiting explicit user review of this written spec

## Goal

Create a standalone promo page for LimitBar inside this repository in a separate `website/` folder.

The page should:

- present LimitBar as a quiet macOS menu bar app for tracking Codex and Claude usage
- feel very close in mood and restraint to `tomm.page`
- remain one-screen and one-section only
- prioritize a single primary CTA: `Download for macOS`
- stay isolated from the existing Swift/Xcode app code in `LimitBar/`

This is not a full marketing site and not a multi-section SaaS landing page.

## Product Intent

The audience is ordinary users who want to understand the value in 5-10 seconds.

The page should communicate:

- what the product is
- why it is useful
- what to do next

It should not front-load technical implementation details, architecture, or internal app mechanics.

## Chosen Direction

The approved direction is the closest option to the reference:

- one narrow centered editorial block
- very little chrome
- short, calm copy
- almost no product scaffolding
- atmosphere first, but still understandable

The final page should feel like a product page with taste and restraint, not like a template-driven startup landing page.

## Scope

### In Scope

- a standalone static website in `website/`
- one page only
- light and dark theme toggle
- one main content block
- primary CTA for download
- secondary CTA to GitHub
- light reveal animation on load
- minimal JavaScript for interactions only

### Out of Scope

- additional sections below the fold
- pricing, FAQ, testimonials, feature grids, changelog, docs
- CMS, analytics, form submission, backend
- integration into the Swift app bundle
- complex routing or framework setup

## Information Architecture

There is only one screen and one reading path:

1. See the product name and small descriptor
2. Read two short lines explaining the value
3. Click `Download for macOS`
4. Optionally open GitHub

No additional information hierarchy is required.

## Content Structure

### Header Controls

Top-right floating controls:

- theme toggle

No traditional navbar.

### Main Block

Centered vertically and horizontally within the viewport.

Structure:

1. Title line
2. Supporting paragraph
3. Supporting paragraph
4. CTA row

### Proposed Copy

Title line:

`LimitBar, menu bar app`

Paragraph 1:

`A quiet macOS menu bar app for keeping an eye on your Codex and Claude usage.`

Paragraph 2:

`Track sessions, weekly limits, renewals, and account context without opening dashboards all day.`

Primary CTA:

`Download for macOS`

Secondary CTA:

`GitHub`

Copy should stay short. If any wording changes during implementation, the same tone must be preserved: plain, calm, precise.

## Visual Design

### Overall Composition

The page should be visually close to `tomm.page`, but not a direct clone.

Approved composition:

- clean white background
- narrow content width around `420-460px`
- generous vertical centering
- no background effects
- no cards, section dividers, feature blocks, or decorative containers

### Color

Light theme:

- background: pure white
- primary text: soft near-black, not absolute black
- secondary text: neutral gray
- CTA background: dark neutral
- CTA text: white
- secondary button: light neutral background

Dark theme:

- calm inversion of the same system
- no neon accents
- no glows
- no saturated gradients across the page

### Typography

Typography should do most of the work.

Rules:

- one main sans serif for UI and body
- one handwritten accent treatment for exactly one word: `quiet`
- no serif accent words in the initial implementation
- no oversized hero headline
- title should read like an editorial line, not like a marketing billboard

### Visual Restraint

Do not add:

- feature cards
- boxed containers
- gradients used as broad decoration
- glossy effects
- shadows as a primary styling tool
- icon-heavy compositions

The page should feel almost empty, but intentional.

## Motion and Interaction

### Page Load

Elements should reveal with a restrained entrance animation:

- slight fade
- slight blur reduction
- slight upward settle

The motion should be quiet and quick.

### Buttons

Buttons should:

- be pill-shaped
- have subtle hover response
- slightly compress on press

### Theme Toggle

Theme toggle should:

- switch between light and dark
- persist the preference locally if trivial to implement
- remain visually small and unobtrusive

## Implementation Architecture

The promo site should live in a separate folder:

- [`website/`](/Users/kelemetov/Documents/atlas.me/website)

Planned file structure:

- [`website/index.html`](/Users/kelemetov/Documents/atlas.me/website/index.html)
- [`website/styles.css`](/Users/kelemetov/Documents/atlas.me/website/styles.css)
- [`website/script.js`](/Users/kelemetov/Documents/atlas.me/website/script.js)
- [`website/assets/`](/Users/kelemetov/Documents/atlas.me/website/assets)
- [`website/README.md`](/Users/kelemetov/Documents/atlas.me/website/README.md)

### Rationale

This keeps the promo page:

- isolated from `LimitBar/`
- easy to host statically
- easy to iterate on without framework overhead
- easy to replace later if the marketing site grows

## Behavioral Details

### Download CTA

The primary CTA should be wired in a way that supports one of these outcomes during implementation:

- direct download URL
- GitHub release asset URL
- GitHub releases page URL as the fallback if a direct binary asset URL is not yet available

Implementation should prefer a direct downloadable URL if one exists, otherwise use the repository releases page.

### Secondary CTA

The secondary CTA should open the repository URL in a new tab.

### Accessibility

The page must support:

- keyboard access to all interactive controls
- visible focus states
- semantic buttons and links
- sufficient contrast in both themes

## Error Handling

This site has minimal runtime logic. Error handling requirements are simple:

- if local theme persistence fails, default gracefully to light theme
- if an asset is missing, the page should remain readable without it
- if JavaScript is disabled, the page should still render as a usable static page, except for enhanced interactions like theme persistence

## Testing Strategy

Testing should match the small scope:

- open the page locally and verify layout at desktop width
- verify it remains usable on mobile width
- verify theme toggle works
- verify primary and secondary CTA links are correct
- verify no layout breakage with missing accent font fallbacks
- verify the page still reads clearly without animation

No heavy testing framework is required for this phase.

## Success Criteria

The page is successful if:

- it is clearly separate from the Swift app code
- it feels close in restraint and mood to `tomm.page`
- it communicates the product in under 10 seconds
- it remains one-screen and one-section only
- the primary CTA is obvious without feeling loud

## Risks

### Risk 1: Copy becomes too vague

Because the page is intentionally sparse, unclear wording would make the page feel stylish but uninformative.

Mitigation:

- keep copy concrete
- mention Codex and Claude directly
- mention menu bar positioning and limit tracking clearly

### Risk 2: Over-designing the page

Adding too many accents, layout tricks, or feature hints would move the page away from the approved direction.

Mitigation:

- default to removing elements rather than adding them
- keep a strict one-block layout

### Risk 3: Making it a clone

If implementation copies the reference too literally, the result will feel derivative.

Mitigation:

- preserve the compositional philosophy, not exact assets or exact wording
- use LimitBar-specific content and a product-appropriate tone

## Open Decisions For Implementation

These can be resolved during implementation without changing the design direction:

- whether the top-right secondary control should be omitted entirely
- whether the title line includes a tiny product mark
- whether one or two words get a type accent
- what exact final download URL should be used

## Summary

Build a standalone static promo page in `website/` that is visually close in restraint and tone to `tomm.page`, but dedicated to LimitBar.

It should remain a single-screen, centered editorial composition with:

- pure white background
- short product copy
- `Download for macOS` as the primary action
- `GitHub` as the secondary action
- minimal motion
- no extra sections
