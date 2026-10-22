# Mat

Mat turns an iPad into a picture frame. It shuffles through one album in Photos and shows each photo inside a plain border, set in real inches, that looks like the mat in an ordinary frame. If your frame leaves the iPad's bezel showing, the border makes the bezel look like part of the mat.

Each photo is held for a fixed time, then crossfades to the next. That's all it does.

## What it does

- **Follows the iPad's orientation.** Only photos that match the way the iPad is turned are shown, and near-square photos count for both. Rotate the iPad and Mat switches to the other set straight away.
- **Shuffles without repeats.** Each orientation has its own shuffled deck, so every photo is shown once before any comes round again.
- **Fills the opening.** By default photos fill the mat's opening and are cropped to fit, which keeps the border even. "Fit inside it" shows the whole photo instead, which leaves the border uneven.
- **Sets the margin in inches.** The margin runs from ¼ to 2½ inches and snaps to ½, ¾, 1, 1¼, 1½ and 2, with a button for each. There's an option for a deeper bottom margin (an extra ¼ inch), as framers often do.
- **Offers three mat colours:** black, charcoal and off-white.
- **Draws a bevelled edge.** Like the 45° cut of a real mat, a thin band (0.08 inch) runs around the opening. Each side is shaded as if lit from the upper left, and the mat casts a faint shadow onto the photo. The core can match the mat colour (the default), be white (the classic cream line), or come **from the photo**: Mat finds each photo's most prominent colour (ignoring greys) and uses a softened version of it, so the core changes with each picture while the mat stays put. Or the bevel can be turned off. It sits in the mat, so the photo keeps its full opening.
- **Turns off at night.** Between set times (11 pm to 7 am by default) the screen fades to black. Tap to wake it for 15 minutes.
- **Stays on** while it's open, and downloads photos kept only in iCloud as they come up.

Tap the screen to open or close the settings. Swipe left for the next photo and right for the previous one.

The margin maths assumes 132 points per inch, which is right for every current iPad except the iPad mini (163 points per inch, which Mat detects). Black mats look best on an OLED iPad (iPad Pro from 2024 on); on other iPads, black glows slightly in a dark room, so charcoal or off-white may look better.

## Install it on your iPad

Mat isn't on the App Store, so you build it yourself with Xcode. That needs a Mac, Xcode 16 or later, and an Apple ID.

1. Clone this repository and open `Mat.xcodeproj` in Xcode.
2. Set up signing. Either:
   - copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill in your team ID and a bundle id prefix (this file is git-ignored); or
   - select the Mat target, open **Signing & Capabilities**, choose your team, and change the bundle identifier to something of your own.
3. Plug the iPad into the Mac, unlock it, and tap **Trust**.
4. On the iPad, turn on Settings › Privacy & Security › **Developer Mode**. The iPad restarts and asks you to confirm.
5. In Xcode, choose the iPad as the run destination and press ⌘R.

With a paid Apple Developer account, the app keeps working for a year before you need to run it from Xcode again. A free Apple ID works too, but the app stops opening after 7 days.

## Set up the frame

1. Open Mat, allow **Full Access** to Photos, and choose an album. ("Limited" access only shows photos you pick by hand, so new photos added to the album won't appear.)
2. Put the iPad in the frame and adjust the margin until it looks right with the bezel.
3. Turn off Settings › Face ID & Passcode › **Attention Aware Features** (on iPads with Face ID). Otherwise the screen dims after a few minutes, because nobody is looking at a picture frame.
4. Turn on Settings › Accessibility › **Guided Access** and set a passcode. Open Mat and triple-click the top button to lock the iPad to it. Triple-click again and enter the passcode to leave.
5. Keep the iPad plugged in.

## Testing in the simulator

Debug builds accept a few launch arguments (see `Mat/DebugSeed.swift`; they don't exist in Release builds):

- `-MatSeedAlbum YES` puts every photo in the library into a "Mat Test" album and selects it, since `simctl addmedia` can add photos but can't make albums.
- `-MatRotateAfter 6` turns the interface to landscape after 6 seconds, to test the orientation switch mid-slideshow.
- Any setting can be overridden for one run, for example `-interval 5` or `-nightStart 0 -nightEnd 1439`.

To change settings on an iPad from the Mac (this works in Release builds too), add `-MatApply YES` and the settings are saved:

```bash
xcrun devicectl device process launch --device <udid> --terminate-existing <bundle id> -- -MatApply YES -bevel fromPhoto
```

```bash
xcrun simctl addmedia <device> photos/*.jpg
xcrun simctl launch <device> <bundle id> -MatSeedAlbum YES -interval 5
```

## Licence

MIT. See `LICENSE`.
