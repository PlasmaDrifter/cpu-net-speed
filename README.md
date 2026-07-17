# CPU & Network Speed

A KDE Plasma panel widget showing horizontal bars for CPU usage, download speed, and upload speed — all in one compact widget.

![cpu-net](cpu-net-speed.png)

![cpu-net](desktop-2.png)

![cpu-net](cpu-net.png)

## Features

- CPU usage bar (normalised across all cores)
- Video Card usage bar (normalised across all cores)
- Download and upload speed bars
- Per-link configurable speed scale (so the bar fills at your connection maximum)
- Fully configurable bar colours
- Compact horizontal layout — ideal for a horizontal panel

## Requirements

- KDE Plasma 6.0+
- `org.kde.ksysguard.sensors` (included with Plasma)

## Installation

```bash
cd ~/.local/share/plasma/plasmoids/
git clone https://github.com/PlasmaDrifter/cpu-net-speed local.widget.cpu-net-speed
```

Then right-click your panel → **Add Widgets** → search for **CPU & Network Speed**.

## Configuration

Right-click the widget → **Configure…**

| Option | Description |
|--------|-------------|
| CPU colour | Bar fill colour for CPU usage |
| Download colour | Bar fill colour for download speed |
| Upload colour | Bar fill colour for upload speed |
| Max download speed | Full-scale speed (Mbps) for the download bar |
| Max upload speed | Full-scale speed (Mbps) for the upload bar |
| Refresh interval | How often to update (seconds) |

