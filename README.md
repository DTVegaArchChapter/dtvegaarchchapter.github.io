# dtvegaarchchapter.github.io
DT Vega Architecture Chapter tanıtım sitesi. Jekyll + GitHub Actions + GitHub Pages + jekyll-theme-slate.

## Geliştirme

Ruby ve Bundler kurulu olmalı.

```bash
bundle install
bundle exec jekyll serve
```

Lokal çalıştırma sonrası site: http://127.0.0.1:4000

## Yapı
- `_config.yml`: Site yapılandırması
- `index.md`: Ana sayfa
- `hakkimizda.md`, `projeler.md`, `katki.md`: İçerik sayfaları

## Yazı URL'leri

Yazı URL'leri kategori, tarih ve dosya adından oluşur:

```
/<kategori>/<alt-kategori>/<yil>/<ay>/<gun>/<dosya-adi>.html
```

Kategori değerleri front matter'da okunabilir haliyle kalır (ör. `vertical slice architecture`, `veritabanı`). URL'de kullanılan kategori segmentleri `_plugins/ascii_categories.rb` tarafından otomatik olarak ASCII'ye çevrilir ve boşluklar tireye dönüştürülür.

```
categories: [mimari, vertical slice architecture]
→ /mimari/vertical-slice-architecture/2026/02/03/vertical-slice-architecture-nedir.html
```

Bu davranış GitHub Pages'in varsayılan (safe mode) build'inde çalışmaz; bu yüzden site GitHub Actions ile build edilir.

## Dağıtım

Site GitHub Actions ile build edilip GitHub Pages'e deploy edilir (`.github/workflows/pages.yml`). Tema: `jekyll-theme-slate`.

İlk kurulumda GitHub'da **Settings → Pages → Build and deployment → Source** ayarını **GitHub Actions** olarak seçin. Aksi halde GitHub Pages eski branch build'ini kullanmaya devam eder.

`main` dalına yapılan her push build + deploy workflow'unu tetikler. Workflow ayrıca kanonik yazı çıktılarının yollarında ASCII dışı karakter olup olmadığını kontrol eder. (Eski URL'ler için üretilen redirect sayfaları bilinçli olarak ASCII dışı yolları korur.)

Yazı dosya adlarının ASCII olması `.github/workflows/check-slugs.yml` ile ayrıca denetlenir.
