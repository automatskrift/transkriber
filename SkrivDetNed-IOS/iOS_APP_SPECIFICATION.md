# SkrivDetNed iOS App - Komplet Specifikation

## 📱 App Oversigt

**Navn:** SkrivDetNed iOS
**Platform:** iOS 17.0+
**Formål:** Optag lydfiler der automatisk transkriberes af macOS appen via iCloud
**Sprog:** Swift, SwiftUI
**iCloud Container:** `iCloud.dk.omdethele.SkrivDetNed`

---

## 🎯 Primære Funktioner

### 1. Lydoptagelse
- **Start/Stop optagelse** med stor rød knap
- **Pause/Resume** funktionalitet
- **Realtids visning** af:
  - Optagelsens varighed
  - Lyd-niveau visualisering (waveform)
  - Fil størrelse estimation
- **Background optagelse** (fortsæt selvom skærmen låses)
- **Kvalitets indstillinger**: Lav, Medium, Høj (bitrate valg)

### 2. Optagelses Håndtering
- **Liste** over alle optagelser med status
- **Søgning og filtrering**
- **Sortering**: Nyeste, Ældste, Navn, Status
- **Swipe actions**: Slet, Del, Omdøb
- **Batch operationer**: Vælg flere, slet, download

### 3. iCloud Sync
- **Automatisk upload** til iCloud efter optagelse
- **Status tracking**:
  - 📤 Uploader til iCloud
  - ⏳ Afventer transkription
  - 🔄 Transkriberes (når macOS app processerer)
  - ✅ Færdig (transkription tilgængelig)
  - ❌ Fejl
- **Background sync** (når app lukkes)
- **Offline mode** (gem lokalt, sync senere)

### 4. Transkriptioner
- **Vis transkription** når klar
- **Copy/paste** funktionalitet
- **Del** via standard iOS share sheet
- **Export** formater: TXT, PDF, RTF
- **Søg i transkription**
- **Highlight search results**

### 5. Metadata & Organisation
- **Titel/navn** på optagelse (editerbar)
- **Tags/labels** (valgfri kategorisering)
- **Noter** (tilføj kontekst før optagelse)
- **Automatisk lokation** (hvis tilladelse givet)
- **Tidsstempel** (oprettet, transkriberet)

---

## 📐 UI/UX Design

### Tab Bar Navigation (5 tabs)

#### 1. 🎙️ Optag (Home)
```
┌─────────────────────────┐
│  SkrivDetNed           ⚙│
├─────────────────────────┤
│                         │
│    [Stor rød cirkel]    │ ← Start/Stop knap
│                         │
│   ████████████████      │ ← Waveform visualization
│   ████  ██████████      │
│                         │
│      00:02:34           │ ← Timer
│      ~2.5 MB            │ ← Fil størrelse
│                         │
│  [⏸ Pause]  [🎤 Kvalitet]│
│                         │
│  📝 Titel: _________    │
│  🏷️ Tags: #møde #arbejde│
│  📍 Lokation: København │
│                         │
└─────────────────────────┘
```

**Funktioner:**
- Stor, tydeligt START knap (grøn når klar, rød når optager)
- Live waveform animation mens der optages
- Automatisk pause ved telefonopkald
- Quick actions til titel/tags mens der optages
- Vibration feedback ved start/stop

#### 2. 📚 Optagelser (Liste)
```
┌─────────────────────────┐
│ Optagelser        [🔍+] │
├─────────────────────────┤
│ 🔴 Møde med team        │
│    2 min • I dag 14:32  │
│    ⏳ Afventer...        │
├─────────────────────────┤
│ ✅ Podcast interview     │
│    45 min • I går       │
│    📄 Transkription klar │
├─────────────────────────┤
│ 🔵 Idéer til projekt    │
│    5 min • 3 dage siden │
│    🔄 Transkriberes...  │
├─────────────────────────┤
│ ✅ Forelæsning          │
│    1t 23min • 1 uge     │
│    📄 Klar • 15.234 ord │
└─────────────────────────┘
```

**Funktioner:**
- Pull to refresh
- Status ikoner med farver
- Swipe left: Del, Slet
- Swipe right: Favorit, Arkivér
- Long press: Kontekst menu
- Empty state: "Ingen optagelser endnu" med tutorial

#### 3. 📄 Detalje View (Når klikket)
```
┌─────────────────────────┐
│ ← Møde med team     [⋯] │
├─────────────────────────┤
│ 🎙️ 2 min 34 sek        │
│ 📅 7. nov 2025, 14:32   │
│ 📍 Kontoret, København  │
│ 🏷️ #møde #team #q4      │
├─────────────────────────┤
│ Status                  │
│ ✅ Transkription færdig │
├─────────────────────────┤
│ Transkription           │
│ ┌─────────────────────┐ │
│ │ Velkommen til mødet.│ │
│ │ Vi skal tale om...  │ │
│ │ [Fuld tekst her]    │ │
│ │                     │ │
│ └─────────────────────┘ │
│                         │
│ [📋 Kopiér] [↗️ Del]    │
│                         │
│ Lydfil                  │
│ ▶️ ━━━━○━━━━━━ 2:34     │
│                         │
│ [🗑️ Slet optagelse]     │
└─────────────────────────┘
```

**Funktioner:**
- Audio player med seek
- Expand/collapse transkription
- Edit titel, tags, noter inline
- Share sheet integration
- Copy transkription
- Export til Files app

#### 4. 🔍 Søg
```
┌─────────────────────────┐
│ Søg i optagelser        │
│ [🔍 Indtast søgeord...] │
├─────────────────────────┤
│ Filtre                  │
│ [✅ Med transkription]  │
│ [  Kun favoritter]      │
│ [  Sidste uge]          │
├─────────────────────────┤
│ Søgeresultater          │
│                         │
│ 📄 Møde med team        │
│    "...diskutere budget │
│    for Q4 og fordele..." │
│                         │
│ 📄 Podcast interview    │
│    "...budget til marke-│
│    ting næste år..."    │
└─────────────────────────┘
```

**Funktioner:**
- Fuld-tekst søgning i transkriptioner
- Søg i titler, tags, noter
- Filtre: Status, dato, varighed
- Highlight matched text
- Recents searches

#### 5. ⚙️ Indstillinger
```
┌─────────────────────────┐
│ Indstillinger           │
├─────────────────────────┤
│ iCloud Sync             │
│ ☁️ iCloud tilgængelig   │
│ [✓] Auto-upload         │
│ [✓] Download transkrip. │
│                         │
│ Optagelse               │
│ Kvalitet: ● Høj         │
│ [✓] Background optagelse│
│ [✓] Pause ved opkald    │
│                         │
│ Transkription           │
│ Sprog: 🇩🇰 Dansk         │
│ [✓] Notifikationer      │
│ [✓] Auto-slet lydfil    │
│                         │
│ Lager                   │
│ Lokalt: 245 MB          │
│ iCloud: 1.2 GB          │
│ [Ryd cache]             │
│                         │
│ Om                      │
│ Version 1.0.0           │
│ [Hjælp & Support]       │
│ [Privatlivspolitik]     │
└─────────────────────────┘
```

---

## 🏗️ Teknisk Arkitektur

### App Struktur
```
SkrivDetNediOS/
├── App/
│   ├── SkrivDetNediOSApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Recording.swift          // Lokal optagelses model
│   ├── RecordingMetadata.swift  // Delt med macOS (samme fil)
│   └── AppSettings.swift
├── ViewModels/
│   ├── RecordingViewModel.swift
│   ├── RecordingsListViewModel.swift
│   ├── TranscriptionViewModel.swift
│   └── iCloudSyncViewModel.swift
├── Views/
│   ├── Recording/
│   │   ├── RecordingView.swift           // Tab 1
│   │   ├── WaveformView.swift
│   │   └── RecordingControls.swift
│   ├── Recordings/
│   │   ├── RecordingsListView.swift      // Tab 2
│   │   ├── RecordingRow.swift
│   │   └── RecordingDetailView.swift     // Tab 3
│   ├── Search/
│   │   └── SearchView.swift              // Tab 4
│   └── Settings/
│       └── SettingsView.swift            // Tab 5
├── Services/
│   ├── AudioRecordingService.swift
│   ├── iCloudSyncService.swift      // Delt logik med macOS
│   ├── MetadataService.swift
│   └── NotificationService.swift
└── Utilities/
    ├── AudioFileHelper.swift
    ├── DateFormatter+Extensions.swift
    └── String+Extensions.swift
```

### Data Flow
```
┌─────────────────┐
│  RecordingView  │
│   (UI Layer)    │
└────────┬────────┘
         │
         ↓
┌──────────────────────┐
│ RecordingViewModel   │
│ (Business Logic)     │
└────────┬─────────────┘
         │
         ↓
┌──────────────────────────┐
│ AudioRecordingService    │
│ (Audio Capture)          │
└────────┬─────────────────┘
         │
         ↓
┌──────────────────────────┐
│ iCloudSyncService        │
│ (Upload to iCloud)       │
└────────┬─────────────────┘
         │
         ↓
┌──────────────────────────┐
│ iCloud Container         │
│ (Shared Storage)         │
└────────┬─────────────────┘
         │
         ↓
┌──────────────────────────┐
│ macOS App                │
│ (Transcription)          │
└──────────────────────────┘
```

---

## 🔧 Tekniske Implementationsdetaljer

### 1. Audio Recording (AVAudioRecorder)
```swift
import AVFoundation

class AudioRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevels: [Float] = []

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = .sharedInstance()
    private var levelTimer: Timer?

    func startRecording(quality: AudioQuality) throws {
        // Configure audio session
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        // Request permission
        audioSession.requestRecordPermission { allowed in
            guard allowed else { return }
            // Setup recorder with quality settings
        }

        // Configure recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: quality.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Start recording
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        // Start level monitoring
        startLevelMonitoring()
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            self.audioLevels.append(level)
            self.duration = self.audioRecorder?.currentTime ?? 0
        }
    }
}
```

### 2. iCloud Sync Implementation
```swift
import Foundation

class iCloudSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0

    private let containerIdentifier = "iCloud.dk.omdethele.SkrivDetNed"
    private var metadataQuery: NSMetadataQuery?

    // Upload recording to iCloud
    func uploadRecording(_ recording: Recording) async throws {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        ) else {
            throw SyncError.iCloudNotAvailable
        }

        let recordingsURL = containerURL
            .appendingPathComponent("Documents/Recordings")

        // Create directory if needed
        try FileManager.default.createDirectory(
            at: recordingsURL,
            withIntermediateDirectories: true
        )

        // Copy audio file
        let destURL = recordingsURL.appendingPathComponent(recording.fileName)
        try FileManager.default.copyItem(
            at: recording.localURL,
            to: destURL
        )

        // Save metadata
        var metadata = RecordingMetadata(
            audioFileName: recording.fileName,
            createdOnDevice: "iOS"
        )
        metadata.title = recording.title
        metadata.tags = recording.tags
        metadata.notes = recording.notes
        metadata.duration = recording.duration

        try metadata.save(to: recordingsURL)

        print("✅ Uploaded to iCloud: \(recording.fileName)")
    }

    // Monitor for transcription completion
    func startMonitoringTranscriptions(
        onNewTranscription: @escaping (String, String) -> Void
    ) {
        metadataQuery = NSMetadataQuery()
        guard let query = metadataQuery else { return }

        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K LIKE '*.txt'",
            NSMetadataItemFSNameKey
        )

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { notification in
            self.handleTranscriptionUpdate(
                notification,
                callback: onNewTranscription
            )
        }

        query.start()
    }
}
```

### 3. Background Upload
```swift
class BackgroundUploadManager {
    static let shared = BackgroundUploadManager()

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "dk.omdethele.SkrivDetNed.background"
        )
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func scheduleUpload(_ recording: Recording) {
        // Use background session for reliable upload
        // iOS will complete upload even if app is terminated
    }
}
```

### 4. Push Notifications
```swift
import UserNotifications

class NotificationService {
    func sendTranscriptionCompleteNotification(
        recordingTitle: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Transkription færdig"
        content.body = "'\(recordingTitle)' er blevet transkriberet"
        content.sound = .default
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

---

## 📊 Data Models

### Recording (Local Model)
```swift
struct Recording: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let localURL: URL
    var title: String
    var tags: [String]
    var notes: String?
    let duration: TimeInterval
    let fileSize: Int64
    let createdAt: Date
    var iCloudStatus: CloudStatus
    var hasTranscription: Bool
    var transcriptionText: String?

    enum CloudStatus: String, Codable {
        case local          // Not uploaded yet
        case uploading      // Currently uploading
        case synced         // In iCloud
        case pending        // Waiting for transcription
        case transcribing   // Being transcribed
        case completed      // Transcription available
        case failed         // Error occurred
    }
}
```

---

## 🎨 Design System

### Colors
```swift
extension Color {
    static let recordingRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let successGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
}
```

### Typography
- **Headers:** SF Pro Display, Bold, 28pt
- **Body:** SF Pro Text, Regular, 17pt
- **Captions:** SF Pro Text, Regular, 13pt

### Animations
- **Record button pulse:** 0.8s loop
- **Waveform:** Real-time, 60fps
- **Status changes:** 0.3s ease-in-out
- **List updates:** Spring animation

---

## 🔐 Permissions & Privacy

### Required Permissions
1. **Microphone** (NSMicrophoneUsageDescription)
   > "SkrivDetNed har brug for mikrofon adgang for at optage lyd."

2. **Speech Recognition** (NSSpeechRecognitionUsageDescription)
   > "SkrivDetNed bruger talegenkendelse til at forbedre transkriptionen."

3. **Notifications** (NSUserNotificationsUsageDescription)
   > "SkrivDetNed sender notifikationer når transkriptioner er færdige."

4. **Location** (Optional - NSLocationWhenInUseUsageDescription)
   > "SkrivDetNed kan tilføje lokation til dine optagelser."

### Privacy
- Ingen data sendes til eksterne servere
- Alt foregår via privat iCloud container
- Transkription sker på brugerens egen Mac
- Ingen analytics eller tracking

---

## 🧪 Testing Strategy

### Unit Tests
- AudioRecordingService: Start, stop, pause, resume
- iCloudSyncService: Upload, download, metadata
- MetadataService: JSON encoding/decoding
- ViewModels: Business logic, state management

### UI Tests
- Recording flow: Start → Record → Stop → Upload
- List interactions: Swipe, search, filter
- Detail view: Play audio, copy text, share
- Settings: Toggle options, verify persistence

### Integration Tests
- End-to-end: Record → Upload → Wait for transcription
- Offline mode: Record without internet
- Background: Upload completes when app closed

---

## 📦 Dependencies

### Native Frameworks
- SwiftUI (UI)
- AVFoundation (Audio recording)
- CloudKit / NSMetadataQuery (iCloud sync)
- UserNotifications (Push notifications)
- CoreLocation (Optional location tagging)

### Third-Party (Optional)
- **Geen** - App bruger kun native iOS frameworks

---

## 🚀 Release Plan

### Version 1.0 (MVP)
- ✅ Basic recording (start/stop)
- ✅ iCloud upload
- ✅ List of recordings
- ✅ View transcriptions
- ✅ Basic settings

### Version 1.1
- 📱 Widgets (Quick record, Recent recordings)
- 🎨 Dark mode optimization
- 📤 More export formats (PDF, DOCX)
- 🔍 Advanced search filters

### Version 1.2
- 🎙️ Live transcription preview
- 📍 Location tagging
- 🏷️ Smart tags suggestions
- 📊 Statistics (total time, word count)

### Version 2.0
- 🤖 On-device transcription (iOS 17+)
- 📱 iPad optimization
- ⌚ Apple Watch companion app
- 🔗 Siri shortcuts

---

## 💡 Tips til Implementation

### Start Simple
1. Få basic recording til at virke først
2. Implementér iCloud upload
3. Byg UI'en i faser
4. Tilføj polish og detaljer til sidst

### Best Practices
- Brug MVVM arkitektur
- Hold services stateless hvor muligt
- Test på rigtig device (ikke kun simulator)
- Håndtér offline mode fra dag 1
- Log alt til Console for debugging

### Common Pitfalls
- ⚠️ Glem ikke background modes
- ⚠️ Test med langsom internet
- ⚠️ Håndtér iCloud ikke-tilgængelig
- ⚠️ Test med fyldt storage
- ⚠️ Håndtér app termination under optagelse

---

## 📝 App Store Listing

### Name
**SkrivDetNed - Lyd til Tekst**

### Subtitle
**Optag lyd, få automatisk transkription**

### Description
```
Optag lydfiler på din iPhone og få dem automatisk transkriberet
af din Mac med SkrivDetNed.

FUNKTIONER:
• Nem optagelse med pause/resume
• Automatisk upload til iCloud
• Transkription via macOS appen
• Søg i alle dine transkriptioner
• Del tekst og lyd let
• Organisér med tags og noter

PERFEKT TIL:
📚 Studerende: Optag forelæsninger
💼 Professionelle: Møder og interviews
🎙️ Content creators: Podcast forberedelse
✍️ Forfattere: Idéer og noter

HVORDAN DET VIRKER:
1. Optag på iPhone
2. Automatisk sync via iCloud
3. Mac appen transkriberer
4. Læs teksten på iPhone

Kræver macOS appen til transkription.
```

### Keywords
```
transkription, lydoptagelse, tale til tekst, whisper,
noter, diktafon, møder, studie, podcast
```

### Screenshots
1. Recording screen (store recording button)
2. Recordings list with status
3. Transcription view with text
4. Search results
5. Settings screen

---

## 🎯 Success Metrics

### KPIs
- **Adoption:** Antal downloads første måned
- **Engagement:** Gennemsnitlig optagelser per bruger
- **Retention:** % der bruger app efter 7/30 dage
- **Sync Success:** % af optagelser der syncer korrekt
- **Transcription Time:** Tid fra optagelse til transkription

### User Satisfaction
- App Store rating target: 4.5+ ⭐
- Support tickets: < 5% af brugere
- Crash-free rate: 99.5%+

---

Dette er den komplette specifikation! Vil du have mig til at uddybe nogle specifikke dele eller begynde at implementere iOS appen?
