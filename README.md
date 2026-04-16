# Klok — macOS Menu Bar Clock App

**Free, open-source macOS menu bar clock with calendar, world clocks, and upcoming events. No Xcode required.**

![Klok App Icon](https://github.com/adityavverma/klok/raw/main/Resources/AppIcon.png)

---

## What is Klok?

Klok is a **macOS menu bar clock app** that replaces or extends the default system clock. It shows the current time in your menu bar and opens a popover with a full **monthly calendar**, **upcoming calendar events**, and **world clocks** for multiple timezones — all with zero battery impact.

Built entirely in Swift with AppKit. No Xcode IDE needed to build and run.

---

## Features

- **Menu bar clock** — live time with date, seconds, 12h/24h format
- **Custom primary timezone** — display any timezone as your main clock
- **Multiple timezones in menu bar** — show up to 2 extra timezone clocks side by side
- **Monthly calendar** — full month grid with week numbers, weekend highlighting, and colored event dots per day
- **Upcoming events** — shows next 3 events from Apple Calendar with countdown timer and video call detection (Zoom, Google Meet, Teams)
- **World clocks** — time, UTC offset, day/night icon, and relative day label (Today / Tomorrow) for any city
- **Next event in menu bar** — see your next meeting without opening anything
- **Preferences** — full settings window with General, Clocks, Calendar, and Events tabs
- **Always-on** — never freezes, never vanishes from the menu bar
- **Lightweight** — near-zero CPU and battery usage, safe to run 24/7

---

## Requirements

- macOS 13 Ventura or later (works on Sonoma and Sequoia)
- Xcode Command Line Tools only — no full Xcode install needed

```bash
xcode-select --install
```

---

## Install

### Build from source

```bash
git clone https://github.com/adityavverma/klok.git
cd klok
bash build.sh
cp -r Klok.app /Applications/
xattr -cr /Applications/Klok.app
open /Applications/Klok.app
```

Klok will appear in your menu bar instantly.

### Run without installing

```bash
git clone https://github.com/adityavverma/klok.git
cd klok
bash build.sh
xattr -cr Klok.app
open Klok.app
```

> **Why `xattr -cr`?** macOS quarantines apps downloaded from the internet or built outside the App Store. This command removes that flag so the app can run.

---

## Auto-start on Login

To launch Klok automatically when your Mac starts:

1. **System Settings → General → Login Items**
2. Click **+** and choose `/Applications/Klok.app`

---

## Usage

| Action | Result |
|--------|--------|
| Click menu bar clock | Opens the popover |
| Right-click menu bar clock | Quick menu (Preferences, Quit) |
| `‹` / `›` in popover | Navigate months |
| **Today** button | Jump back to current month |
| `···` button | Preferences or Quit |
| `>` button | Open Apple Calendar |

### Preferences

| Tab | What you can configure |
|-----|------------------------|
| **General** | Date display, 12h/24h, seconds, secondary timezones in menu bar, next event in menu bar |
| **Clocks** | Primary timezone, up to 2 secondary menu bar clocks, world clocks list |
| **Calendar** | Week start day, week numbers, weekend highlighting, event dots |
| **Events** | Toggle upcoming events panel, enable/disable individual calendars |

---

## Calendar & Events Access

Klok asks for calendar permission on first launch to:
- Show colored dots on days that have events
- Display upcoming events in the popover
- Show your next event in the menu bar

Manage permissions anytime: **System Settings → Privacy & Security → Calendars**

---

## Building & Development

The `build.sh` script compiles all Swift source files and packages them into a standard macOS `.app` bundle using `swiftc` — no Xcode project file, no SPM, no dependencies.

```
Klok.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo
    ├── MacOS/Klok          ← compiled binary
    └── Resources/AppIcon.icns
```

**Rebuild and reinstall in one line:**

```bash
pkill -x Klok; bash build.sh && cp -r Klok.app /Applications/ && xattr -cr /Applications/Klok.app && open /Applications/Klok.app
```

---

## Project Structure

```
klok/
├── build.sh
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── AppIcon.png
└── Sources/
    ├── main.swift                         # Entry point
    ├── AppDelegate.swift                  # Prevents App Nap
    ├── AppSettings.swift                  # All settings via UserDefaults
    ├── StatusBarController.swift          # Menu bar item, 1s timer, popover
    ├── PopoverViewController.swift        # Popover layout
    ├── CalendarView.swift                 # Monthly calendar grid
    ├── WorldClocksView.swift              # World clock rows
    ├── UpcomingEventsView.swift           # Upcoming events list
    ├── PreferencesWindowController.swift  # Settings UI
    └── EventManager.swift                 # EventKit / Apple Calendar wrapper
```

---

## Keywords

macOS menu bar clock · macOS world clock app · macOS calendar menu bar · macOS timezone clock · macOS status bar clock · macOS upcoming events menu bar · macOS clock app open source · Swift menu bar app · AppKit menu bar · macOS multiple timezones · macOS clock with calendar · free macOS clock app

---

## License

MIT
