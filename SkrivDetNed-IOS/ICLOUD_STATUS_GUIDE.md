# iCloud Status Icons Guide

## 📱 Hvad Betyder Ikonerne i Optagelses-listen?

### Status Ikoner (Øverste højre hjørne af hver optagelse)

| Ikon | Status | Farve | Betyder |
|------|--------|-------|---------|
| 📱 `iphone` | **Local** | Grå | Optagelsen er kun gemt lokalt på din iPhone |
| ☁️↑ `icloud.and.arrow.up` + spinner | **Uploading** | Blå | Optagelsen uploades til iCloud lige nu |
| ☁️✓ `icloud.and.arrow.down.fill` | **Synced** | Grøn | Gemt i iCloud, afventer transskribering |
| ☁️✓ `icloud.and.arrow.down.fill` | **Pending** | Blå | I iCloud, venter på transskribering |
| ☁️✓ `icloud.and.arrow.down.fill` | **Transcribing** | Blå | Bliver transskriberet på din Mac |
| ☁️✓ `icloud.and.arrow.down.fill` | **Completed** | Grøn | Transskription færdig og downloadet |
| ❗☁️ `exclamationmark.icloud` | **Failed** | Rød | Upload til iCloud fejlede |

### Tekst Status (Under iCloud ikon)

- **"Lokal"** (grå) - Kun på iPhone
- **"Uploader..."** (blå, med spinner) - Uploading i gang
- **"Synkroniseret"** (grøn) - I iCloud
- **"Afventer"** (orange) - Venter på transskribering
- **"Transkriberes..."** (lilla) - Bliver transskriberet
- **"Færdig"** (grøn) - Transskription klar
- **"Fejlet"** (rød) - Noget gik galt

## 🎯 Typisk Flow

### Succesfuld Optagelse:

```
1. Lige efter optagelse:
   📱 Lokal (grå)

2. Upload starter (efter 1-2 sekunder):
   ☁️↑ Uploader... (blå + spinner)

3. Upload færdig (efter 5-30 sekunder):
   ☁️✓ Synkroniseret (grøn)

4. macOS begynder transskribering:
   ☁️✓ Transkriberes... (blå)

5. Transskription færdig (efter 1-5 minutter):
   ☁️✓ Færdig (grøn)
   + Notification: "Transskription klar"
```

### Hvis Upload Fejler:

```
1. Optagelse gemt lokalt:
   📱 Lokal (grå)

2. Upload forsøges:
   ☁️↑ Uploader... (blå + spinner)

3. Upload fejler:
   ❗☁️ Fejlet (rød)

Hvad gør du?
- Check iCloud login
- Check netværk
- Pull-to-refresh for retry
- Se console logs for fejl
```

## 💡 Hvad Skal Du Gøre Ved Hver Status?

### 📱 Lokal (Grå)
**Normal hvis:**
- Du lige har optaget
- iCloud auto-upload er slået fra
- Ingen netværk tilgængelig

**Handlinger:**
- Vent 1-2 sekunder - upload starter automatisk
- Check Settings → iCloud Sync → Auto-upload er ON
- Check netværk forbindelse

### ☁️↑ Uploader... (Blå + Spinner)
**Normal hvis:**
- Upload er i gang
- Stor fil kan tage længere tid

**Handlinger:**
- Vent tålmodigt
- Lad app være åben
- Hold stabil netværk forbindelse

### ☁️✓ Synkroniseret (Grøn)
**Normal hvis:**
- Filen er uploadet til iCloud
- macOS app'en skal nu transskribere

**Handlinger:**
- Vent på macOS transskribering
- Check macOS app kører
- Status ændrer sig automatisk til "Transkriberes..."

### ☁️✓ Transkriberes... (Blå)
**Normal hvis:**
- macOS app'en transskriberer
- Kan tage 1-5 minutter afhængig af længde

**Handlinger:**
- Vent tålmodigt
- Du får notification når færdig
- Pull-to-refresh for opdateret status

### ☁️✓ Færdig (Grøn)
**Normal hvis:**
- Alt gik perfekt!
- Transskription er klar

**Handlinger:**
- Tap på optagelsen for at se transskription
- Kopier tekst hvis ønsket
- Del transskription

### ❗☁️ Fejlet (Rød)
**Ikke normalt - noget gik galt**

**Mulige årsager:**
- Ingen netværk under upload
- iCloud ikke logget ind
- Disk fuld på iCloud
- App permissions fejl

**Handlinger:**
1. Check iCloud login (Settings → Apple ID)
2. Check netværk forbindelse
3. Check iCloud storage plads
4. Pull-to-refresh i listen for retry
5. Se console logs for præcis fejl

## 🔄 Opdatering af Status

Status opdateres automatisk når:
- Upload starter/færdiggøres
- macOS begynder transskribering
- Transskription er klar og downloadet
- Upload fejler

**Manuel opdatering:**
- Pull-to-refresh i "Optagelser" listen
- Gå ud og ind af appen

## 🎨 UI Design

Hver optagelse i listen viser:

```
┌────────────────────────────────────────────┐
│ [🟢] Optagelsens Titel              ☁️✓    │
│      ⏱️ 2:45  📄 2.1 MB              Færdig │
│      #tag1 #tag2                    5 min  │
└────────────────────────────────────────────┘
     │                                  │
     Lyd info & tags              iCloud status
```

**Venstre side:**
- Status cirkel (farvet efter CloudStatus)
- Titel
- Varighed og filstørrelse
- Tags (hvis nogen)

**Højre side:**
- iCloud ikon (viser upload status)
- Status tekst (viser transskriberings status)
- Tid siden optagelse

## 📊 Test Alle Status States

Brug Preview i Xcode for at se alle states:

```swift
// I RecordingRow.swift
#Preview {
    List {
        // Viser alle 6 forskellige states:
        - Local only
        - Uploading (med spinner)
        - Synced
        - Transcribing
        - Completed
        - Failed
    }
}
```

Åbn preview i Xcode for at se præcist hvordan hver status ser ud! 🎨
