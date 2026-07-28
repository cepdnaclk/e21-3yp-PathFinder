# Image Placeholder Guide

All current images are lightweight local SVG placeholders. Replace them with verified project visuals when available. Keep replacement files inside `docs/images` and update the matching `src` path in `docs/index.html` if the filename or extension changes.

Example: replace `images/placeholders/hero-device.svg` with `images/hero-device.webp`, then update the corresponding `src` in `index.html`.

Compress photos before adding them. Prefer WebP for photographs, and prefer SVG or PNG for diagrams, wireframes, and architecture drawings. Use descriptive filenames so future maintainers can understand each asset.

| Placeholder file | Intended replacement | Recommended aspect ratio | Suggested file type | Notes |
| --- | --- | --- | --- | --- |
| `hero-device.svg` | Final PathFinder device image | 3:2 or 16:10 | WebP or PNG | Use a clear product-style image of the assembled prototype. |
| `architecture.png` | Final system architecture diagram | 4:3 | PNG | Keep labels readable on mobile. |
| `data-flow.png` | Final data-flow diagram | 4:3 | PNG | Show device, network, cloud, app, and guardian flow. |
| `mobile-login.svg` | Login screen screenshot | 9:18 | WebP or PNG | Use a real phone screenshot or framed mockup. |
| `mobile-home.svg` | Home dashboard screenshot | 9:18 | WebP or PNG | Show registered devices and key safety controls. |
| `mobile-tracking.svg` | Live tracking screenshot | 9:18 | WebP or PNG | Show latest available location. |
| `mobile-sos.svg` | SOS alert screenshot | 9:18 | WebP or PNG | Avoid showing private user data. |
| `mobile-safe-zone.svg` | Safe-zone management screenshot | 9:18 | WebP or PNG | Show editable safe-zone view. |
| `mobile-camera.svg` | Camera feed screenshot | 9:18 | WebP or PNG | Use a safe demo feed or blurred private surroundings. |
| `hardware-raspberry-pi.svg` | Raspberry Pi module photo | 10:7 | WebP | Show mounted controller clearly. |
| `hardware-camera.svg` | Camera module photo | 10:7 | WebP | Show camera placement and cable routing. |
| `hardware-gps.svg` | GPS module photo | 10:7 | WebP | Show GPS antenna/module location. |
| `hardware-battery.svg` | Battery and INA219 photo | 10:7 | WebP | Show power wiring safely and clearly. |
| `hardware-speaker.svg` | Speaker or audio output photo | 10:7 | WebP | Show speaker placement. |
| `hardware-4g.svg` | 4G or Wi-Fi connectivity module photo | 10:7 | WebP | Show modem, antenna, or connectivity setup. |
| `gallery-01.svg` | Initial hardware setup photo | 29:20 | WebP | Good for early prototype or bench setup. |
| `gallery-02.jpeg` | Raspberry Pi integration or internal layout photo | 29:20 | JPEG | Reused by the second gallery card and hardware integration figure. |
| `gallery-03.svg` | Camera testing photo | 29:20 | WebP | Show controlled testing environment. |
| `gallery-04.svg` | GPS and connectivity testing photo | 29:20 | WebP | Avoid exposing private coordinates. |
| `gallery-05.svg` | Mobile application development image | 29:20 | WebP or PNG | Use app screenshot, development setup, or UI mockup. |
| `gallery-06.svg` | Final prototype and controlled field testing photo | 29:20 | WebP | Avoid implying real-world safety certification. |
| `team-member-01.svg` | Team member 1 photo | 1:1 | WebP | Replace with consented profile photo. |
| `team-member-02.svg` | Team member 2 photo | 1:1 | WebP | Replace with consented profile photo. |
| `team-member-03.svg` | Team member 3 photo | 1:1 | WebP | Replace with consented profile photo. |
| `team-member-04.svg` | Team member 4 photo | 1:1 | WebP | Replace with consented profile photo. |
| `supervisor-01.svg` | Supervisor 1 photo | 1:1 | WebP | Confirm academic title and contact details. |
| `supervisor-02.svg` | Supervisor 2 photo | 1:1 | WebP | Confirm academic title and contact details. |
