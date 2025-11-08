# Console Logs Reference Guide

## 🎯 Hvad Du Skal Se Efter

### På iOS - Efter Optagelse

**Forventet flow:**
```
1️⃣ Recording phase:
✅ Recording started
[record audio]
⏹️ Recording stopped

2️⃣ Save phase:
💾 Recording metadata saved: [UUID].json

3️⃣ Upload phase:
📤 Upload requested for: recording_XXXX.m4a
   - isAvailable: true
   - Getting recordings folder...
   - Recordings folder: /var/mobile/Containers/.../Documents/Recordings
   - Local file exists: true
📤 Uploading recording_XXXX.m4a to iCloud...
✅ Successfully uploaded recording_XXXX.m4a to iCloud
☁️ Recording uploaded to iCloud

4️⃣ Monitoring phase (optional):
🔍 Started monitoring iCloud for transcriptions
```

### Hvis Upload Fejler - Kig Efter:

**Problem 1: iCloud ikke tilgængelig**
```
❌ Upload failed: iCloud not available
```
**Fix:**
- Check Settings → [Name] → iCloud → iCloud Drive er ON
- Log ud og ind igen af iCloud

**Problem 2: Container ikke tilgængelig**
```
❌ Upload failed: Could not get recordings folder URL
❌ Failed to get iCloud container URL
```
**Fix:**
- Verify entitlements er korrekt
- Prøv at rebuilde app
- Check Xcode: Signing & Capabilities → iCloud → Documents er checked

**Problem 3: Lokal fil findes ikke**
```
   - Local file exists: false
```
**Fix:**
- Check AudioRecordingService gemmer filen korrekt
- Check file permissions

### På macOS - Ved Opstart

**Forventet flow:**
```
✅ iCloud is available
📱 iCloud identity token: present
📁 iCloud container: /Users/XX/Library/Mobile Documents/iCloud~dk~omdethele~SkrivDetNed/Documents
📁 Created Recordings folder in iCloud (hvis ny)
🔍 Started monitoring iCloud for new audio files
📊 iCloud query finished gathering. Found X files
```

### På macOS - Når iOS Uploader

**Forventet flow:**
```
🔄 iCloud query updated
✨ New audio file detected: recording_XXXX.m4a
   Status: NSMetadataUbiquitousItemDownloadingStatusCurrent
   URL: /Users/.../SkrivDetNed/Documents/Recordings/recording_XXXX.m4a
📱 New file from iCloud: recording_XXXX.m4a
🎙️ Starting transcription for: recording_XXXX.m4a
```

## 🔍 Debugging Specific Issues

### Issue: "isAvailable: false"

**På iOS, check:**
```
✅ iCloud is available
📱 iCloud identity token: present/missing
📁 iCloud container: [path]/not accessible
```

Hvis "missing" eller "not accessible":
1. Settings → iCloud → iCloud Drive = ON
2. Xcode → Target → Signing & Capabilities → Check iCloud capability
3. Rebuild project (Clean Build Folder)

### Issue: Upload starter aldrig

Check at `settings.iCloudAutoUpload` er true:
```swift
// I RecordingViewModel.swift:
if settings.iCloudAutoUpload {  // <- Dette skal være true
    try await iCloudService.uploadRecording(recording)
}
```

**Verificer i app:**
- iOS Settings tab → iCloud Sync → "Auto-upload til iCloud" = ON

### Issue: macOS ser ikke filen

**Check disse logs på macOS:**

**1. Er monitoring startet?**
```
🔍 Started monitoring iCloud for new audio files
📊 iCloud query finished gathering
```
Hvis NEJ → Check Settings → Enable iCloud Sync er checked

**2. Kom query update?**
```
🔄 iCloud query updated
```
Hvis NEJ → iCloud sync virker ikke
- Prøv `killall bird` i Terminal
- Check begge devices på samme WiFi

**3. Blev fil detekteret?**
```
✨ New audio file detected: recording_XXXX.m4a
```
Hvis NEJ men query updated → Fil matcher ikke predicate
- Check filnavn slutter med .m4a, .mp3, .wav, etc.

## 📊 Test Scenario

### Komplet Success Flow

**iOS Console:**
```
✅ Recording started
⏹️ Recording stopped
💾 Recording metadata saved: ABC123.json
📤 Upload requested for: recording_1699387234.m4a
   - isAvailable: true
   - Getting recordings folder...
   - Recordings folder: /var/mobile/.../Documents/Recordings
   - Local file exists: true
📤 Uploading recording_1699387234.m4a to iCloud...
✅ Successfully uploaded recording_1699387234.m4a to iCloud
☁️ Recording uploaded to iCloud
🔍 Started monitoring iCloud for transcriptions
```

**macOS Console (efter 5-30 sekunder):**
```
🔄 iCloud query updated
📄 File: recording_1699387234.m4a
   Status: NSMetadataUbiquitousItemDownloadingStatusCurrent
   URL: /Users/.../recording_1699387234.m4a
✨ New audio file detected: recording_1699387234.m4a
📱 New file from iCloud: recording_1699387234.m4a
🎙️ Starting transcription for: recording_1699387234.m4a
⏳ Transcribing...
✅ Transcription completed
💾 Saved transcription to iCloud: recording_1699387234.txt
```

**iOS Console (efter transcription):**
```
🔄 iCloud query updated
📥 Downloaded transcription for: recording_1699387234.m4a
   Length: 245 characters
✅ Updated local recording with transcription
```

## 🚨 Common Errors & Meanings

| Error | Betyder | Fix |
|-------|---------|-----|
| `iCloud is not available` | Ikke logget ind eller container fejl | Check iCloud login + entitlements |
| `Container not accessible` | App kan ikke få adgang til iCloud | Rebuild med korrekte entitlements |
| `Notifications are not allowed` | Brugeren har nægtet notifikationer | OK - ikke kritisk, app virker stadig |
| `open(/private/var/db/DetachedSignatures)` | System warning | Ignorer - harmløs |
| `No speech detected` | Whisper fandt ikke tale i audio | Optag med tydeligere tale |
| `Error (-4) getting reporterIDs` | Audio system warning | Ignorer - harmløs |

## 💡 Pro Tips

### Få Mere Debug Info

Tilføj environment variable i Xcode Scheme:
```
Name: OS_ACTIVITY_MODE
Value: disable
```
Dette fjerner Apple's debug output så du kun ser app logs.

### Filter Console Output

I Xcode Console, brug søg:
- `☁️` - Se kun iCloud logs
- `📤` - Se kun upload logs
- `❌` - Se kun fejl
- `✅` - Se kun successes

### Live Monitor

Åbn to Xcode vinduer samtidigt:
1. iOS projekt → Run på device → Se console
2. macOS projekt → Run på Mac → Se console

Så kan du se real-time sync mellem devices!

## 📝 Hvad Skal Du Sende Mig

Hvis det stadig ikke virker, send:

**Fra iOS:**
```
[Hele console output fra du starter optagelse til den stopper]
```

**Fra macOS:**
```
[Console output fra app starter]
[Console output når du forventer fil fra iOS]
```

**Plus dette:**
```bash
# Kør i Terminal på Mac:
ls -la ~/Library/Mobile\ Documents/ | grep SkrivDetNed
ls -la ~/Library/Mobile\ Documents/iCloud~dk~omdethele~SkrivDetNed/Documents/Recordings/
```

Så kan jeg se præcist hvor problemet er! 🔍
