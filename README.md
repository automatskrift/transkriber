# SkrivDetNed - Automatisk Lydtranskribering til macOS

SkrivDetNed er en macOS-applikation der automatisk transkriberer lydoptagelser ved hjælp af AI-baseret talegenkendelse. Appens hovedfunktion er automatisk overvågning af mapper, så nye lydfiler automatisk bliver transkriberet.

## 🎯 Funktioner

### 📁 **Automatisk Mappeovervågning**
- Overvåg en valgfri mappe (inkl. iCloud Drive) for nye lydfiler
- Automatisk detektion og transskribering af nye optagelser
- Understøtter: `.m4a`, `.mp3`, `.wav`, `.aiff`, `.caf`, `.aac`, `.flac`
- Intelligent håndtering af iCloud-synkronisering
- Debounce-logik sikrer at filen er færdig med at blive skrevet

### 🎤 **Manuel Transskribering**
- Vælg enkeltfiler til transskribering
- Drag-and-drop support
- Real-time progress tracking
- Visning af lydfil-information (varighed, format)

### ⚙️ **Whisper Model Management**
- Download og administrer Whisper AI-modeller
- Vælg mellem 5 modeller (tiny, base, small, medium, large)
- Balance mellem hastighed og nøjagtighed
- Lokal lagring af modeller

### 🔔 **Notifikationer & Indstillinger**
- Notifikationer ved færdig transskribering
- Valgfri automatisk sletning af lydfiler efter transskribering
- Sprog-indstillinger (Dansk, Engelsk, Svensk, Norsk)
- Start ved login

## 🏗️ Arkitektur

Projektet følger MVVM (Model-View-ViewModel) arkitektur:

```
SkrivDetNed/
├── Models/               # Data modeller
│   ├── WhisperModel.swift
│   ├── TranscriptionTask.swift
│   └── AppSettings.swift
├── Views/                # SwiftUI views
│   ├── MainView.swift
│   ├── FolderMonitorView.swift
│   ├── ManualTranscriptionView.swift
│   └── SettingsView.swift
├── ViewModels/           # Business logic
│   ├── FolderMonitorViewModel.swift
│   ├── TranscriptionViewModel.swift
│   └── ModelManagerViewModel.swift
├── Services/             # Core funktionalitet
│   ├── FolderMonitorService.swift    # FSEvents-baseret overvågning
│   ├── WhisperService.swift          # AI transskribering
│   ├── ModelDownloadService.swift    # Model downloads
│   └── AudioFileService.swift        # Audio fil håndtering
└── Utilities/            # Hjælpefunktioner
    ├── FileSystemHelper.swift
    ├── iCloudHelper.swift
    └── Extensions.swift
```

## 🚀 Kom i Gang

### Forudsætninger
- macOS 14.0 eller nyere (kan justeres til ældre versioner)
- Xcode 15.0 eller nyere
- Apple Developer Account (til code signing)

### Installation

1. **Klon repository:**
   ```bash
   git clone https://github.com/yourusername/transkriber.git
   cd transkriber
   ```

2. **Åbn projektet i Xcode:**
   ```bash
   open SkrivDetNed/SkrivDetNed.xcodeproj
   ```

3. **Konfigurer Code Signing:**
   - Åbn projektet i Xcode
   - Vælg SkrivDetNed target
   - Gå til "Signing & Capabilities"
   - Vælg dit development team

4. **Build og kør:**
   - Tryk `Cmd + R` eller klik på "Run" knappen

### Første Gang Setup

1. **Download en Whisper model:**
   - Åbn appen
   - Gå til "Indstillinger" tab
   - Vælg en model (anbefaler "base" til start)
   - Klik "Download"

2. **Vælg en mappe til overvågning:**
   - Gå til "Overvågning" tab
   - Klik "Vælg Folder"
   - Vælg den mappe du vil overvåge
   - Klik "Start Overvågning"

3. **Test transskribering:**
   - Kopier en lydfil til den overvågede mappe
   - Appen vil automatisk starte transskribering
   - Resultatet gemmes som `.txt` fil ved siden af lydfilen

## 🔧 Tekniske Detaljer

### Folder Monitoring
Appen bruger macOS FSEvents API til effektiv folder overvågning:
- Real-time detektion af nye filer
- Minimal CPU-forbrug
- Understøtter iCloud Drive

### iCloud Support
Speciel håndtering af iCloud-synkroniserede filer:
- Detektion af `.icloud` placeholder filer
- Automatisk download triggering
- Venter på synkronisering før transskribering

### Whisper Integration
Aktuelt bruger appen Apple's Speech Recognition som fallback:
- Lokal behandling (ingen data sendes til cloud)
- Høj nøjagtighed for dansk
- Kan udvides med whisper.cpp for offline AI

## 🎨 Features

### Current Implementation
- ✅ SwiftUI-baseret moderne UI
- ✅ Dark mode support
- ✅ Real-time progress tracking
- ✅ Notification system
- ✅ App Sandbox support
- ✅ Security-scoped bookmarks for folder access
- ✅ Model download med progress
- ✅ Queue system for multiple filer

### Fremtidige Forbedringer
- 🔄 Integration af whisper.cpp for offline AI
- 🔄 Batch processing af eksisterende filer
- 🔄 Export til forskellige formater
- 🔄 Avanceret audio pre-processing
- 🔄 Menu bar app mode
- 🔄 Keyboard shortcuts

## 🔐 Sikkerhed & Permissions

Appen anvender macOS App Sandbox og kræver følgende permissions:
- **User Selected Files (Read/Write)**: For at læse lydfiler og skrive transskriptioner
- **File Bookmarks**: For persistent adgang til valgte mapper
- **Network Client**: For at downloade Whisper modeller

## 📝 Licens

Dette projekt er udviklet af Tomas Thøfner.

## 🤝 Bidrag

Bidrag er velkomne! Åbn gerne issues eller pull requests.

## 📧 Support

Hvis du oplever problemer eller har spørgsmål, åbn venligst et issue på GitHub.

---

**Note:** Denne app er optimeret til dansk, men understøtter også andre sprog gennem indstillinger.
