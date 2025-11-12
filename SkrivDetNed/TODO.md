# SkrivDetNed - TODO Liste

## Højt Prioritet

### 1. Permission Handling (Apple Krav)
- [ ] Genimplementer security-scoped bookmarks korrekt
- [ ] Håndter iCloud folder permissions
- [ ] Tilføj brugervenlige permission prompts med forklaringer
- [ ] Test at alle permissions fungerer efter app genstart
- [ ] Sørg for at permissions er persistent
- **Note:** Blev fjernet under debugging af 0 tokens problem. Skal implementeres kompatibelt med WhisperKit 0.9.4.

### 2. Model Download UX Forbedringer
- [ ] **Første gang bruger:** Vis tydelig welcome/onboarding dialog der forklarer:
  - At en Whisper model skal downloades
  - Hvor stor modellen er (Tiny: ~60MB, Base: ~140MB, etc.)
  - At det tager flere minutter første gang
  - At det kun skal gøres én gang per model
- [ ] Vis download progress bar med:
  - Procent (X%)
  - MB downloaded / Total MB (f.eks. "45 MB / 140 MB")
  - Estimeret tid tilbage
- [ ] Vis hvilket model der downloades (Tiny, Base, Small, Medium, Large)
- [ ] Tilføj "Cancel" knap under download
- [ ] Vis success besked når model er downloaded
- **Teknisk note:** WhisperKit 0.9.4 bruger simple init - undersøg om progress kan hentes via `WhisperKit.download()` metode separat.

### 3. Køsystem Redesign
**Problem:** Nuværende køsystem er for komplekst for nye brugere at forstå.

- [ ] Forenkle køvisning:
  - Vis kun "Næste opgave" tydeligt
  - Resten af køen i en minimeret liste
  - Tilføj status ikoner (⏳ venter, 🔄 transkriberer, ✅ færdig, ❌ fejlet)
- [ ] Bedre navngivning:
  - "Aktuel Opgave" → "Transkriberer nu"
  - "Kø" → "Afventer" eller "Næste opgaver"
- [ ] Vis estimeret ventetid for filer i kø
- [ ] Tilføj "Pause kø" funktion
- [ ] Tilføj "Ryd færdige" knap
- [ ] Overvej at skjule tekniske detaljer som "taskQueue size", "activeTasks", etc.

### 4. Save Dialog Flow (Manual Mode)
**Problem:** Save dialog efter transcription er forvirrende - bedre at vælge output location først.

- [ ] **Ny flow:**
  1. Bruger vælger audio fil(er)
  2. **ØjeblikkELigt** vis dialog: "Hvor skal transskriptionerne gemmes?"
  3. Lad bruger vælge output folder (gem som bookmark)
  4. Start transcription
  5. Gem automatisk til valgt folder uden yderligere dialogs
- [ ] Husk output location mellem sessions
- [ ] Tilføj "Skift output folder" knap i UI
- [ ] Vis valgt output location tydeligt i UI
- [ ] Supporter batch processing - flere filer, én output location

### 5. Intern Storage for Transskriptioner
**Problem:** Txt filer gemmes forskellige steder. Bør gemmes centralt i app's data directory.

- [ ] **Implementer intern storage:**
  - Gem alle transskriptioner i `~/Library/Containers/dk.omdethele.SkrivDetNed/Data/Documents/Transcriptions/`
  - Brug database (SQLite/CoreData) til at tracke:
    - Original audio fil path
    - Transskription tekst
    - Metadata (model brugt, sprog, dato, varighed, etc.)
    - Status (pending, processing, completed, failed)
    - Fejlbeskeder hvis failed
- [ ] **UI for at browse transskriptioner:**
  - Liste over alle transskriptioner
  - Søgning i transskriptionstekst
  - Filtrer efter dato, model, status
  - Export funktion (copy til clipboard, gem som .txt, gem som .docx)
- [ ] **Migration:**
  - Import eksisterende txt filer fra iCloud
  - Behold backward compatibility
- [ ] **iCloud Sync:**
  - Synkroniser database via iCloud (CloudKit?)
  - Synkroniser på tværs af iOS/macOS

## Medium Prioritet

### 6. Fejlhåndtering og Logging
- [ ] Bedre fejlbeskeder til brugeren (mindre tekniske)
- [ ] Log fil som bruger kan eksportere ved support henvendelser
- [ ] Retry mekanisme for fejlede transskriptioner
- [ ] Notifikationer når transcription fejler

### 7. Performance Optimering
- [ ] Test memory usage med store filer
- [ ] Optimer kø processing
- [ ] Test concurrent transcriptions (hvis hardware tillader det)

### 8. UI/UX Polish
- [ ] Konsistent spacing og alignment
- [ ] Bedre ikoner
- [ ] Dark mode support improvements
- [ ] Keyboard shortcuts (Cmd+O for åben fil, etc.)
- [ ] Accessibility forbedringer (VoiceOver support)

## Lav Prioritet

### 9. Avancerede Features
- [ ] Export til forskellige formater (SRT, VTT for undertekster)
- [ ] Speaker diarization (hvem siger hvad)
- [ ] Real-time transcription fra mikrofon
- [ ] Batch processing forbedringer
- [ ] Custom vocabulary/dictionary support

### 10. Dokumentation
- [ ] Bruger manual
- [ ] Video tutorials
- [ ] FAQ
- [ ] Release notes automation

## Tekniske Noter

### WhisperKit Version
- **Nuværende version:** 0.9.4 (låst)
- **Årsag:** Version 0.10.0+ introducerede breaking changes der forårsagede 0 tokens output
- **Upgrade plan:** Test grundigt før upgrade til 0.15.x+
- **Kritiske breaking changes i 0.10+:**
  - Timestamp rules aktiveret by default
  - Multi-channel audio merging
  - Protocol changes til DecoderInputs
  - TranscriptionResult ændret fra struct til class

### Kendte Issues
- [ ] iPhone optagelser producerede 0 tokens med WhisperKit 0.15.0 (fixed ved downgrade til 0.9.4)
- [ ] Security-scoped access fjernet midlertidigt - skal genimplementeres
- [ ] Download progress ikke synlig i UI (WhisperKit 0.9.4 limitation)

### Model Information
- **Default model:** Base (før Tiny)
- **Tilgængelige modeller:**
  - Tiny: ~60MB, hurtigst, mindst præcis
  - Base: ~140MB, god balance (anbefalet default)
  - Small: ~460MB, bedre præcision
  - Medium: ~1.5GB, meget god præcision
  - Large: ~3GB, bedste præcision, langsomst

---

## Session Notes

### 2025-11-12: WhisperKit Version Issue
- **Problem:** iPhone transskriptioner producerede tomme filer (0 tokens)
- **Root cause:** WhisperKit auto-upgraded fra 0.9.4 → 0.15.0 pga. "upToNextMajorVersion" constraint
- **Løsning:** Låst WhisperKit til exact version 0.9.4
- **Side-effects:** Fjernede security-scoped access under debugging (skal genimplementeres)
- **Filer ændret:**
  - `WhisperService.swift`: Simplificeret loadModel(), fjernet kompleks download flow
  - `TranscriptionViewModel.swift`: Fjernet security-scoped access
  - `project.pbxproj`: Låst WhisperKit version til 0.9.4

---

*Opdateret: 2025-11-12*
