# 🧪 Testing Guide - SkrivDetNed iOS App

## ✅ Build Status

**BUILD SUCCEEDED** - App kompilerer uden fejl!

## 🎯 Næste Skridt: Test iCloud Upload

Dette er en KOMPLET guide til at teste og debugge iCloud upload funktionalitet.

## 🔍 Debug iCloud Upload Problem

### Step 1: Rebuild App i Xcode

**VIGTIGT: Clean build først!**

1. Åbn `/Volumes/DokuSystem(1tb)/GitHub/transkriber/SkrivDetNed-IOS/SkrivDetNed/SkrivDetNed.xcodeproj` i Xcode
2. **Product → Clean Build Folder** (Shift+Cmd+K)
3. Vent til clean er færdig
4. **Product → Build** (Cmd+B)
5. Vælg **din fysiske iPhone** som destination (ikke simulator til iCloud test)
6. **Product → Run** (Cmd+R)

### Step 2: Verificer iCloud er Konfigureret Korrekt

**På iOS Device:**
```
Settings → [Your Name] → iCloud
├─ Verificer du er logget ind
├─ iCloud Drive = ✅ ON
└─ Check samme Apple ID som Mac
```

**På Mac:**
```
System Settings → Apple ID → iCloud
├─ Verificer du er logget ind
├─ iCloud Drive = ✅ ON
└─ Check samme Apple ID som iOS
```

### Step 3: Åbn Console App (Mac) - VIGTIG!

**Dette er KRITISK for debugging:**

1. Find Console.app i `/Applications/Utilities/`
2. Vælg din **iPhone** i venstre sidebar (under "Devices")
3. I søgefeltet øverst, skriv: `SkrivDetNed`
4. Klik på filter-ikonet og vælg:
   - Process: `SkrivDetNed`
   - Type: `Default` og `Error`
5. **LAD CONSOLE VÆRE ÅBEN** under hele testen

### Step 4: Optag Test-lydfil med Console Logging

**I iOS App:**
1. Gå til "Indstillinger" tab FØRST
2. Verificer under "iCloud Sync":
   - ✅ **"Auto-upload til iCloud"** = ON
   - ✅ **"Auto-download transskriptioner"** = ON
3. Gå til "Optag" tab
4. Tryk på den store røde cirkel for at starte
5. Tal i **10 sekunder** (tal til 10)
6. Tryk på **stop-knappen** (kvadrat)
7. **VIGTIG:** SE STRAKS I CONSOLE!

### Step 5: Analyser Console Output

**FORVENTEDE LOGS (skal alle være der i denne rækkefølge):**

```log
🛑 Stop recording called
⏹️ Stopping audio service...
📝 Recording stopped, got file: recording_2025-11-07_23-45-12.m4a
📝 Applied metadata - title: [titel]
💾 Saving recording...
📁 Recordings directory: /var/mobile/.../Documents/Recordings
💾 Recording metadata saved: [UUID].json
🔍 Checking iCloud upload - enabled: true
☁️ Starting iCloud upload...
📤 Upload requested for: recording_2025-11-07_23-45-12.m4a
   - isAvailable: true
   - Getting recordings folder...
   - Recordings folder: [iCloud path]/Documents/Recordings
   - Local file exists: true
📤 Uploading recording_2025-11-07_23-45-12.m4a to iCloud...
✅ Successfully uploaded recording_2025-11-07_23-45-12.m4a to iCloud
☁️ Recording uploaded to iCloud successfully
```

### Step 6: Tjek Hvad Du FAKTISK Ser i Console

#### Scenario A: Ser INTET i Console
**Problem:** Console er ikke konfigureret korrekt eller app crasher

**Løsning:**
1. Tjek at iPhone er valgt i Console sidebar
2. Tjek at "SkrivDetNed" process filter er sat
3. Tjek at app faktisk kører på device
4. Genstart Console app

#### Scenario B: Ser "Stop recording called" men INTET mere
**Problem:** stopRecording() fejler tidligt

**Løsning:**
1. Se efter error messages i Console
2. Check at microphone permission er givet
3. Check at optagelsen faktisk gemmes lokalt

#### Scenario C: Ser "isAvailable: false"
**Problem:** iCloud container ikke tilgængelig

**Løsning:**
1. **Check Entitlements:**
   ```bash
   # I Terminal:
   cd /Volumes/DokuSystem\(1tb\)/GitHub/transkriber/SkrivDetNed-IOS/SkrivDetNed
   cat SkrivDetNed/SkrivDetNed.entitlements

   # Skal vise:
   # iCloud.dk.omdethele.SkrivDetNed
   ```

2. **Reset Provisioning i Xcode:**
   - Select "SkrivDetNed" target
   - "Signing & Capabilities" tab
   - Under "Signing": Tryk "Download Manual Profiles"
   - Under "iCloud":
     - Click "-" for at remove capability
     - Click "+ Capability" for at add den igen
     - Vælg "iCloud"
     - Check "CloudDocuments"
     - Tilføj container: `iCloud.dk.omdethele.SkrivDetNed`

3. **Clean + Rebuild:**
   - Product → Clean Build Folder
   - Product → Build
   - Product → Run
   - Test igen

#### Scenario D: Upload starter men fejler
**Problem:** iCloud upload process fejler

**Se efter:**
```log
❌ Failed to upload recording: [fejlbesked]
```

**Løsning afhænger af fejlbesked:**

- **"Permission denied"**:
  - Delete app fra device
  - Reinstall fra Xcode
  - Grant permissions igen

- **"No such file or directory"**:
  - Disk plads problem
  - Check storage på device

- **"Container not available"**:
  - Bundle ID problem
  - Check at Bundle ID er: `dk.omdethele.SkrivDetNed`

#### Scenario E: Upload lykkedes men fil ikke i iCloud
**Problem:** Upload reporterer success men fil mangler

**Verificer fil i iCloud:**
```bash
# I Terminal på Mac:
ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/

# Skulle vise:
# recording_2025-11-07_23-45-12.m4a
# recording_2025-11-07_23-45-12.json
```

**Hvis filen mangler:**
- iCloud sync er forsinket (vent 1-2 minutter)
- iCloud Drive er fuld (check storage)
- iCloud sync er paused (check System Settings)

### Step 7: Verificer iCloud Status Ikoner i App

**Gå til "Optagelser" tab i iOS app:**

Du skal se EN af disse status på højre side:

| Ikon | Tekst | Farve | Betyder |
|------|-------|-------|---------|
| 📱 | Lokal | Grå | Kun på device, upload pending |
| ☁️↑ + spinner | Uploader... | Blå | Upload i gang LIGE NU |
| ☁️✓ | Synkroniseret | Grøn | Upload færdig, i iCloud |
| ❗☁️ | Fejlet | Rød | Upload fejlede |

**Hvis du ser "Fejlet" (rød):**
- Pull-to-refresh for retry
- Check Console for fejlbesked
- Følg fejlfinding ovenfor

### Step 8: Verificer Fil Fysisk Findes i iCloud

**Terminal kommando:**
```bash
# List alle filer i iCloud Recordings folder:
ls -lah ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/

# Søg efter din specifikke fil:
find ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed -name "*.m4a" -mtime -1

# Se ALLE iCloud containers du har:
ls -la ~/Library/Mobile\ Documents/ | grep -i skriv
```

**Forventet output:**
```
drwx------  iCloud~dk~omdethele~SkrivDetNed
```

**Hvis du ser to containers:**
```
drwx------  iCloud~dk~omdethele~SkrivDetNed  ← Korrekt
drwx------  iCloud~SkrivDetNed               ← Gammel/forkert
```

**Løsning hvis to containers:**
```bash
# Slet den forkerte gamle container (VIGTIGT: kun den uden "dk.omdethele"):
rm -rf ~/Library/Mobile\ Documents/iCloud~SkrivDetNed

# Genstart Mac
# Genstart iPhone
```

## 🚨 Hvis INTET af Ovenstående Virker

### Nuclear Option: Full Reset

**1. Clean Xcode Derived Data:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SkrivDetNed-*
rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

**2. Reset iCloud Container (Mac):**
```bash
# ADVARSEL: Dette sletter ALLE iCloud filer for denne app
rm -rf ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed
```

**3. Delete App fra iOS:**
- Long-press app icon
- Delete app
- Settings → General → iPhone Storage → SkrivDetNed → Delete App

**4. Genstart begge enheder:**
- Genstart Mac
- Genstart iPhone

**5. Vent 5 minutter på iCloud sync**

**6. Rebuild alt:**
```bash
cd /Volumes/DokuSystem\(1tb\)/GitHub/transkriber/SkrivDetNed-IOS/SkrivDetNed
# Åbn i Xcode
# Clean Build Folder
# Build
# Run på device
```

**7. Test igen med Console åben**

---

## Prerequisites

### macOS App Setup
1. Open `SkrivDetNed/SkrivDetNed.xcodeproj` in Xcode
2. Ensure you're signed in to iCloud (System Settings → Apple ID)
3. Build and run the macOS app
4. In Settings:
   - Enable "iCloud Sync"
   - Enable "Monitor local folder" (optional)
   - Download at least one Whisper model (medium or large recommended)

### iOS App Setup
1. Open `SkrivDetNed-IOS/SkrivDetNed/SkrivDetNed.xcodeproj` in Xcode
2. Select your device or simulator
3. Ensure the same iCloud account is signed in
4. Build and run the iOS app
5. Grant permissions when prompted:
   - ✅ Microphone access
   - ✅ Notifications

## 📱 Step-by-Step Testing

### Phase 1: iOS Recording

1. **Open iOS App** → Navigate to "Optag" tab

2. **Configure Settings** (Optional)
   - Go to "Indstillinger" tab
   - Verify "Auto-upload til iCloud" is **ON**
   - Verify "Auto-download transskriptioner" is **ON**
   - Set "Lydkvalitet" to "Høj (128 kbps)"
   - Ensure "Vis notifikationer" is **ON**

3. **Create a Test Recording**
   - Tap the large red record button
   - Speak clearly in Danish (or selected language):
     - Example: "Dette er en test optagelse. Jeg tester SkrivDetNed systemet."
   - Watch the waveform visualization (should show audio levels)
   - Optional: Add metadata:
     - Titel: "Test Optagelse"
     - Tags: "#test #demo"
     - Noter: "Første test af systemet"
   - Tap the red stop button

4. **Verify Upload**
   - Should see success message: "Optagelse gemt"
   - If notifications enabled, expect: "Upload fuldført"
   - Check console logs for: "☁️ Recording uploaded to iCloud"

### Phase 2: iCloud Sync Verification

5. **Check iCloud Status** (on iOS)
   - Go to "Optagelser" tab
   - Find your recording
   - Status should show: "Afventer" (Pending) or "Synkroniseret" (Synced)
   - Status icon should be orange or blue

6. **Verify on macOS**
   - Open macOS SkrivDetNed app
   - Look at logs/console:
     - Should see: "✨ New audio file detected: recording_XXXX.m4a"
   - The app should automatically detect the new file

### Phase 3: macOS Transcription

7. **Monitor Transcription** (on macOS)
   - macOS app should automatically:
     1. Detect the new audio file from iCloud
     2. Start transcription (you'll see progress)
     3. Save transcription back to iCloud

   Expected console output:
   ```
   ✨ New audio file detected: recording_XXXX.m4a
   🎙️ Starting transcription for: recording_XXXX.m4a
   ⏳ Transcribing... (this may take 1-5 minutes)
   ✅ Transcription completed
   💾 Saved transcription to iCloud: recording_XXXX.txt
   ```

8. **Check Transcription Progress**
   - In macOS app, verify transcription appears in list
   - Status should change: Pending → Transcribing → Completed

### Phase 4: iOS Transcription Download

9. **Receive Notification** (on iOS)
   - Within 1-2 minutes after transcription completes
   - Should receive push notification:
     - Title: "Transskription klar"
     - Body: "'Test Optagelse' er færdig transskriberet"

10. **View Transcription** (on iOS)
    - Go to "Optagelser" tab
    - Pull to refresh if needed
    - Find your recording
    - Status should now show: "Færdig" (Completed) with green checkmark
    - Tap the recording to open details

11. **Verify Transcription Text**
    - In detail view, scroll to "Transskription" section
    - Should see your transcribed text
    - Tap "Kopier tekst" to copy to clipboard
    - Verify text accuracy

12. **Check Transcriptions Tab**
    - Go to "Transkrip." tab
    - Your recording should appear here
    - Shows only recordings with completed transcriptions

### Phase 5: Search and Organization

13. **Test Search**
    - Go to "Søg" tab
    - Search for words from your transcription
    - Should find your recording
    - Try searching by:
      - Title
      - Tags
      - Transcription text
      - Notes

14. **Test Sorting**
    - Go to "Optagelser" tab
    - Tap sort menu (arrow icon)
    - Try different sort orders:
      - Nyeste først
      - Ældste først
      - Navn
      - Størrelse

15. **Test Swipe Actions**
    - Swipe left on a recording
    - Should see:
      - Blue "Del" button
      - Red "Slet" button
    - Don't delete yet!

## 🔍 Verification Checklist

### iOS App
- [ ] Recording works with audio visualization
- [ ] Metadata can be added (title, tags, notes)
- [ ] Upload to iCloud succeeds
- [ ] Upload notification appears
- [ ] Recording appears in "Optagelser" list
- [ ] Status badge shows correct state
- [ ] Transcription notification appears when ready
- [ ] Transcription downloads automatically
- [ ] Transcription text is readable and accurate
- [ ] Search finds recordings
- [ ] Sorting works correctly
- [ ] Audio playback works in detail view
- [ ] Copy transcription works

### macOS App
- [ ] Detects new recordings from iCloud
- [ ] Transcription starts automatically
- [ ] Progress is visible
- [ ] Transcription completes successfully
- [ ] Transcription saves to iCloud
- [ ] Metadata updates correctly

### iCloud Sync
- [ ] iOS → iCloud upload works
- [ ] macOS detects new files
- [ ] macOS → iCloud transcription upload works
- [ ] iOS downloads transcriptions
- [ ] Status updates sync between devices

## 🐛 Troubleshooting

### Recording not uploading
**Problem**: Recording stays "Lokal" and doesn't upload

**Solutions**:
1. Check iCloud sign-in (Settings → Apple ID)
2. Verify "Auto-upload til iCloud" is enabled
3. Check network connection
4. Check console for error messages
5. Try manually triggering upload (future feature)

### macOS not detecting recordings
**Problem**: macOS app doesn't see new iOS recordings

**Solutions**:
1. Verify same iCloud account on both devices
2. Check macOS app has "iCloud Sync" enabled
3. Verify iCloud container ID matches: `iCloud.dk.omdethele.SkrivDetNed`
4. Check macOS Console for iCloud errors
5. Restart macOS app monitoring

### Transcription not downloading on iOS
**Problem**: Transcription completes but iOS doesn't update

**Solutions**:
1. Pull to refresh on "Optagelser" tab
2. Check "Auto-download transskriptioner" is enabled
3. Verify network connection
4. Check if file exists in iCloud Drive (Files app → iCloud Drive → SkrivDetNed → Recordings)
5. Restart iOS app

### No notifications
**Problem**: Not receiving transcription notifications

**Solutions**:
1. Check iOS Settings → SkrivDetNed → Notifications (should be allowed)
2. Verify "Vis notifikationer" is enabled in app settings
3. Check Do Not Disturb is off
4. Try recording a new test

## 📊 Expected Timeline

| Step | Action | Expected Time |
|------|--------|---------------|
| 1 | Record audio (30 sec) | 30 seconds |
| 2 | Upload to iCloud | 5-30 seconds |
| 3 | macOS detects file | 5-60 seconds |
| 4 | Transcription (30 sec audio) | 1-3 minutes |
| 5 | Upload transcription | 2-10 seconds |
| 6 | iOS downloads & notifies | 5-60 seconds |
| **Total** | **End-to-end** | **~3-5 minutes** |

*Times vary based on:*
- Audio length
- Whisper model size
- Network speed
- iCloud sync latency
- Mac processing power

## 🎯 Success Criteria

A successful end-to-end test means:

1. ✅ **Recording captured** with good audio quality
2. ✅ **Upload completed** to iCloud
3. ✅ **macOS detected** new file automatically
4. ✅ **Transcription accurate** (>90% for clear speech)
5. ✅ **iOS updated** with transcription text
6. ✅ **Notifications sent** at appropriate times
7. ✅ **Search works** across all fields
8. ✅ **No crashes** or errors

## 📝 Test Data Examples

### Good Test Phrases (Danish)
```
"Hej, dette er en test af SkrivDetNed systemet.
Jeg taler tydeligt og langsomt for at få den bedste transskription."

"I dag er det den syvende november, to tusind fem og tyve.
Vejret er godt og jeg tester min nye app."
```

### Good Test Phrases (English)
```
"Hello, this is a test of the SkrivDetNed transcription system.
I am speaking clearly to ensure accurate transcription."

"Today is November seventh, twenty twenty-five.
The weather is nice and I'm testing my new application."
```

## 🔄 Continuous Testing

For ongoing testing:

1. **Create multiple recordings** with different:
   - Lengths (10 sec, 1 min, 5 min)
   - Languages (Danish, English, etc.)
   - Audio quality (quiet, loud, background noise)

2. **Test edge cases**:
   - Very long recordings (>10 minutes)
   - Quick succession recordings
   - Offline mode (disable WiFi, record, enable WiFi)
   - Low battery conditions
   - Background recording

3. **Monitor performance**:
   - Check battery usage
   - Monitor storage space
   - Watch memory consumption
   - Track network usage

## 📞 Reporting Issues

If you find bugs, note:
1. Device model and iOS version
2. macOS version
3. Exact steps to reproduce
4. Console logs from both apps
5. iCloud account status
6. Network conditions

Happy Testing! 🎉
