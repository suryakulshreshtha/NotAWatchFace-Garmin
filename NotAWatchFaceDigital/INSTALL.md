# NotAWatchFace: install guide for Garmin Instinct 2

Release 1.0.3 · 30 Oct 2026

## What you're installing

Two watch faces, each built as its own file and copied to the watch by USB.
You switch between them from the watch's face menu. Nothing goes through the
Connect IQ Store.

| Face | What it shows |
| --- | --- |
| NotAWatchFaceAnalogue | Hour and minute hands; a seconds needle (thin, hollow arrow tip) for about 10 seconds after a wrist raise; Arabic numerals 1-12; minute track; day window below 12; date window above 6; current time in digital form inside the round subscreen |
| NotAWatchFaceDigital | Day and date; the text Bravo01One; moon phase in the round subscreen; large time (12- or 24-hour, following the watch's setting); sunrise and sunset; heart rate, steps, distance; altitude, last compass reading, pressure trend |

Neither face uses the internet, your phone or any outside service. Every value
comes from the watch's own clock, sensors and last GPS position, or is
calculated inside the face.

## Target watch and build device

These faces are made for the **Instinct 2 Solar - Tactical Edition** (45 mm).
Build both faces for Garmin's device target **instinct2**.

| Item | Value |
| --- | --- |
| Connect IQ device | Instinct 2 / Solar / Dual Power / dezl Edition (`instinct2`) |
| Screen | 176 x 176 pixels, 2 colors (black and white), memory-in-pixel |
| Connect IQ API level | 3.4 |
| Round subscreen | Yes, top-right |

Garmin's Instinct 2 Series manual lists the Solar Tactical Edition among the
Instinct 2 models, and its spec sheet gives the same 176 x 176 screen. The
smaller Instinct 2S (40 mm, 163 x 156) is a different model; don't build for
it. Both faces size themselves to the screen, but each file must be built for
the right model, or the watch may not show it.

## Install the software (one time)

You need three free tools, all from Microsoft or Garmin: VS Code, Garmin's
Monkey C extension, and Garmin's Connect IQ SDK Manager. Mac users may also
need OpenMTP for the USB copy (see "Copy to the watch over USB").

1. Install **Visual Studio Code** from https://code.visualstudio.com
2. Download Garmin's **Connect IQ SDK Manager** from
   https://developer.garmin.com/connect-iq/sdk/ and open it. Sign in with your
   Garmin account if it asks.
3. In the SDK Manager, download the latest **SDK** and set it as the active one.
4. Still in the SDK Manager, open **Devices** and download
   **Instinct 2 / Solar / Dual Power / dezl Edition**. This is the device file
   your build target `instinct2` needs.
5. In VS Code, open **Extensions**, search **Monkey C**, and install the one
   published by **Garmin**.
6. Open the command palette (Ctrl+Shift+P on Windows, Cmd+Shift+P on Mac) and
   run **Monkey C: Verify Installation**. If it reports Java missing or "Java
   path not set", follow the section below; PyCharm's or Android Studio's
   built-in Java needs no download.

### If VS Code shows "Unable to find Java in the path" or "Java path not set" (Mac)

The Monkey C extension needs a recent Java, and it looks for a `java`
command on your Mac. macOS's built-in `java` command only finds Java installed
in the system Java folder, `/Library/Java/JavaVirtualMachines`. PyCharm,
IntelliJ IDEA and Android Studio run on the JetBrains Runtime, a Java that
comes with each app, but macOS doesn't know about it until you register it in
that folder with a shortcut. Homebrew's own instructions for its Java use the
same method.

Options A and B below use `sudo`, which asks for your Mac's administrator
password and changes the system Java folder. Read each command before you run
it. Each option says how to undo it.

#### Option A: register PyCharm's built-in Java (no download; this is the route that worked for the author)

1. Confirm PyCharm's Java works:

   ```
   /Applications/PyCharm.app/Contents/jbr/Contents/Home/bin/java -version
   ```

   It should print an `openjdk version` line. The author's working version was 21;
   if Monkey C later reports a Java version problem, use Option C, which
   installs version 21.
2. Register it with macOS. This asks for your Mac's administrator password and only adds a
   shortcut; nothing is copied and PyCharm isn't changed:

   ```
   sudo ln -sfn /Applications/PyCharm.app/Contents/jbr /Library/Java/JavaVirtualMachines/pycharm-jbr.jdk
   ```
3. Check that macOS now finds it:

   ```
   java -version
   ```

   It should print the same version as step 1.
4. Quit VS Code with **Cmd+Q** and reopen it. The Java errors should be gone.
5. If "Java path not set" still appears, click **Set Java path**, press
   **Cmd+Shift+G** (opens a "Go to folder" box), type `/usr`, press
   **Return**, then click **Open**.
6. Run **Monkey C: Verify Installation** from the command palette (Cmd+Shift+P).

To undo, run `sudo rm /Library/Java/JavaVirtualMachines/pycharm-jbr.jdk`. It
removes only the shortcut.

This ties Monkey C to PyCharm. If PyCharm is uninstalled or moved out of
Applications, `java -version` stops working; switch to Android Studio's Java
with Option B.

#### Option B: switch to Android Studio's built-in Java

Use this if PyCharm is removed, or if Option A stops working. It's the same
method as Option A, pointed at Android Studio. It has not been tested by the
author, so check each step's output before moving on.

Android Studio keeps its Java at `/Applications/Android Studio.app/Contents/jbr`.
The app name contains a space, so every command below keeps that path in
quotes; the shortcut's own name has no space.

1. **Confirm Android Studio's Java works.** Keep the quotes:

   ```
   "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" -version
   ```

   Expect an `openjdk version` line.
2. **Remove the PyCharm shortcut**, if it's there, so macOS doesn't keep using it:

   ```
   sudo rm -f /Library/Java/JavaVirtualMachines/pycharm-jbr.jdk
   ```
3. **Register Android Studio's Java:**

   ```
   sudo ln -sfn "/Applications/Android Studio.app/Contents/jbr" /Library/Java/JavaVirtualMachines/android-studio-jbr.jdk
   ```
4. **Check that macOS finds it:**

   ```
   /usr/libexec/java_home -V
   java -version
   ```

   The first command lists every Java macOS knows about. The second should
   print the version from step 1.
5. **Restart and verify.** Quit VS Code with **Cmd+Q**, reopen it, and run
   **Monkey C: Verify Installation**. If "Java path not set" appears, use
   **Set Java path** > **Cmd+Shift+G** > `/usr` > **Open**, as in Option A.

Good to know:

- The shortcut follows Android Studio. If Android Studio is moved or
  uninstalled, `java -version` stops working until you register another Java.
- `sudo rm /Library/Java/JavaVirtualMachines/android-studio-jbr.jdk` removes
  only the shortcut, never Android Studio or its Java.
- Updating Android Studio replaces the app in the same place, so the shortcut
  normally keeps working.

#### Option C: download the Temurin JRE

Only needed when none of those apps is installed. A JRE is enough, since the
compiler only runs Java and never builds Java code.

1. On https://adoptium.net/temurin/releases/ choose macOS, your chip
   (**aarch64** for Apple M-series, **x64** for Intel), Package Type **JRE**,
   version **21**, and the `.pkg` file. On an unstable connection, a browser
   download can be paused and resumed.
2. Install it, then in Terminal run `/usr/libexec/java_home` and copy the
   folder it prints.
3. In VS Code Settings (Cmd+,), search **Monkey C java** and paste that folder.
4. Quit VS Code with **Cmd+Q**, reopen it, and run
   **Monkey C: Verify Installation**.

If "Unable to read device data for Devices" stays after that, open the SDK
Manager, confirm the SDK is set as the current one, then remove and
re-download the Instinct 2 device.

Command names can change between extension versions. If one isn't listed, type
**Monkey C** in the command palette to see the current list.

## Create a developer key (one time)

Every Connect IQ file must be signed with your own key. Create it once and
reuse it for every build of both faces.

1. In VS Code, run **Monkey C: Generate a Developer Key** from the command palette.
2. Save the key file in a folder **outside** both project folders, for example
   `Documents/garmin-key/`. Keep it private: never commit it to Git or share it.
3. Back that file up. A watch face rebuilt with a different key is a signature
   mismatch: developers on Garmin's forum report "Signature check failed" errors
   and the face being removed when the key isn't set up correctly.

Command-line alternative, if you prefer a terminal:

```
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

## Build each face

Each face builds to one `.prg` file. Do these steps twice: once for
`NotAWatchFaceAnalogue`, once for `NotAWatchFaceDigital`.

1. Unzip the project somewhere easy to find, such as `Documents/garmin/`.
2. In VS Code, choose **File > Open Folder** and open the project folder (the
   one containing `manifest.xml`).
3. Run **Monkey C: Build for Device** from the command palette.
4. Pick **instinct2** when asked for the device, choose an output folder, and
   point it at your developer key if asked.
5. Check the output folder for `NotAWatchFaceAnalogue.prg` (or
   `NotAWatchFaceDigital.prg`). Copy the `.prg`, never an `.iq` file.

Command-line alternative, run inside the project folder:

```
monkeyc -d instinct2 -f monkey.jungle -o NotAWatchFaceDigital.prg -y /path/to/developer_key.der
```

If the build stops with an error, the message names the file and line number.
Copy the full text before changing anything.

## Test in the simulator first

Garmin's simulator shows the face with the watch's real fonts and screen
shape, so any problem shows up here, never on your wrist.

1. With the project folder open, run **Monkey C: Run** (or
   **Run > Run Without Debugging**) and pick **instinct2**.
2. The simulator opens with the face. Use its **Simulation** menu to feed in
   sensor data such as heart rate, altitude and heading.
3. Keep the VS Code debug console visible. Any crash or error appears there in red.

What to check before copying to the watch:

- [ ] Analogue: numerals sit cleanly; any that fall under the round subscreen are skipped, not cut in half
- [ ] Analogue: hands slide under the subscreen and the digital time stays readable
- [ ] Analogue: seconds needle shows, then disappears when the simulator goes to low power
- [ ] Digital: nothing overlaps, and Bravo01One is fully visible
- [ ] Digital: the six bottom fields show values, or `--` where there is no data
- [ ] Digital: the bottom-left and bottom-right values aren't clipped by the screen's cut corners
- [ ] No red errors in the debug console for either face

## Copy to the watch over USB

The whole install is copying two files into one folder. Nothing touches the
watch's firmware, and you never delete or move anything else.

1. **Close Garmin Express completely**, including its icon in the Windows
   system tray or the Mac menu bar. Developers on Garmin's forum report that
   file transfer and Garmin Express can't share the connection.
2. Connect the watch to your computer with its charging cable.
3. Open the watch's storage:
   - **Windows:** open File Explorer. The watch appears under This PC as a
     device; open it.
   - **Mac:** if the watch shows up in Finder, use that. If it doesn't, it is
     using MTP, which Finder can't read: install the free, open-source OpenMTP
     (https://openmtp.ganeshrvel.com) and open the watch there.
4. Open the **GARMIN** folder, then **APPS** (capital letters may differ, e.g.
   `Garmin/Apps`).
5. Copy `NotAWatchFaceAnalogue.prg` and `NotAWatchFaceDigital.prg` into
   **APPS**. Do not rename, move or delete any other file.
6. Eject the watch properly (Windows: **Safely Remove Hardware**; Mac: eject
   in Finder or OpenMTP), then unplug the cable.

It's normal for the two files to vanish from APPS afterwards. Developers report
the watch moves app files into internal storage as soon as it takes them in.

## Select the face on the watch

1. On the watch face, **hold MENU** (the UP button). Garmin's Instinct 2
   manual: "Hold MENU to customize the watch face."
2. Choose **Watch Face**.
3. Scroll to **NotAWatchFaceAnalogue** or **NotAWatchFaceDigital** and select
   it with the **GPS** button (top right).

Switch between your two faces, or back to a Garmin face, the same way at any time.

## Undo, update or remove a face

**Undo (instant):** hold MENU > **Watch Face** > pick any Garmin face. Your
watch is back exactly as before.

**Update:** rebuild the face and copy the new `.prg` into APPS the same way.
It has the same app ID, so it replaces the earlier version.

**Remove completely:** switch to another face first, then use one of Garmin's
own tools:

- **Connect IQ app on your phone:** Device > My Watch Faces > the face >
  Uninstall. Developers report this also lists sideloaded faces.
- **Garmin Express on your computer:** with the watch connected, open its
  **Apps** list and remove the face.

Deleting the file from the APPS folder does **not** remove it, because the
watch has already moved it into internal storage.

## Changing things later

Most display preferences follow your watch's own settings, so they need no
rebuild. Sideloaded faces can't use phone-app settings, so anything else is a
one-line edit plus a rebuild.

| What to change | Where | Rebuild? |
| --- | --- | --- |
| Label text | `NotAWatchFaceDigital/source/Settings.mc`, the text between the quotes | Yes, then copy again |
| 12- or 24-hour time (both faces, plus sunrise and sunset) | The watch's own time-format setting | No |
| km or miles (distance) | The watch's own units setting | No |
| Metres or feet (altitude) | The watch's own units setting | No |

The label holds about 10 characters next to the subscreen; anything
longer is cut off. Stick to plain letters, numbers and basic symbols.

## Troubleshooting and known limits

| What you see | Why | What to do |
| --- | --- | --- |
| Face not in the Watch Face list | Built for the wrong device, Garmin Express was open during the copy, or a key problem | Rebuild for `instinct2` with your saved key, close Garmin Express fully, copy again |
| Error icon instead of the face | The face crashed on the watch | Switch to another face, run it in the simulator, and copy the red error text from the VS Code debug console |
| Sunrise and sunset show `--:--` | The watch has no GPS position yet; a watch face can't switch GPS on itself | Do any short GPS activity outdoors. The face saves the position and keeps using it |
| Pressure arrow is a small circle | Under 2.5 hours of barometer history, which is wiped when the watch restarts | Wait a few hours |
| Pressure arrow says falling while hiking downhill | A climb or descent changes air pressure the same way weather does | Expected; trust it most when you've stayed at one altitude |
| Compass shows `---` | No heading reading yet | Open the watch's own compass, then return to the face |
| Compass never fills in | Garmin doesn't document this behaviour on watch faces | Swap field 10 for another value in NotAWatchFaceDigitalView.mc and rebuild |
| Compass differs a few degrees from the compass app | The face reads true north (per Garmin's docs); your compass may be set to magnetic north | Expected |
| Seconds needle disappears | It only shows for about 10 seconds after a wrist raise, to stay within Garmin's power limits | Expected |

Accuracy, checked against an independent astronomy library: sunrise and sunset
within 3 minutes across 64 test cases (8 cities, 4 dates including both
solstices); moon phase within about 1 day.

## Sources

Garmin documentation:

- Connect IQ compatible devices: https://developer.garmin.com/connect-iq/compatible-devices/
- Instinct 2 Series owner's manual (PDF): https://www8.garmin.com/manuals/webhelp/GUID-31D23DBB-57C2-4DF7-A0C9-8D1A00AB4BE7/EN-US/Instinct_2_Series_OM_EN-US.pdf
- Instinct 2 Solar Tactical spec sheet: https://woo.gpscentral.ca/wp-content/uploads/Garmin_Instinct_2_Solar_Tactical_Specifications.pdf
- Get the SDK: https://developer.garmin.com/connect-iq/sdk/
- API reference: https://developer.garmin.com/connect-iq/api-docs/

Developer reports on Garmin's forum (community, not official Garmin guidance):

- Sideloading, MTP, OpenMTP, closing Garmin Express: https://forums.garmin.com/developer/connect-iq/f/discussion/367718/sideload-prg-file-no-longer-working
- Modern watches connect via MTP: https://forums.garmin.com/developer/connect-iq/f/discussion/3743/can-i-test-an-app-in-my-own-device-before-submitting-it/1967819
- Sideloaded faces disappearing from APPS; signature errors: https://forums.garmin.com/developer/connect-iq/f/discussion/396208/why-does-my-watch-faces-delete-from-garmin-app
- Uninstalling watch faces: https://forums.garmin.com/developer/connect-iq/f/showcase/418758/how-to-uninstall-any-watch-face
- Phone-app settings need a store install: https://forums.garmin.com/developer/connect-iq/f/discussion/269335/change-settings-with-side-loaded-app
- Compass heading on watch faces: https://forums.garmin.com/developer/connect-iq/f/discussion/440345/best-practices-for-heading-compass-indicators-on-watch-faces-given-magnetometer-power-gating
- OpenMTP for Mac users: https://forums.garmin.com/sports-fitness/cycling/f/edge-explore-2/397019/for-mac-users-openmtp
