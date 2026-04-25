# Hab' ich wirklich so viel Zeit gespart?

> **Disclaimer:** This README was written entirely by Claude (Anthropic's AI assistant), who also wrote the vast majority of the app's code.

## What is this?

A simple iOS app that answers the age-old question every speeder secretly wonders: *"Am I actually saving any time by driving this fast?"*

The app tracks your driving speed via GPS and calculates in real time how much time you save (or don't) by exceeding a reference speed — defaulting to 130 km/h on the Autobahn or 60 mph.

Spoiler: it's usually less than you think.

## Features

- **Live speedometer** — large, glanceable speed display via GPS
- **Time saved counter** — running tally of seconds saved versus the reference speed, with percentage
- **Travel stats** — travel time, distance driven, and average speed
- **Traffic jam mode** ("Staumodus") — prevents the trip timer from auto-stopping in slow traffic
- **Background tracking** — keeps running when you switch apps
- **mph / km/h toggle** — for both sides of the Atlantic

## How it works

Whenever your speed exceeds the reference threshold, the app accumulates the time difference: how long the distance you just covered would have taken at the reference speed versus how long it actually took. Time spent below the threshold is not subtracted — it only counts the gains.

## Requirements

- iOS 17+
- Location permission (always, for background tracking)

## Built with

- Swift & SwiftUI
- CoreLocation
- Observation framework
