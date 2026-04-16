# Klok

A lightweight macOS menu bar clock app inspired by [Dato](https://sindresorhus.com/dato). Shows the time, a monthly calendar, upcoming calendar events, and world clocks — all in a clean popover. No Xcode required to build.

![Klok menu bar popover](https://github.com/adityavverma/klok/raw/main/Resources/AppIcon.png)

---

## Features

- **Menu bar clock** — date, time, seconds, 12/24h format
- **Primary timezone** — set any timezone as your main clock (defaults to system)
- **Secondary clocks in menu bar** — show up to 2 extra timezones alongside the main clock
- **Month calendar** — with week numbers, weekend highlighting, and colored event dots
- **Upcoming events** — next 3 events from your calendars with countdown and video call detection
- **World clocks panel** — city name, time, UTC offset, day/night icon, relative day (Today/Tomorrow)
- **Preferences window** — General, Clocks, Calendar, and Events tabs
- **App Nap prevention** — clock never freezes or vanishes from the menu bar
- **Near-zero battery impact** — safe to run 24/7

---

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)

No third-party dependencies. No Xcode IDE needed.

---

## Installation

### Option 1 — Build from source (recommended)

```bash
# 1. Clone the repo
git clone https://github.com/adityavverma/klok.git
cd klok

# 2. Build
bash build.sh

# 3. Install to Applications
cp -r Klok.app /Applications/

# 4. Remove macOS quarantine flag (required for apps not from the App Store)
xattr -cr /Applications/Klok.app

# 5. Launch
open /Applications/Klok.app
```

Klok will appear in your menu bar immediately.

### Option 2 — Run without installing

```bash
git clone https://github.com/adityavverma/klok.git
cd klok
bash build.sh
xattr -cr Klok.app
open Klok.app
```

---

## Auto-start on login

1. Open **System Settings → General → Login Items**
2. Click **+** and select `/Applications/Klok.app`

---

## Usage

**Click** the menu bar clock to open the popover.

**Right-click** the menu bar clock for a quick menu (Preferences, Quit).

Inside the popover:
- **`‹` / `›`** arrows navigate months
- **Today** button (appears when you've navigated away) jumps back to current month
- **`···`** button → Preferences or Quit
- **`>`** button → opens Calendar.app

### Preferences

Open via `···` → Preferences, or right-click the menu bar icon.

| Tab | Options |
|-----|---------|
| **General** | Show date, 24h format, seconds, secondary timezones in menu bar, next event in menu bar |
| **Clocks** | Primary timezone, secondary menu bar clocks (up to 2), world clocks shown in popover |
| **Calendar** | Week starts on Monday, week numbers, highlight weekends, event dots |
| **Events** | Show upcoming events, enable/disable individual calendars |

---

## Calendar Access

On first launch, Klok will request access to your calendars. This is used to:
- Show colored event dots on the calendar grid
- Display upcoming events in the popover
- Show the next event in the menu bar

You can grant or revoke access at any time in **System Settings → Privacy & Security → Calendars**.

---

## Building

The build script compiles all Swift sources in `Sources/` using `swiftc` and packages them into a standard `.app` bundle:

```
Klok.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo
    ├── MacOS/
    │   └── Klok          ← compiled binary
    └── Resources/
        └── AppIcon.icns
```

To rebuild after making changes:

```bash
bash build.sh && cp -r Klok.app /Applications/ && xattr -cr /Applications/Klok.app
```

If the app is already running, quit it first (`···` → Quit Klok) or:

```bash
pkill -x Klok; bash build.sh && cp -r Klok.app /Applications/ && xattr -cr /Applications/Klok.app && open /Applications/Klok.app
```

---

## Project Structure

```
klok/
├── build.sh                          # Build script (no Xcode needed)
├── Resources/
│   ├── Info.plist                    # App bundle metadata
│   ├── AppIcon.icns                  # App icon (all sizes)
│   └── AppIcon.png                   # Source icon (2048×2048)
└── Sources/
    ├── main.swift                    # Entry point
    ├── AppDelegate.swift             # App Nap prevention
    ├── AppSettings.swift             # UserDefaults-backed settings
    ├── StatusBarController.swift     # Menu bar item, timer, popover
    ├── PopoverViewController.swift   # Popover layout and sections
    ├── CalendarView.swift            # Month calendar grid + DayCell
    ├── WorldClocksView.swift         # World clocks rows
    ├── UpcomingEventsView.swift      # Upcoming events list
    ├── PreferencesWindowController.swift  # Preferences UI
    └── EventManager.swift            # EventKit wrapper
```

---

## License

MIT
