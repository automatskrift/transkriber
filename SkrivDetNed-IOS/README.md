# SkrivDetNed iOS

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18.0+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" />
</p>

**SkrivDetNed** er en iOS companion app til SkrivDetNed macOS, der gør det muligt at optage lyd på din iPhone og automatisk få det transskriberet via din Mac.

## ✨ Features

### 🎙️ Audio Optagelse
- **High-quality recording** med AAC komprimering
- **Real-time waveform visualization** under optagelse
- **Pause/Resume** funktionalitet
- **Metadata support**: titel, tags, og noter
- **3 kvalitetsniveauer**: Lav (32 kbps), Medium (64 kbps), Høj (128 kbps)

### ☁️ iCloud Integration
- **Automatisk upload** til iCloud efter optagelse
- **Automatisk download** af transskriptioner
- **Real-time sync** med macOS app
- **Background upload** fortsætter selv når app lukkes
- **Status tracking**: Lokal → Uploader → Synkroniseret → Transkriberes → Færdig

### 📱 Brugervenlig Interface
- **5-tab navigation**:
  - 🎙️ **Optag**: Record med stor, animeret knap
  - 📂 **Optagelser**: Liste over alle optagelser
  - 🔍 **Søg**: Søg i alt indhold og transskriptioner
  - 📄 **Transkrip.**: Kun transskriberede optagelser
  - ⚙️ **Indstillinger**: App konfiguration

### 🔔 Notifikationer
- Push notifikation når transskription er klar
- Upload success/failure notifikationer
- Badge count for nye transskriptioner

### 🎵 Audio Afspilning
- Indbygget audio player
- Skip forward/backward (15 sekunder)
- Progress bar med tid
- Afspil direkte fra detail view

### 🔍 Søgning & Organisation
- Søg i:
  - Titler
  - Tags
  - Noter
  - Transskriptionstekst
- Sortering:
  - Nyeste først
  - Ældste først
  - Navn
  - Størrelse
- Swipe actions (slet, del)

## 🏗️ Arkitektur

### MVVM Pattern
```
SkrivDetNed/
├── Models/              # Data models
│   ├── Recording.swift
│   ├── RecordingMetadata.swift (delt med macOS)
│   └── AppSettings.swift
├── ViewModels/          # Business logic
│   ├── RecordingViewModel.swift
│   └── RecordingsListViewModel.swift
├── Views/               # SwiftUI views
│   ├── Recording/
│   ├── Recordings/
│   ├── Search/
│   ├── Transcriptions/
│   └── Settings/
└── Services/            # Core services
    ├── AudioRecordingService.swift
    ├── iCloudSyncService.swift
    └── NotificationService.swift
```

### Key Services

#### AudioRecordingService
- Håndterer AVAudioRecorder
- Real-time audio level monitoring
- Pause/resume support
- Permission handling

#### iCloudSyncService
- NSMetadataQuery-baseret monitoring
- Automatisk upload med NSFileCoordinator
- Background upload support
- Transcription download

#### NotificationService
- UNUserNotificationCenter integration
- Transcription ready notifications
- Upload status notifications

## 🚀 Kom I Gang

### Krav
- iOS 18.0+
- Xcode 16.0+
- iCloud account (samme som macOS)
- SkrivDetNed macOS app installeret

### Installation

1. **Clone repository**
```bash
git clone https://github.com/yourusername/SkrivDetNed-IOS.git
cd SkrivDetNed-IOS/SkrivDetNed
```

2. **Åbn i Xcode**
```bash
open SkrivDetNed.xcodeproj
```

3. **Konfigurer iCloud**
   - Vælg dit team i Signing & Capabilities
   - Verificer iCloud container: `iCloud.dk.omdethele.SkrivDetNed`

4. **Build og Run**
   - Vælg din device eller simulator
   - Tryk Cmd+R

### Første Gang Setup

1. **Tillad Mikrofon**
   - App vil bede om mikrofon adgang
   - Accepter for at kunne optage

2. **Tillad Notifikationer**
   - App vil bede om notifikation adgang
   - Accepter for at modtage transskription alerts

3. **Log ind på iCloud**
   - Samme account som på din Mac
   - Verificer i Settings → Apple ID

4. **Start macOS App**
   - Åbn SkrivDetNed på din Mac
   - Enable "iCloud Sync" i indstillinger
   - Download mindst én Whisper model

## 📖 Brug

### Lav en Optagelse

1. Åbn app → "Optag" tab
2. Tap den store røde knap
3. Tal tydeligt (dansk eller valgt sprog)
4. Se waveform visualization
5. (Valgfri) Tilføj titel, tags, noter
6. Tap stop knappen
7. Optagelse uploades automatisk til iCloud

### Se Transskription

1. Vent på notifikation (~3-5 minutter for 30 sek audio)
2. Åbn app → "Optagelser" tab
3. Find din optagelse (status: "Færdig")
4. Tap for at åbne detaljer
5. Scroll til "Transskription"
6. Kopier tekst hvis ønsket

### Søg i Optagelser

1. "Søg" tab
2. Indtast søgeord
3. Finder matches i:
   - Titler
   - Tags
   - Noter
   - Transskriptionstekst

## 🔧 Konfiguration

### Indstillinger

**Optagelse:**
- Lydkvalitet: Lav/Medium/Høj
- Pause ved opkald: Automatisk pause ved indgående kald
- Fortsæt i baggrund: Recording fortsætter i baggrunden

**iCloud Sync:**
- Auto-upload til iCloud: Upload automatisk efter optagelse
- Auto-download transskriptioner: Download transskriptioner automatisk

**Transskribering:**
- Sprog: Vælg sprog for transskribering
- Vis notifikationer: Modtag push notifikationer
- Slet lyd efter transskribering: Fjern lydfil når transskriberet

**Privatliv:**
- Tilføj lokation: Gem GPS koordinater med optagelser

## 🧪 Testing

Se [TESTING_GUIDE.md](TESTING_GUIDE.md) for komplet test guide.

**Quick Test:**
```
1. Record 30 sekunder audio
2. Upload til iCloud (automatisk)
3. Vent ~3-5 minutter
4. Modtag notifikation
5. Verificer transskription
```

## 📊 Workflow Diagram

```
┌─────────────┐
│   iOS App   │
│  (Recording)│
└──────┬──────┘
       │ 1. Record audio
       │ 2. Upload to iCloud
       ▼
┌─────────────┐
│   iCloud    │
│   Drive     │
└──────┬──────┘
       │ 3. Sync to Mac
       ▼
┌─────────────┐
│  macOS App  │
│ (Transcribe)│
└──────┬──────┘
       │ 4. Whisper transcription
       │ 5. Upload .txt to iCloud
       ▼
┌─────────────┐
│   iCloud    │
│   Drive     │
└──────┬──────┘
       │ 6. Sync to iPhone
       ▼
┌─────────────┐
│   iOS App   │
│  (Display)  │
└─────────────┘
       │ 7. Show notification
       │ 8. Display transcription
```

## 🐛 Troubleshooting

### Optagelse Virker Ikke
- Verificer mikrofon permission (Settings → SkrivDetNed → Microphone)
- Genstart app
- Check console for fejl

### iCloud Upload Fejler
- Verificer iCloud login
- Check netværk forbindelse
- Verificer lagerplads i iCloud
- Check Settings → iCloud Sync er enabled

### Ingen Transskription
- Verificer macOS app kører
- Check macOS har model downloadet
- Verificer samme iCloud account
- Pull-to-refresh i "Optagelser" tab

### Ingen Notifikationer
- Settings → SkrivDetNed → Notifications (allow)
- App Settings → Vis notifikationer (enabled)
- Check Do Not Disturb er slukket

## 🔐 Privatliv & Sikkerhed

- **Lokal optagelse**: Audio gemmes kun lokalt indtil upload
- **End-to-end iCloud**: Kun din iCloud account har adgang
- **Ingen cloud processing**: Transskribering sker på din Mac (offline)
- **Ingen tracking**: App sender ingen analytics eller data til tredjepart
- **Mikrofon kun under optagelse**: Permission bruges kun når du optager

## 📄 Licens

MIT License - se LICENSE fil

## 🙏 Acknowledgments

- **Whisper.cpp**: For fantastisk open-source transskribering
- **AVFoundation**: Apple's audio framework
- **SwiftUI**: For moderne iOS UI

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/SkrivDetNed-IOS/issues)
- **Dokumentation**: Se [TESTING_GUIDE.md](TESTING_GUIDE.md) og [iOS_APP_SPECIFICATION.md](iOS_APP_SPECIFICATION.md)

---

**Udviklet med ❤️ i Danmark**
