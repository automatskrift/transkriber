# Skriv det ned - Website

Dette er hjemmesiden for "Skriv det ned" apps (macOS og iOS).

## Filer

- `index.html` - Hovedsiden med app-præsentation
- `privacy.html` - Privatlivspolitik
- `app-icon.png` - App-ikon (1024x1024px)

## Features

### index.html
- ✨ Moderne, responsive design
- 🇩🇰🇬🇧 Dansk/engelsk sprogskift
- 📱💻 Præsentation af både iOS og macOS apps
- 🎨 Flotte animationer og gradienter
- 📋 Funktionsoversigt
- 🔒 Privacy-fokus

### privacy.html
- 🔒 Detaljeret privatlivspolitik
- 🌐 Både dansk og engelsk
- 📱 Mobil-venlig
- ✅ GDPR-kompatibel

## Deployment

### GitHub Pages
1. Gå til repository settings
2. Vælg "Pages" under "Code and automation"
3. Source: Deploy from a branch
4. Branch: main
5. Folder: /docs
6. Gem

Hjemmesiden vil være tilgængelig på: `https://[username].github.io/[repository-name]/`

### Netlify
1. Træk `docs` mappen til Netlify
2. Eller tilslut GitHub repository og sæt build directory til `docs`

### Lokal test
```bash
cd docs
python3 -m http.server 8000
```
Åbn: http://localhost:8000

## Opdatering af App Store links

Når apps er live på App Store, opdater linkene i `index.html`:

```html
<!-- Find og udskift '#' med rigtige App Store URLs -->
<a href="https://apps.apple.com/app/..." class="btn btn-primary">
```

## Tilpasning

### Farver
Primær gradient defineres i CSS:
```css
:root {
    --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    --primary-color: #667eea;
    --secondary-color: #764ba2;
}
```

### Kontakt email
Opdater i begge filer:
```
privacy@skrivdetnedapp.com
```
