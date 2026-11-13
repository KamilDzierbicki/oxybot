---
name: OxyBot
description: Open-source product agent that turns customer feedback into product decisions
colors:
  bg: "oklch(98.5% 0.004 260)"
  surface: "oklch(100% 0 0)"
  sidebar: "oklch(96.5% 0.006 260)"
  text: "oklch(24% 0.02 260)"
  muted: "oklch(48% 0.02 260)"
  border: "oklch(90% 0.01 260)"
  border-strong: "oklch(64% 0.015 260)"
  accent: "oklch(55% 0.19 35)"
  accent-strong: "oklch(50% 0.19 35)"
  accent-text: "oklch(99% 0 0)"
  accent-soft: "oklch(95% 0.04 35)"
  link: "oklch(49% 0.17 35)"
  ok: "oklch(45% 0.12 150)"
  warn: "oklch(48% 0.12 70)"
  danger: "oklch(47% 0.16 5)"
  bg-dark: "oklch(18% 0.012 260)"
  surface-dark: "oklch(22% 0.014 260)"
  sidebar-dark: "oklch(16% 0.012 260)"
  text-dark: "oklch(93% 0.01 260)"
  muted-dark: "oklch(72% 0.015 260)"
  border-dark: "oklch(31% 0.015 260)"
  border-strong-dark: "oklch(56% 0.015 260)"
  accent-soft-dark: "oklch(27% 0.06 35)"
  link-dark: "oklch(74% 0.13 45)"
  danger-dark: "oklch(74% 0.13 5)"
  shadow: "oklch(0% 0 0 / 0.06)"
  shadow-raised: "oklch(0% 0 0 / 0.16)"
  scrim: "oklch(0% 0 0 / 0.12)"
typography:
  body:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.55
  h1:
    fontFamily: "{typography.body.fontFamily}"
    fontSize: "1.5rem"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  hero:
    fontSize: "2rem"
    fontWeight: 600
  h2:
    fontSize: "1.125rem"
    fontWeight: 600
  caption:
    fontSize: "0.8125rem"
  small:
    fontSize: "0.875rem"
  label:
    fontSize: "0.8125rem"
    fontWeight: 600
  mono:
    fontFamily: "ui-monospace, monospace"
    fontSize: "0.85rem"
weights:
  regular: 400
  strong: 600
rounded:
  sm: "4px"
  md: "8px"
  lg: "10px"
  xl: "14px"
  pill: "999px"
spacing:
  "1": "0.25rem"
  "2": "0.5rem"
  "3": "0.75rem"
  "4": "1rem"
  "6": "1.5rem"
  "8": "2rem"
components:
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "0.5rem 1rem"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-text}"
    rounded: "{rounded.md}"
    padding: "0.5rem 1rem"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "1rem"
  pill:
    backgroundColor: "{colors.sidebar}"
    textColor: "{colors.muted}"
    rounded: "{rounded.pill}"
    padding: "0 0.5rem"
---

## Direction

- **Product:** turns customer feedback from Slack, Mattermost, HubSpot and a form into cited product decisions (insights, demand by ARR, specs) for product managers.
- **Character:** factual, evidence-led, editorial.
- **World:** a researcher's notebook and a ledger: quotes with footnotes, amounts in the margin, numbered sources.
- **Focus:** the ARR asking for a feature and the customer quote behind it. Everything else stays quiet: titles in the text color, the accent only for actions.
- **Signature:** citations are numbered footnotes (`#12`); tapping one shows the quote, the customer and their ARR without leaving the page.

## Overview

A calm work tool for product managers: dense information, quiet chrome, one warm accent. The sidebar holds
navigation; the main column holds one task per page (inbox, features, a document, a conversation). Light and dark
themes follow the system setting. Source of truth: the custom properties on `:root` in
`app/assets/stylesheets/application.css`.

## Colors

Neutral blue-grey surfaces with a single terracotta accent (`accent`) for primary actions, the count badge,
citations, the ARR focus number and the logo mark. Row titles in lists use the text color, not the accent. `danger` is
a wine red, kept apart from the accent hue so errors never look like actions. Status colors (`ok`, `warn`, `danger`)
appear only in small pills, diff lines and the alert banner, never as large fills. Success messages are neutral with a
green check. Form fields use `border-strong` (3:1 against the surface). Dark mode swaps the neutral tokens and keeps the accent.

## Typography

System UI font everywhere, 15px body, two weights only (400 and 600), sizes from the scale above. The de-slop module
prefers 400 and 500; 600 is kept on purpose, because the system font at 500 looks like 400 on Windows. Pills, table
headers and nav groups use the `label` style in sentence case at normal tracking. Code, templates and diffs use the
system monospace.

## Layout

Two columns on desktop: a 220px sticky sidebar and a main column capped at 1100px. Documents use a reading column
with a 340px side panel for the agent. Below 800px the sidebar becomes a compact top bar with a Menu button that opens
the navigation, every grid collapses to one column, list tables (`.table--cards`) become one card per row with labeled
values, other tables scroll inside their own box, and every control is at least 44px tall. Spacing uses the 4px scale; the tokens live on `:root` in application.css.

## Elevation & Depth

Flat. Cards separate from the background with a 1px border and, in light mode only, a 1px shadow. The only floating
layer is the citation popover (`shadow-raised` over a light `scrim`), besides native confirm dialogs.

## Shapes

8px radius for controls, 10px for cards, 14px for chat bubbles and the composer, fully rounded pills and chips.

## Components

Buttons (default, primary, quiet, danger), cards, pills for status and urgency ("High urgency"), tabs as rounded
filters, tables with sentence-case headers, chat bubbles (user in `accent-soft`, assistant in `surface` with border),
citation footnotes (`#12` in `accent-soft`, opening a popover card), quotes with a 2px `border-strong` rule, diffs that
show only changed lines with two lines of context (added in a green tint, removed struck through in a red tint), and a
flash banner that can carry an Undo button.

## Do's and Don'ts

- Do keep one primary button per area; everything else is default or quiet.
- Do show where a number comes from (citations, "Used feature_demand").
- Don't add new colors for decoration; use the existing tokens.
- Don't use gradients, glassmorphism or large status-colored fills.
- Do use `--link` (not `--accent`) for text links: it passes WCAG AA on every surface in both themes.
- Do offer Undo instead of a confirmation for reversible actions (triage, accepting a suggestion); confirm only actions
  that cost money, leave OxyBot or cannot be undone.
