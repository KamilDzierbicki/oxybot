---
name: OxyBot
description: Open-source product agent that turns customer feedback into product decisions
colors:
  bg: "oklch(98.5% 0.004 260)"
  surface: "oklch(100% 0 0)"
  sidebar: "oklch(96.5% 0.006 260)"
  text: "oklch(24% 0.02 260)"
  muted: "oklch(52% 0.02 260)"
  border: "oklch(90% 0.01 260)"
  accent: "oklch(58% 0.19 35)"
  accent-text: "oklch(99% 0 0)"
  accent-soft: "oklch(95% 0.04 35)"
  ok: "oklch(55% 0.13 150)"
  warn: "oklch(62% 0.15 75)"
  danger: "oklch(56% 0.19 25)"
  bg-dark: "oklch(18% 0.012 260)"
  surface-dark: "oklch(22% 0.014 260)"
  sidebar-dark: "oklch(16% 0.012 260)"
  text-dark: "oklch(93% 0.01 260)"
  muted-dark: "oklch(70% 0.015 260)"
  border-dark: "oklch(31% 0.015 260)"
  accent-soft-dark: "oklch(30% 0.06 35)"
typography:
  body:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.55
  h1:
    fontFamily: "{typography.body.fontFamily}"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  hero:
    fontSize: "2rem"
    fontWeight: 700
  label:
    fontSize: "0.72rem"
    fontWeight: 600
    letterSpacing: "0.03em"
  mono:
    fontFamily: "ui-monospace, monospace"
    fontSize: "0.85rem"
rounded:
  sm: "4px"
  md: "8px"
  lg: "10px"
  xl: "14px"
  pill: "999px"
spacing:
  xs: "0.25rem"
  sm: "0.5rem"
  md: "0.75rem"
  lg: "1rem"
  xl: "2rem"
components:
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "0.45rem 0.9rem"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-text}"
    rounded: "{rounded.md}"
    padding: "0.45rem 0.9rem"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "1rem 1.1rem"
  pill:
    backgroundColor: "{colors.sidebar}"
    textColor: "{colors.muted}"
    rounded: "{rounded.pill}"
    padding: "0.1rem 0.5rem"
---

## Overview

A calm work tool for product managers: dense information, quiet chrome, one warm accent. The sidebar holds
navigation; the main column holds one task per page (inbox, features, a document, a conversation). Light and dark
themes follow the system setting. Source of truth: the custom properties on `:root` in
`app/assets/stylesheets/application.css`.

## Colors

Neutral blue-grey surfaces with a single terracotta accent (`accent`) for primary actions, the active count badge,
citations and the logo mark. Status colors (`ok`, `warn`, `danger`) appear only in small pills and diff lines, never
as large fills. Dark mode swaps the neutral tokens and keeps the accent.

## Typography

System UI font everywhere, 15px body, tight headings. Small uppercase labels (pills, table headers, nav groups) use
the `label` style. Code, templates and diffs use the system monospace.

## Layout

Two columns on desktop: a 220px sticky sidebar and a main column capped at 1100px. Documents use a reading column
with a 340px side panel for the agent. Below 800px the sidebar becomes a wrapped top bar and every grid collapses to
one column.

## Elevation & Depth

Flat. Cards separate from the background with a 1px border and, in light mode only, a 1px shadow. No floating
layers except native dialogs.

## Shapes

8px radius for controls, 10px for cards, 14px for chat bubbles and the composer, fully rounded pills and chips.

## Components

Buttons (default, primary, quiet), cards, pills for status, tabs as rounded filters, tables with uppercase headers,
chat bubbles (user in `accent-soft`, assistant in `surface` with border), citation chips (`#12` in `accent-soft`),
diff lines (added in a green tint, removed struck through in a red tint).

## Do's and Don'ts

- Do keep one primary button per area; everything else is default or quiet.
- Do show where a number comes from (citations, "Used feature_demand").
- Don't add new colors for decoration; use the existing tokens.
- Don't use gradients, glassmorphism or large status-colored fills.
