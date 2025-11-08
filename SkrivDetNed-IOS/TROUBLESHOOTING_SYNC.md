# iCloud Sync Troubleshooting Guide

## Problem: Optagelser kommer ikke fra iOS til macOS

### Quick Checklist

#### På iOS (iPhone/iPad):
1. [ ] **Er du logget ind på iCloud?**
   - Gå til Settings → [Dit navn] → iCloud
   - Verificer at iCloud Drive er slået til

2. [ ] **Er "Auto-upload til iCloud" aktiveret i app'en?**
   - Åbn SkrivDetNed app
   - Gå til "Indstillinger" tab
   - Under "iCloud Sync" skal "Auto-upload til iCloud" være **ON** (grøn)

3. [ ] **Har du internetforbindelse?**
   - Test i Safari eller anden app
   - Både WiFi og cellular data virker

4. [ ] **Se Console logs under optagelse:**
   - Kør app via Xcode
   - Efter optagelse, kig efter disse logs:
   ```
   💾 Recording metadata saved: [UUID].json
   📤 Uploading recording_XXXX.m4a to iCloud...
   ✅ Successfully uploaded recording_XXXX.m4a to iCloud
   ☁️ Recording uploaded to iCloud
   ```

5. [ ] **Hvis du ser fejl:**
   ```
   ⚠️ Failed to upload to iCloud: [error]
   ❌ Failed to upload recording: [error]
   ```
   - Noter fejlbeskeden og se nedenfor

#### På macOS:
1. [ ] **Er du logget ind på samme iCloud konto?**
   - System Settings → Apple ID
   - Skal være **samme** account som på iOS

2. [ ] **Er "iCloud Sync" aktiveret i app'en?**
   - Åbn SkrivDetNed macOS app
   - Gå til Settings (⚙️ ikon)
   - Under "iCloud Sync" skal "Enable iCloud Sync" være **checked**

3. [ ] **Kører macOS app'en?**
   - App skal være åben (kan minimeres til menubar)
   - Check menu bar for SkrivDetNed ikon

4. [ ] **Se Console logs når app starter:**
   ```
   ✅ iCloud is available
   📁 iCloud container URL: /Users/.../Library/Mobile Documents/iCloud~dk~omdethele~SkrivDetNed/Documents
   🔍 Started monitoring iCloud for new audio files
   ```

5. [ ] **Når iOS uploader, kig efter:**
   ```
   ✨ New audio file detected: recording_XXXX.m4a
   📱 New file from iCloud: recording_XXXX.m4a
   ```

## Diagnostiske Tests

### Test 1: Verificer iCloud Container
Kør dette i Terminal på macOS:

```bash
# Se om container findes
ls -la ~/Library/Mobile\ Documents/ | grep SkrivDetNed
```

Forventet output:
```
drwx------@ 3 user  staff   96 Nov  7 22:00 iCloud~dk~omdethele~SkrivDetNed
```

Hvis mappen IKKE findes:
- iCloud er ikke konfigureret korrekt
- Prøv at logge ud og ind igen i iCloud

### Test 2: Check iCloud Status via Xcode Console

**På iOS (når du optager):**
```
🎙️ Recording started
⏹️ Recording stopped
💾 Recording metadata saved: [UUID].json
📤 Uploading recording_XXXX.m4a to iCloud...
```

**Hvis upload fejler:**
- "container not available" → iCloud ikke logget ind
- "not signed in" → iCloud account mangler
- "permission denied" → Check entitlements

**På macOS (skal automatisk se filen):**
```
🔍 Started monitoring iCloud for new audio files
📊 iCloud query finished gathering. Found X files
✨ New audio file detected: recording_XXXX.m4a
📱 New file from iCloud: recording_XXXX.m4a
```

### Test 3: Manuel iCloud Test
1. **På iOS device via Files app:**
   - Åbn Files app
   - Gå til "iCloud Drive"
   - Kig efter "SkrivDetNed" folder
   - Indeni skal være "Recordings" folder
   - Efter optagelse, check om .m4a fil dukker op her

2. **På macOS via Finder:**
   - Åbn Finder
   - Gå til iCloud Drive
   - Kig efter "SkrivDetNed" → "Recordings"
   - Filen skal dukke op automatisk efter iOS upload

### Test 4: Check Entitlements

**iOS Entitlements:**
```bash
cd /Volumes/DokuSystem\\(1tb\\)/GitHub/transkriber/SkrivDetNed-IOS/SkrivDetNed/SkrivDetNed/
cat SkrivDetNed.entitlements
```

Skal indeholde:
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.dk.omdethele.SkrivDetNed</string>
</array>
```

**macOS Entitlements:**
```bash
cd /Volumes/DokuSystem\\(1tb\\)/GitHub/transkriber/SkrivDetNed/SkrivDetNed/
cat SkrivDetNed.entitlements
```

Skal også indeholde samme container ID.

## Almindelige Problemer & Løsninger

### Problem 1: "iCloud is not available"
**Symptomer:** Console viser "⚠️ iCloud is not available"

**Løsning:**
1. Verificer iCloud login på device
2. Genstart device
3. I System Settings → iCloud → iCloud Drive → Check at app har adgang

### Problem 2: Fil uploader men kommer ikke til macOS
**Symptomer:** iOS siger "✅ Successfully uploaded" men macOS ser ingenting

**Løsning:**
1. **Check macOS app kører:**
   - App skal være åben for at monitorere
   - Check menu bar icon

2. **Genstart iCloud monitoring på macOS:**
   - I macOS app Settings
   - Slå "Enable iCloud Sync" FRA
   - Vent 5 sekunder
   - Slå "Enable iCloud Sync" TIL igen
   - Genstart app

3. **Force iCloud sync:**
   ```bash
   # På macOS Terminal
   killall bird
   ```
   Dette genstarter iCloud daemon

### Problem 3: Filer synkroniserer langsomt
**Symptomer:** Fil dukker op efter 5-10 minutter

**Mulige årsager:**
- Dårlig netværksforbindelse
- Stor fil størrelse
- iCloud lagerplads fuld
- iCloud throttling (ved mange uploads)

**Løsning:**
- Check netværkshastighed
- Check iCloud storage: Settings → [Name] → iCloud → Manage Storage
- Vent - første gang kan være langsommere
- Mindre filer (<1MB) er hurtigere

### Problem 4: "Container not available"
**Symptomer:** "❌ Failed to get iCloud container URL"

**Løsning:**
1. **Verificer app har iCloud capability i Xcode:**
   - Åbn projekt i Xcode
   - Select target → Signing & Capabilities
   - Check "iCloud" capability er tilføjet
   - Verificer "iCloud Documents" er checked

2. **Verificer Developer account:**
   - iCloud kræver betalt Apple Developer account
   - Check at signing fungerer

3. **Clean build:**
   ```bash
   # I Xcode
   Product → Clean Build Folder (Shift+Cmd+K)
   # Rebuild project
   ```

### Problem 5: Permission fejl
**Symptomer:** "Permission denied" når der uploades

**Løsning:**
1. **Check file permissions:**
   ```bash
   ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/
   ```

2. **Reset iCloud permissions:**
   - På iOS: Settings → General → Reset → Reset Location & Privacy
   - På macOS: System Settings → Privacy & Security → Full Disk Access
   - Genstart devices

## Debug Mode

### Aktivér Detaljeret Logging

Tilføj dette midlertidigt til koden for ekstra debug info:

**I iOS iCloudSyncService.swift uploadRecording:**
```swift
print("🔍 DEBUG: iCloudService.isAvailable = \(isAvailable)")
print("🔍 DEBUG: recordingsFolder = \(recordingsFolder?.path ?? "nil")")
print("🔍 DEBUG: settings.iCloudAutoUpload = \(AppSettings.shared.iCloudAutoUpload)")
print("🔍 DEBUG: File exists at local path: \(FileManager.default.fileExists(atPath: recording.localURL.path))")
```

**I macOS iCloudSyncService.swift queryDidUpdate:**
```swift
print("🔍 DEBUG: Query update received")
print("🔍 DEBUG: Added items count: \(addedItems?.count ?? 0)")
```

## Næste Skridt hvis Ingenting Virker

1. **Verificer Simple iCloud Test:**
   - Opret en test fil på iOS via Files app i SkrivDetNed folder
   - Se om den dukker op på macOS
   - Hvis ikke = generelt iCloud problem, ikke app-specifikt

2. **Check Apple System Status:**
   - Gå til https://www.apple.com/support/systemstatus/
   - Check om "iCloud Drive" er grøn

3. **Kontakt logs:**
   - Gem console output fra både iOS og macOS
   - Note præcis hvornår optagelse starter/slutter
   - Note device models og OS versioner

4. **Alternativ test:**
   - Test på anden iOS device hvis muligt
   - Test på anden macOS machine hvis muligt
   - Hjælper med at isolere om det er device- eller account-specifikt

## Quick Fix Kommandoer

```bash
# Genstart iCloud på macOS
killall bird

# Check iCloud status
brctl log --wait --shorten

# Se iCloud container indhold
ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/

# Force download af iCloud filer (macOS)
brctl download ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/
```

## Hvad Fortæller Mig

Send mig:
1. **Console output fra iOS** når du optager (hele output fra start til slut)
2. **Console output fra macOS** når app starter
3. **Resultat af denne kommando:**
   ```bash
   ls -la ~/Library/Mobile\ Documents/ | grep SkrivDetNed
   ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/ 2>/dev/null
   ```
4. **Screenshot af iOS Settings** → iCloud Sync section
5. **Screenshot af macOS Settings** → iCloud Sync section

Så kan jeg hjælpe med at finde den præcise årsag! 🔍
