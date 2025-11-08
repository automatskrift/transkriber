# 🚀 Quick Fix - iCloud Sync Problem

## Problem Identificeret

Du har to iCloud containers:
- ✅ `iCloud~dk~omdethele~SkrivDetNed` (korrekt - brugt af apps)
- ❌ `iCloud~SkrivDetNed` (gammel - måske fra test?)

Begge er tomme, hvilket betyder **ingen upload er lykkedes endnu**.

## 🔧 Løsning: Test Upload Manuelt

### Step 1: Verificer iCloud Virker Overhovedet

**På iOS via Simulator/Device:**

Åbn **Files** app → **iCloud Drive** → Find "SkrivDetNed" mappen

Hvis mappen IKKE findes:
1. iCloud sync er ikke aktiveret korrekt
2. Prøv nedenstående fixes

### Step 2: Clean & Rebuild iOS App

```bash
cd /Volumes/DokuSystem\(1tb\)/GitHub/transkriber/SkrivDetNed-IOS/SkrivDetNed

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/SkrivDetNed-*

# Rebuild i Xcode
# Product → Clean Build Folder (Shift+Cmd+K)
# Product → Build (Cmd+B)
```

### Step 3: Verificer Console Output

Efter rebuild, optag og stop. Du SKAL se disse logs:

```
🛑 Stop recording called
⏹️ Stopping audio service...
📝 Recording stopped, got file: recording_XXXX.m4a
💾 Saving recording...
🔍 Checking iCloud upload - enabled: true
☁️ Starting iCloud upload...
📤 Upload requested for: recording_XXXX.m4a
   - isAvailable: true
   - Getting recordings folder...
   - Recordings folder: [path]
   - Local file exists: true
📤 Uploading recording_XXXX.m4a to iCloud...
✅ Successfully uploaded recording_XXXX.m4a to iCloud
```

### Step 4: Hvis Du IKKE Ser "Stop recording called"

Det betyder knappen ikke kalder funktionen. Check:

**I RecordingView.swift:**
```swift
RecordButton(
    isRecording: viewModel.isRecording,
    isPaused: viewModel.isPaused,
    action: { viewModel.toggleRecording() }  // <- Skal kalde denne
)
```

### Step 5: Hvis "isAvailable: false"

**Problem:** iOS kan ikke få adgang til iCloud container

**Fix:**

1. **Check iOS Settings på device:**
   - Settings → [Name] → iCloud → iCloud Drive = ON
   - Settings → SkrivDetNed → Skulle være der hvis app har kørt

2. **Reset Provisioning i Xcode:**
   - Xcode → Target "SkrivDetNed"
   - Signing & Capabilities
   - Under "Signing": Tryk "Download Manual Profiles"
   - Under "iCloud": Remove og re-add capability

3. **Hvis det er Simulator:**
   - Simulator → Settings → iCloud → Log in med din Apple ID
   - Vent 1-2 minutter på sync
   - Restart simulator

4. **Hvis det er Device:**
   - Verify samme iCloud account som Mac
   - Trust computer hvis prompted

### Step 6: Manuel iCloud Test

Hvis alt fejler, test grundlæggende iCloud:

**På Mac:**
```bash
# Create test file i korrekt container
mkdir -p ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings
echo "test" > ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/test.txt
```

**På iOS:**
- Åbn Files app
- Gå til iCloud Drive → SkrivDetNed → Recordings
- Ser du test.txt efter et minut?

**Hvis JA:** iCloud virker, problemet er i app upload
**Hvis NEJ:** iCloud sync virker ikke mellem devices

### Step 7: Nuclear Option - Reset iCloud Containers

Hvis intet virker:

```bash
# På Mac - slet begge containers
rm -rf ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed
rm -rf ~/Library/Mobile\ Documents/iCloud~SkrivDetNed

# Genstart Mac
# Genstart iOS device
# Vent 5 minutter
# Containers vil blive genoprettet automatisk
```

## 🎯 Debugging Checklist

Gennemgå disse i rækkefølge:

- [ ] iOS: Settings → iCloud → iCloud Drive = ON
- [ ] iOS: Logged in med samme Apple ID som Mac
- [ ] Xcode: Clean Build Folder kørt
- [ ] Xcode: App rebuildet efter clean
- [ ] Console: Ser "Stop recording called" når stop trykkes
- [ ] Console: Ser "isAvailable: true" i upload logs
- [ ] Console: Ser "Successfully uploaded" efter upload
- [ ] Mac: Ser fil i `~/Library/Mobile Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/`
- [ ] macOS app: Settings → iCloud Sync er enabled
- [ ] macOS app: Ser "New audio file detected" i console

## 🔍 Hvad Skal Du Sende Mig

Hvis det stadig ikke virker efter ovenstående:

**1. iOS Console Output:**
```
[Kopier ALT fra når du trykker record til efter stop]
```

**2. Terminal Output:**
```bash
# Kør disse på Mac og send output:
ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/
ls -la ~/Library/Mobile\ Documents/iCloud~SkrivDetNed/Documents/ 2>/dev/null
```

**3. iOS Settings Screenshot:**
- Settings → iCloud → iCloud Drive → Apps Using iCloud Drive
- Skulle gerne se SkrivDetNed der

**4. Xcode Info:**
```
- Kører du på Simulator eller Real Device?
- Hvilken iOS version?
- Hvilken Xcode version?
```

## 💡 Mest Sandsynlige Problem

Baseret på hvad jeg ser:

**Hypotese 1:** iOS app uploader IKKE fordi `isAvailable` er false
- Fix: Check iCloud login og entitlements
- Test: Se console for "isAvailable: false"

**Hypotese 2:** Stop-knappen kalder ikke stopRecording()
- Fix: Check RecordButton integration
- Test: Se console for "Stop recording called"

**Hypotese 3:** iCloud Auto-upload er slået fra
- Fix: iOS app Settings → iCloud Sync → Auto-upload = ON
- Test: Se console for "iCloud auto-upload is disabled"

Giv mig console output så kan jeg være mere præcis! 🎯
