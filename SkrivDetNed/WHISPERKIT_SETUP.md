# WhisperKit Setup Instructions

## Manuel tilføjelse af WhisperKit dependency:

1. Åbn `SkrivDetNed.xcodeproj` i Xcode
2. Vælg projektet i navigatoren (øverste fil)
3. Vælg "SkrivDetNed" target
4. Gå til "Package Dependencies" tab
5. Klik "+" for at tilføje package
6. Indtast URL: `https://github.com/argmaxinc/WhisperKit.git`
7. Vælg "Up to Next Major Version" med minimum 0.7.0
8. Klik "Add Package"
9. Sørg for at WhisperKit er tilføjet til SkrivDetNed target

## Alternativ: Via command line (experimentel)

```bash
cd "/Volumes/DokuSystem(1tb)/GitHub/transkriber/SkrivDetNed"

# Add package reference
xcodebuild -resolvePackageDependencies \
  -scmProvider xcode \
  -repository "https://github.com/argmaxinc/WhisperKit.git"
```

## Verifikation

Efter tilføjelse, build projektet:
```bash
xcodebuild -scheme SkrivDetNed -configuration Debug build
```

Hvis WhisperKit importeres korrekt, skulle du se:
```
✅ Build Succeeded
```

