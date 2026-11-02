---
layout: post
title: "EF Core ile Çok Dilli Veri Modeli: Per-Entity Translation Table Yaklaşımı"
categories: [veritabanı, ef core]
tags: [ef core, multi-language, localization, translation table, postgresql, dapper]
lang: tr
author: QuickOrBeDead
excerpt: Çok dilli (multi-language) veriyi veritabanında nasıl saklarız? Kolon-per-dil, JSON kolon ve translation table yaklaşımlarının karşılaştırması, EF Core ile per-entity translation table tasarımı, Dapper ile dil bazlı okuma ve fallback stratejileri (fallback dil, "Translation Not Available" mesajı, hibrit) örnek projeyle anlatılıyor.
date: 2026-10-16
last_modified_at: 2026-10-16 08:00:00 +0300
---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "EF Core ile Çok Dilli Veri Modeli: Per-Entity Translation Table Yaklaşımı",
    "datePublished": "2026-10-15",
    "author": { "@type": "Person", "name": "QuickOrBeDead" }
}
</script>
<!-- markdownlint-enable MD033 -->

## TL;DR

- Çok dilli uygulamalarda iki ayrı problem vardır: **UI metinleri** (buton, hata mesajı; i18n kütüphaneleri ve resource dosyalarıyla çözülür) ve **veritabanındaki içerik** (ürün adı, kategori açıklaması vs. gibi tablolar ve kolonları; bu yazının konusu).
- Veritabanı tarafında dört yaygın yaklaşım vardır: dil başına kolon, dil başına tablo, JSON kolon ve **translation table**. Çok sayıda dil seçeneği ve zamanla çok büyüyen içerik modeli için en dengeli seçenek genellikle translation table'dır.
- **Per-entity translation table**: her çevrilebilir entity için kendi çeviri tablosu vardır (`products` → `product_translations`, `categories` → `category_translations`). Çeviri tablosunun primary key'i `(entity_id, language_code)` bileşik anahtarıdır.
- Dile bağlı olmayan veriler (SKU, fiyat, kategori ilişkisi) ana tabloda kalır; yalnızca gerçekten çevrilmesi gereken alanlar (ad, açıklama) çeviri tablosuna taşınır.
- Örnek projede yazma tarafı **EF Core**, okuma tarafı **Dapper** ile yapılır; okuma sorguları seçilen dile göre `left join` ile çalışır.
- Eksik çeviri için tek bir doğru cevap yoktur: **boş göster**, **fallback dil kullan**, **"EN Translation Not Available" gibi bir mesaj göster** veya **hibrit** bir yaklaşım seçilebilir. Örnek proje fallback uygulamaz; bu yazıda alternatifleri ayrı bir bölümde karşılaştırıyoruz.

---

## 1. Problem: Çok Dilli Veri Nedir?

Tek dilli bir ürün kataloğunda şema basittir:

```sql
create table products (
    id          integer primary key,
    sku         varchar(40)   not null,
    price       numeric(12,2) not null,
    name        varchar(160)  not null,
    description varchar(1000) not null
);
```

Uygulama birden fazla dili desteklemeye başladığında `name` ve `description` her dil için ayrı bir değere ihtiyaç duyar; `sku` ve `price` ise dilden bağımsızdır.

### UI lokalizasyonu ile veri lokalizasyonu farklıdır

| | UI metinleri | Veritabanı içeriği |
|---|---|---|
| Örnek | "Kaydet", "Alan zorunludur" | Ürün adı, kategori açıklaması |
| Kim yönetir? | Geliştirici | Admin / içerik editörü / kullanıcı |
| Nerede saklanır? | Resource / JSON dosyaları (`react-intl`, `vue-i18n`, `.resx`) | Veritabanı |
| Değişim sıklığı | Deploy ile | Çalışma zamanında |

Çoğu uygulama ikisine de ihtiyaç duyar. Bu yazı yalnızca **veritabanı içeriğini** ele alır.

### Önce veriyi sınıflandırın

Şemayı çizmeden önce her kolonu üç gruptan birine yerleştirmek gerekir:

1. **Localizable (çevrilebilir):** Ürün adı, açıklama, kategori adı.
2. **Universal (evrensel):** SKU, fiyat, stok, kategori ilişkisi, sayısal veriler.
3. **System-internal (sistem içi):** Log kayıtları, teknik metadata. Çoğunlukla çevrilmez.

Evrensel bir alanı çeviri tablosuna koymak (örneğin `price`) aynı verinin her dil için tekrarlanmasına ve senkronizasyon hatalarına yol açar. Evrensel veri tek bir yerde, ana tabloda tutulmalıdır.

---

## 2. Şema Stratejileri

### 2.1 Dil Başına Kolon (Column Per Locale)

```sql
create table products (
    id             integer primary key,
    sku            varchar(40),
    price          numeric(12,2),
    name_tr        varchar(160),
    name_en        varchar(160),
    name_fr        varchar(160),
    description_tr varchar(1000),
    description_en varchar(1000),
    description_fr varchar(1000)
);
```

- ✅ Join yok, sorgu basit, okuma performansı yüksek.
- ❌ Her yeni dil için `ALTER TABLE` gerekir. 5 çevrilebilir alan ve 10 dil = 50 kolon.
- ❌ Çok sayıda `NULL` (seyrek veri).
- ❌ Sorgu ve kod karmaşıklığı dil sayısıyla doğru orantılı artar.
- **Uygun olduğu durum:** Sabit ve az sayıda (2-4) dil, az çevrilebilir alan.

### 2.2 Dil Başına Tablo (Separate Tables Per Language)

`Product_en`, `Product_fr`, `Product_tr` gibi her dil için ana tablonun kopyası. Evrensel veri tekrarlanır, şema değişikliği tüm tablolarda yapılmak zorundadır ve yeni dil yeni tablo demektir. Bu yaklaşım pratikte nadiren tercih edilir.

### 2.3 JSON Kolon

```sql
create table products (
    id   integer primary key,
    sku  varchar(40),
    name jsonb   -- {"tr": "Kablosuz Kulaklık", "en": "Wireless Headphones"}
);
```

- ✅ Yeni dil için şema değişikliği yok, join yok.
- ❌ Veritabanı her dilin mevcut olduğunu veya değerin tipini garanti edemez.
- ❌ Dil kodları için foreign key / referential integrity yoktur.
- ❌ Dile göre arama ve indeksleme (GIN, ifade indeksleri) daha karmaşıktır; ORM desteği değişkendir.
- **Uygun olduğu durum:** PostgreSQL/MySQL kullanan, orta ölçekli, çeviri tamamlanma oranının dillere göre çok değiştiği ve minimal şema isteyen projeler.

### 2.4 Translation Table

```sql
create table products (
    id    integer primary key,
    sku   varchar(40)   not null,
    price numeric(12,2) not null
);

create table product_translations (
    product_id    integer     not null references products(id),
    language_code varchar(2)  not null,
    name          varchar(160)  not null,
    description   varchar(1000) not null,
    primary key (product_id, language_code)
);
```

- ✅ Yeni dil = yeni satırlar; şema değişmez.
- ✅ Evrensel veri ana tabloda, çevrilebilir veri çeviri tablosunda: temiz ayrım.
- ✅ Hangi dillerin mevcut olduğu sorgulanabilir; dil kodu için foreign key tanımlanabilir.
- ❌ Okuma sorgularında en az bir `JOIN` gerekir.
- ❌ Fallback zincirleri ek join veya uygulama mantığı gerektirir.
- ❌ Her çevrilebilir entity için ayrı tablo yönetmek gerekir.

### Karşılaştırma

| Kriter | Dil Başına Kolon | Translation table | JSON kolon |
|---|---|---|---|
| Yeni dil maliyeti | Migration | Satır ekleme | Değişiklik yok |
| Sorgu karmaşıklığı | Basit | Join gerekli | Orta |
| Okuma performansı | Çok iyi | İyi (doğru indeksle) | İyi |
| Tip güvenliği / bütünlük | Tam | Tam | Kısmi |
| EF Core desteği | Yerleşik | Yerleşik | Provider'a bağlı |
| En uygun | Az ve sabit dil | Çok dil, büyüyen model | Esnek model |

---

## 3. Per-Entity Translation Table mı, Ortak Translation Table mı?

Translation table yaklaşımının iki yaygın varyasyonu vardır:

**Ortak (generic) çeviri tablosu:** Tüm entity'ler tek bir tabloyu paylaşır.

```text
translations(entity_type, entity_id, field_name, language_code, value)
```

Esnektir ancak `entity_id` için foreign key tanımlanamaz, her alan ayrı satırdır (bir ürünü okumak için birden çok satır pivotlamak gerekir), tip ve uzunluk kısıtları kaybolur.

**Per-entity çeviri tablosu:** Her entity'nin kendi çeviri tablosu vardır.

```text
products      → product_translations   (product_id, language_code, name, description)
categories    → category_translations  (category_id, language_code, name, description)
```

| | Ortak tablo | Per-entity tablo |
|---|---|---|
| Foreign key / bütünlük | Yok (entity_id polimorfik) | Var (cascade delete dahil) |
| Alan tipi ve uzunluğu | Hepsi aynı (`text`) | Alan bazında (`varchar(160)`, `varchar(1000)`) |
| Okuma | Pivot / çok satır | Tek satır, tek join |
| Yeni çevrilebilir entity | Yeni tablo gerekmez | Yeni tablo + migration |
| EF Core modeli | Zor, tip güvensiz | Doğal ilişki, tip güvenli |

Per-entity yaklaşımın bedeli tablo sayısının artmasıdır; karşılığında bütünlük, tip güvenliği ve basit sorgular kazanılır. EF Core ile çalışırken bu yaklaşım modele en doğal oturan seçimdir.

---

## 4. Örnek Proje

Bu yazıdaki kod örnekleri, per-entity translation table yaklaşımını gösteren örnek projeden alınmıştır (bkz. [Bölüm 12](#12-örnek-proje-referansı)).

**Teknoloji yığını:**

- .NET 10 Web API (Minimal API)
- EF Core 10 + PostgreSQL (Npgsql): **yazma** ve migration
- Dapper: **okuma** (tüm sorgu endpoint'leri)
- React + Vite + TypeScript arayüzü
- Desteklenen diller: `tr`, `en`, `fr`

**Veri modeli:**

```text
                        ┌─────────────────────────┐
                        │ languages               │
                        ├─────────────────────────┤
                        │ code (PK, varchar(2))   │
                        │ display_name            │
                        └────────────┬────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 │ FK (Restrict)         FK (Restrict)   │
                 ▼                                       ▼
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│ category_translations           │     │ product_translations            │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│ PK (category_id, language_code) │     │ PK (product_id, language_code)  │
│ name                            │     │ name                            │
│ description                     │     │ description                     │
└────────────────┬────────────────┘     └────────────────┬────────────────┘
                 │ FK (Cascade)                          │ FK (Cascade)
                 ▼                                       ▼
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│ categories                      │     │ products                        │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│ id                              │     │ id                              │
│ code (unique)                   │     │ sku (unique)                    │
│                                 │     │ price                           │
│                                 │     │ category_id                     │
└─────────────────────────────────┘     └────────────────┬────────────────┘
                 ▲                                       │
                 └───────────── FK (Restrict) ───────────┘
```

**Tasarım kararları:**

- Çeviri tablolarının primary key'i `(entity_id, language_code)`: bir entity için aynı dilde iki çeviri olamaz ve ayrı bir surrogate `Id` kolonuna gerek yoktur.
- `language_code` ISO 639-1 (`tr`, `en`, `fr`) formatında, `languages` tablosuna foreign key ile bağlıdır; böylece desteklenmeyen bir dil kodu veritabanına yazılamaz.
- `sku`, `price`, `category_id` ürünün evrensel alanlarıdır, `products` tablosunda kalır.
- Ana kayıt silinince çeviriler silinir (`Cascade`); dil silinirken çevirisi olan bir dil silinemez (`Restrict`).
- Kategori ve ürün adları dile göre değişir, fakat kategori `code` değeri (`categories.code`) dil bağımsız bir tanımlayıcıdır.

---

## 5. Entity'ler ve EF Core Konfigürasyonu

### Entity'ler

```csharp
public sealed class Product
{
    public int Id { get; set; }
    public required string Sku { get; set; }
    public decimal Price { get; set; }
    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;
    public List<ProductTranslation> Translations { get; set; } = [];
}

public sealed class ProductTranslation
{
    public int ProductId { get; set; }
    public required string LanguageCode { get; set; }
    public required string Name { get; set; }
    public required string Description { get; set; }
    public Product Product { get; set; } = null!;
    public Language Language { get; set; } = null!;
}

public sealed class Language
{
    public required string Code { get; set; }
    public required string DisplayName { get; set; }
}
```

`ProductTranslation` içinde ayrı bir `Id` yoktur; `ProductId` ve `LanguageCode` birlikte kimliği oluşturur. `Category` ve `CategoryTranslation` aynı kalıbı izler.

### `OnModelCreating`

```csharp
modelBuilder.Entity<Language>(entity =>
{
    entity.ToTable("languages");
    entity.HasKey(language => language.Code);
    entity.Property(language => language.Code).HasColumnName("code").HasMaxLength(2);
    entity.Property(language => language.DisplayName).HasColumnName("display_name").HasMaxLength(40).IsRequired();
    entity.HasData(
        new Language { Code = "tr", DisplayName = "Turkish" },
        new Language { Code = "en", DisplayName = "English" },
        new Language { Code = "fr", DisplayName = "French" });
});

modelBuilder.Entity<Product>(entity =>
{
    entity.ToTable("products");
    entity.HasKey(product => product.Id);
    entity.Property(product => product.Sku).HasColumnName("sku").HasMaxLength(40).IsRequired();
    entity.Property(product => product.Price).HasColumnName("price").HasPrecision(12, 2);
    entity.HasIndex(product => product.Sku).IsUnique();
    entity.HasOne(product => product.Category)
        .WithMany(category => category.Products)
        .HasForeignKey(product => product.CategoryId)
        .OnDelete(DeleteBehavior.Restrict);
    entity.HasMany(product => product.Translations)
        .WithOne(translation => translation.Product)
        .HasForeignKey(translation => translation.ProductId)
        .OnDelete(DeleteBehavior.Cascade);
});

modelBuilder.Entity<ProductTranslation>(entity =>
{
    entity.ToTable("product_translations");
    entity.HasKey(translation => new { translation.ProductId, translation.LanguageCode });
    entity.Property(translation => translation.ProductId).HasColumnName("product_id");
    entity.Property(translation => translation.LanguageCode).HasColumnName("language_code").HasMaxLength(2);
    entity.Property(translation => translation.Name).HasColumnName("name").HasMaxLength(160).IsRequired();
    entity.Property(translation => translation.Description).HasColumnName("description").HasMaxLength(1000).IsRequired();
    entity.HasOne(translation => translation.Language)
        .WithMany()
        .HasForeignKey(translation => translation.LanguageCode)
        .OnDelete(DeleteBehavior.Restrict);
});
```

Dikkat edilecek noktalar:

- `HasKey(t => new { t.ProductId, t.LanguageCode })` bileşik anahtarı tanımlar.
- `HasMany(...).WithOne(...)` ürün ile çevirileri arasındaki ilişkiyi kurar; ürün eklenirken `Translations` listesi ile birlikte tek `SaveChanges` çağrısında yazılır.
- Dil tablosuna `HasData` ile seed veri eklenir; bu veri migration'a yansır.
- Kolon isimleri `snake_case` olarak elle verilmiştir; böylece Dapper SQL'leri okunaklı kalır.

---

## 6. Migration

`dotnet ef migrations add InitialCreate` komutunun ürettiği migration, translation tablolarını bileşik primary key ve iki foreign key ile oluşturur:

```csharp
migrationBuilder.CreateTable(
    name: "product_translations",
    columns: table => new
    {
        product_id = table.Column<int>(type: "integer", nullable: false),
        language_code = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
        name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
        description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false)
    },
    constraints: table =>
    {
        table.PrimaryKey("PK_product_translations", x => new { x.product_id, x.language_code });
        table.ForeignKey(
            name: "FK_product_translations_languages_language_code",
            column: x => x.language_code,
            principalTable: "languages",
            principalColumn: "code",
            onDelete: ReferentialAction.Restrict);
        table.ForeignKey(
            name: "FK_product_translations_products_product_id",
            column: x => x.product_id,
            principalTable: "products",
            principalColumn: "id",
            onDelete: ReferentialAction.Cascade);
    });

migrationBuilder.InsertData(
    table: "languages",
    columns: new[] { "code", "display_name" },
    values: new object[,]
    {
        { "en", "English" },
        { "fr", "French" },
        { "tr", "Turkish" }
    });

migrationBuilder.CreateIndex(
    name: "IX_product_translations_language_code",
    table: "product_translations",
    column: "language_code");
```

Bileşik primary key, `product_id` ile başlayan aramalar için zaten bir indeks sağlar. EF Core ayrıca foreign key kolonu olan `language_code` için ayrı bir indeks oluşturur; "belirli bir dildeki tüm çeviriler" gibi sorgularda işe yarar.

Uygulama açılışında migration'lar otomatik uygulanır:

```csharp
await using (var scope = app.Services.CreateAsyncScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await dbContext.Database.MigrateAsync();
}
```

> Not: Otomatik `MigrateAsync` örnek proje için pratiktir; production ortamında migration'ları ayrı bir deployment adımı olarak çalıştırmak genellikle daha güvenlidir.

---

## 7. Yazma Tarafı: EF Core ile Çeviri Yönetimi

Örnek projede iki farklı yazma senaryosu vardır.

### 7.1 Ürün: Seçili Dilde Tek Çeviri

![Ürün Kayıt Ekranı](/assets/images/posts/urun-kayit-ekrani.png)

Ürün formunda kullanıcı bir dil seçer; kaydetme yalnızca o dilin çevirisini ekler veya günceller. Yeni ürün oluşturulurken ürün ve ilk çevirisi tek `SaveChanges` ile yazılır:

```csharp
var product = new Product
{
    Sku = request.Sku.Trim(),
    Price = request.Price,
    CategoryId = request.CategoryId,
    Translations =
    [
        new ProductTranslation
        {
            LanguageCode = request.LanguageCode.ToLowerInvariant(),
            Name = request.Name.Trim(),
            Description = request.Description.Trim()
        }
    ]
};
dbContext.Products.Add(product);
await dbContext.SaveChangesAsync(cancellationToken);
```

Güncellemede ise ürünün evrensel alanları güncellenir ve ilgili dil için **upsert** yapılır: çeviri varsa güncellenir, yoksa eklenir.

```csharp
product.Sku = request.Sku.Trim();
product.Price = request.Price;
product.CategoryId = request.CategoryId;

var translation = await dbContext.ProductTranslations
    .SingleOrDefaultAsync(item => item.ProductId == id
        && item.LanguageCode == request.LanguageCode.ToLowerInvariant(), cancellationToken);
if (translation is null)
{
    dbContext.ProductTranslations.Add(new ProductTranslation
    {
        ProductId = id,
        LanguageCode = request.LanguageCode.ToLowerInvariant(),
        Name = request.Name.Trim(),
        Description = request.Description.Trim()
    });
}
else
{
    translation.Name = request.Name.Trim();
    translation.Description = request.Description.Trim();
}

await dbContext.SaveChangesAsync(cancellationToken);
```

Bu akışın sonucu: bir ürün önce Türkçe olarak oluşturulabilir, İngilizce ve Fransızca çeviriler daha sonra, aynı ürün üzerinde dil değiştirilerek eklenebilir. Çeviri sürecinin farklı kişiler ve zamanlar arasında dağılması translation table yaklaşımının önemli bir avantajıdır.

### 7.2 Kategori: Tüm Çeviriler Birlikte

![Kategori Kayıt Ekranı](/assets/images/posts/kategori-kayit-ekrani.png)

Kategori formunda ise `tr`, `en` ve `fr` çevirileri birlikte girilir ve doğrulanır:

```csharp
private static void ValidateTranslations(IReadOnlyList<CategoryTranslationInput> translations)
{
    var codes = translations.Select(item => item.LanguageCode.ToLowerInvariant()).ToArray();
    if (codes.Length != SupportedLanguages.Codes.Length ||
        codes.Distinct(StringComparer.Ordinal).Count() != SupportedLanguages.Codes.Length ||
        !SupportedLanguages.Codes.All(codes.Contains))
    {
        throw new ArgumentException("Provide exactly one translation for tr, en, and fr.");
    }
}
```

Güncellemede kategori çevirileri `Include` ile yüklenir ve dil koduna göre bir sözlükle eşleştirilir:

```csharp
var category = await dbContext.Categories
    .Include(item => item.Translations)
    .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);

var existingTranslations = category.Translations
    .ToDictionary(item => item.LanguageCode, StringComparer.Ordinal);

foreach (var input in request.Translations)
{
    var languageCode = input.LanguageCode.ToLowerInvariant();
    if (!existingTranslations.TryGetValue(languageCode, out var translation))
    {
        translation = new CategoryTranslation
        {
            CategoryId = id,
            LanguageCode = languageCode,
            Name = string.Empty,
            Description = string.Empty
        };
        dbContext.CategoryTranslations.Add(translation);
    }

    translation.Name = input.Name.Trim();
    translation.Description = input.Description.Trim();
}
await dbContext.SaveChangesAsync(cancellationToken);
```

Yazma tarafında EF Core'un change tracking'i tam olarak ihtiyaç duyulan şeydir: değişen çeviriler `UPDATE`, yeni çeviriler `INSERT` olarak tek transaction içinde yazılır.

### 7.3 Doğrulama

Girdi doğrulaması iki katmanda yapılır:

```csharp
public sealed record CreateProductRequest
{
    [Required, StringLength(40, MinimumLength = 1)]
    public required string Sku { get; init; }

    [Range(typeof(decimal), "0", "9999999999")]
    public required decimal Price { get; init; }

    [Range(1, int.MaxValue)]
    public required int CategoryId { get; init; }

    [Required, StringLength(2, MinimumLength = 2)]
    public required string LanguageCode { get; init; }

    [Required, StringLength(160, MinimumLength = 1)]
    public required string Name { get; init; }

    [Required, StringLength(1000)]
    public required string Description { get; init; }
}
```

- DTO üzerinde `DataAnnotations` ile uzunluk ve zorunluluk kontrolü (`builder.Services.AddValidation()`).
- Serviste `SupportedLanguages.Contains(languageCode)` ile dil kodu kontrolü; geçersiz dil `ArgumentException` fırlatır ve `ApiExceptionHandler` bunu `400 Bad Request` olarak döndürür. Veritabanı seviyesinde ise `languages` tablosuna foreign key son savunma hattıdır.

---

## 8. Okuma Tarafı: Dapper ile Dil Bazlı Sorgular

Okuma tarafı iş kuralı çalıştırmaz, yalnızca seçilen dile göre bir görünüm üretir. Bu yüzden EF Core `Include` ile entity yüklemek yerine doğrudan SQL ile DTO üretmek hem daha basit hem daha verimlidir.

### 8.1 Liste: Seçilen Dilde `left join`

```csharp
var command = new CommandDefinition("""
    select p.id, p.sku, p.price, ct.name as "CategoryName", pt.name as "Name", pt.description as "Description",
        (pt.product_id is not null) as "HasTranslation"
    from products p
    join categories c on c.id = p.category_id
    left join category_translations ct on ct.category_id = c.id and ct.language_code = @LanguageCode
    left join product_translations pt on pt.product_id = p.id and pt.language_code = @LanguageCode
    order by p.sku
    """, new { LanguageCode = languageCode.ToLowerInvariant() }, cancellationToken: cancellationToken);
var rows = await connection.QueryAsync<ProductListItemResponse>(command);
```

Kritik detay: dil filtresi `where` değil **`on` koşulunda** verilir. `where pt.language_code = @LanguageCode` yazılsaydı `left join` fiilen `inner join`'a dönüşür ve çevirisi olmayan ürünler listeden kaybolurdu. Burada çevirisi olmayan ürün de listelenir; `Name` ve `Description` `null` gelir, `HasTranslation` ise `false` olur.

DTO nullable alanlarla bu durumu açıkça ifade eder:

```csharp
public sealed record ProductListItemResponse(
    int Id,
    string Sku,
    decimal Price,
    string? CategoryName,
    string? Name,
    string? Description,
    bool HasTranslation);
```

### 8.2 Tek Kayıt

```csharp
select p.id as "Id", p.sku as "Sku", p.price as "Price", p.category_id as "CategoryId",
       pt.name as "Name", pt.description as "Description"
from products p
left join product_translations pt on pt.product_id = p.id and pt.language_code = @LanguageCode
where p.id = @Id
```

### 8.3 Kategori Detayı: Tüm Çeviriler (Multi-Mapping)

Kategori düzenleme ekranı tüm dillerin çevirilerini birlikte ister. Bu durumda `language_code` filtresi yoktur ve Dapper'ın multi-mapping özelliğiyle kategori ve çeviri satırları birleştirilir:

```csharp
select c.id, c.code, t.language_code as "LanguageCode", t.name, t.description
from categories c
left join category_translations t on t.category_id = c.id
where c.id = @Id
```

```csharp
await connection.QueryAsync<CategoryRow, CategoryTranslationRow, int>(
    command,
    (categoryRow, translationRow) =>
    {
        category ??= categoryRow;
        if (translationRow?.LanguageCode is not null)
        {
            translations.Add(new CategoryTranslationResponse(
                translationRow.LanguageCode,
                translationRow.Name!,
                translationRow.Description!));
        }
        return categoryRow.Id;
    },
    splitOn: "LanguageCode");
```

### 8.4 Neden Okuma ve Yazma Ayrı?

- **Yazma (EF Core):** Change tracking, ilişkili kayıtları tek `SaveChanges` ile yazma, migration.
- **Okuma (Dapper):** Dil parametreli, düz SQL; `Include` ile tüm dilleri belleğe çekme maliyeti yok.

Her iki yaklaşım aynı şemayı kullanır. Dilerseniz okuma tarafını EF Core `AsNoTracking` ile de yazabilirsiniz; Bölüm 10'daki fallback örneklerinde bu yöntemi de göstereceğiz.

---

## 9. API ve Arayüz

### Endpoint'ler

Dil, sorgu parametresi olarak taşınır:

```text
GET  /api/languages
GET  /api/categories?languageCode=tr
GET  /api/categories/{id}                  # tüm çeviriler
POST /api/categories                       # tüm çevirilerle
PUT  /api/categories/{id}
GET  /api/products?languageCode=fr
GET  /api/products/{id}?languageCode=en
POST /api/products                         # seçili dilde tek çeviri
PUT  /api/products/{id}                    # evrensel alanlar + seçili dil upsert
```

```csharp
products.MapGet("/", async (string? languageCode, IProductService service, CancellationToken cancellationToken) =>
        TypedResults.Ok(await service.ListAsync(languageCode ?? "en", cancellationToken)))
    .WithName("ListProducts");
```

Dil verilmezse `en` varsayılır. Bu bir **istek dili** varsayılanıdır; eksik çeviri için fallback değildir.

### Arayüz Akışı

- Liste sayfalarında bir dil seçici bulunur; liste seçilen dile göre yeniden yüklenir.
- Ürün editöründe dil değiştirildiğinde `getProduct(id, languageCode)` çağrılır; çeviri yoksa form alanları boş gelir ve kullanıcı o dil için çeviriyi girip kaydeder.
- Kategori editöründe `tr`, `en`, `fr` çevirileri tek tabloda yan yana düzenlenir.
- Arayüz `hasTranslation` alanıyla eksik çevirileri işaretler. Örnek projede eksik değerler **fallback olmadan** boş olarak gösterilir.

```typescript
export type Product = {
  id: number
  sku: string
  price: number
  categoryId: number
  name: string | null
  description: string | null
  hasTranslation: boolean
}
```

Şimdi asıl soruya, eksik çeviri geldiğinde ne yapacağımıza geçelim.

---

## 10. Eksik Çeviri Stratejileri (Fallback)

Her çevrilebilir kaydın her dilde çevirisi bulunmaz. Yeni bir dil eklendiğinde veya yeni bir ürün tek dilde girildiğinde sorgunun sonucunda çeviri satırı olmayabilir. Bu durumda uygulamanın ne yapacağı bir **ürün kararıdır**; veritabanı tasarımı bu kararı destekleyecek bilgiyi sağlamalıdır.

> **Önemli:** Örnek proje fallback uygulamaz. README'deki ifadeyle "missing localized values are shown as missing, without fallback". Bu bölümdeki fallback örnekleri, mevcut şemanın üzerine nasıl eklenebileceğini gösteren **kavramsal örneklerdir**; örnek projede bulunmaz.

### 10.1 Yaklaşım A: Fallback Yok, Boş / "Eksik" Göster

Çeviri yoksa alan `null` döner, istemci eksikliği olduğu gibi gösterir. Örnek projenin yaptığı budur (`HasTranslation = false`).

- ✅ En basit yaklaşım; yanlış dilde içerik gösterme riski yok.
- ✅ Admin / içerik yönetim ekranları için idealdir: editör hangi çevirinin eksik olduğunu net görür.
- ❌ Son kullanıcı için kötü deneyim: boş kartlar, isimsiz ürünler.

### 10.2 Yaklaşım B: Fallback Dil

Çeviri yoksa önceden belirlenmiş bir dilin (genellikle varsayılan dil) içeriği gösterilir. Tipik zincir:

1. Tam eşleşme (`fr-CA`)
2. Dil eşleşmesi (`fr`)
3. Varsayılan dil (`en`)

Örnek projedeki `language_code` kolonu 2 karakterlidir; `fr-CA` gibi bölgesel kodlar için kolon uzunluğu ve `languages` tablosu genişletilmelidir. Bu yazıdaki örnek, `istenen dil → varsayılan dil` iki adımlı zinciri gösterir.

**Veritabanı katmanında (SQL):** İstenen ve fallback dil için iki ayrı `left join` ve `COALESCE`:

```sql
select p.id, p.sku, p.price,
       coalesce(pt.name, pf.name)               as "Name",
       coalesce(pt.description, pf.description) as "Description",
       (pt.product_id is not null)                              as "HasTranslation",
       (pt.product_id is null and pf.product_id is not null)    as "IsFallback",
       case
           when pt.product_id is not null then @LanguageCode
           when pf.product_id is not null then @FallbackLanguageCode
       end                                                      as "ResolvedLanguageCode"
from products p
left join product_translations pt on pt.product_id = p.id and pt.language_code = @LanguageCode
left join product_translations pf on pf.product_id = p.id and pf.language_code = @FallbackLanguageCode
order by p.sku
```

`COALESCE` alan bazında çalışır. Çeviri tablosunda `name` ve `description` kolonları birlikte `NOT NULL` olduğundan çeviri satırı ya tamamen vardır ya da yoktur; kolonları nullable olan bir şemada "ad Türkçe, açıklama İngilizce" gibi karışık sonuçlar çıkabileceğini unutmayın. Böyle durumlarda `case when pt.product_id is not null then ... else ...` ile satır bazında karar vermek daha güvenlidir.

**EF Core ile (okuma tarafı EF Core'a taşınırsa):**

```csharp
var items = await dbContext.Products
    .AsNoTracking()
    .Select(product => new
    {
        product.Id,
        product.Sku,
        product.Price,
        Translation = product.Translations
            .Where(t => t.LanguageCode == languageCode || t.LanguageCode == fallbackLanguageCode)
            .OrderBy(t => t.LanguageCode == languageCode ? 0 : 1)
            .FirstOrDefault()
    })
    .ToListAsync(cancellationToken);
```

İstenen dil varsa o, yoksa fallback satır seçilir. Üretilen SQL'i her zaman kontrol edin; fallback sorguları performans açısından Dapper ile yazılan düz SQL kadar öngörülebilir olmayabilir.

**Uygulama katmanında:** Kullanıcı tercihleri, `Accept-Language` başlığı ve çoklu fallback zinciri (`pt-BR → pt → en`) gibi mantıklar SQL yerine kodda yazılırsa daha esnek olur. Bu durumda sorgu, ilgili dillerin hepsini (`where language_code in (...)`) getirir ve seçim kodda yapılır.

- ✅ Kullanıcı hiçbir zaman boş içerik görmez; kısmen çevrilmiş kataloglar (e-ticaret, haber, dokümantasyon) için uygundur.
- ❌ Kullanıcı farkında olmadan yanlış dilde içerik görebilir.
- ❌ Fallback dilin çevirisi de eksikse yine boşluk oluşur; varsayılan dilin her zaman dolu olduğunu garanti etmek gerekir.
- ❌ Hukuki metinler, fiyat/garanti koşulları gibi içeriklerde yanlış dil bir risk olabilir.

### 10.3 Yaklaşım C: "Translation Not Available" Mesajı

Bazı ürünlerde başka bir dilin içeriğini göstermek yanlış veya riskli olabilir (hukuki metin, sözleşme, bölgeye özel kampanya, kalite denetiminden geçmemiş çeviri). Bu durumda içerik yerine açık bir mesaj gösterilir:

```text
EN Translation Not Available
```

Bu yaklaşımda API, çevirinin olmadığını açıkça belirtir; **mesaj metni ise veritabanında değil, UI lokalizasyon katmanında üretilir** (mesajın kendisi de çevrilmelidir):

```csharp
// API: çeviri yoksa null döner, HasTranslation = false
public sealed record ProductResponse(
    int Id, string Sku, decimal Price, int CategoryId,
    string? Name, string? Description, bool HasTranslation);
```

```tsx
function LocalizedText({ value, languageCode }: { value: string | null; languageCode: string }) {
  if (value) return <>{value}</>
  return (
    <span className="italic text-muted">
      {languageCode.toUpperCase()} Translation Not Available
    </span>
  )
}
```

Mesaj arayüzde dile göre yerelleştirilebilir (örneğin `tr` arayüzünde "EN çevirisi mevcut değil").

- ✅ Yanlış dilde içerik gösterme riski yok, eksiklik şeffaf.
- ✅ Kullanıcı başka dile geçmeyi seçebilir.
- ✅ Örnek projenin liste DTO'su (`ProductListItemResponse`) zaten `null` alanlar ve `HasTranslation` döndürür; bu yaklaşım için çoğunlukla yalnızca istemci tarafı değişir (tekil `ProductResponse`'a `HasTranslation` eklenmesi gerekir).
- ❌ Kullanıcı için en az yararlı seçenektir: içerik yoktur, yalnızca nedenini söyler.
- ❌ SEO açısından boş sayfalar üretir; bu sayfaların indekslenmemesi veya 404/ yönlendirme ile yönetilmesi gerekebilir.

### 10.4 Yaklaşım D: Hibrit (Fallback + Rozet)

Pratikte en sık tercih edilen model, fallback içeriği **gösterirken bunu açıkça belirtmektir**: "Bu içerik İngilizce olarak gösteriliyor". API, hangi dilin çözüldüğünü döndürür:

```csharp
public sealed record ProductResponse(
    int Id, string Sku, decimal Price, int CategoryId,
    string? Name, string? Description,
    string RequestedLanguageCode,
    string? ResolvedLanguageCode,
    bool IsFallback);
```

```tsx
{product.isFallback && (
  <span className="badge">
    {product.resolvedLanguageCode?.toUpperCase()} · {t('shownInFallbackLanguage')}
  </span>
)}
```

Alan veya içerik türü bazında farklı politikalar da uygulanabilir:

| İçerik | Politika |
|---|---|
| Ürün adı, açıklama | Fallback dil + rozet |
| Hukuki metin, KVKK/GDPR metni | "Translation Not Available" |
| Admin ekranları | Fallback yok, eksik çeviriyi vurgula |
| Arama sonuçları | Yalnızca çevirisi olan kayıtlar |

### 10.5 Diğer Seçenekler

- **Çevirisi olmayan kaydı gizleme:** `inner join` veya `where exists (...)` ile yalnızca seçilen dilde çevirisi olan kayıtlar listelenir. Dil bazlı katalogların (bir pazarda satılan ürünler) doğal çözümüdür.
- **Otomatik / makine çevirisi ile doldurma:** Çeviri yoksa arka planda çeviri servisi çağrılır ve sonuç `product_translations` tablosuna yazılır. Bu durumda çevirinin makine çevirisi olduğunu ve onay bekleyip beklemediğini tutan bir alan (`is_machine_translated`, `status`) eklemek iyi bir pratiktir.
- **Çeviri tamamlanma takibi:** Çeviri satırına `updated_at`, `status` (`draft`, `approved`) gibi alanlar eklemek çeviri iş akışlarıyla (çeviri sağlayıcı entegrasyonu) bütünleşmeyi kolaylaştırır.

### 10.6 Karşılaştırma

| Yaklaşım | Kullanıcı ne görür? | Avantaj | Dezavantaj | Uygun yer |
|---|---|---|---|---|
| A. Fallback yok | Boş alan | Basit, net | Kötü son kullanıcı deneyimi | Admin / editör ekranları |
| B. Fallback dil | Varsayılan dildeki içerik | Boşluk yok | Yanlış dil riski, ek join | Katalog, haber, ürün listeleri |
| C. "Translation Not Available" | Açıklayıcı mesaj | Şeffaf, güvenli | İçerik yok | Hukuki / bölgeye özel içerik |
| D. Hibrit | Fallback içerik + rozet | Şeffaf ve yararlı | Daha çok kod, API'de ek alanlar | Çoğu public uygulama |
| E. Kaydı gizle | Kayıt listelenmez | Tutarlı dil deneyimi | Kayıt "kaybolmuş" görünür | Dil bazlı kataloglar |

### 10.7 Fallback Nerede Uygulanmalı?

- **SQL (`COALESCE` + ek join):** Tek sorguda sonuç döner, uygulama katmanına daha az veri taşınır. Basit tek adımlı fallback için uygundur.
- **Uygulama katmanı:** Çok adımlı zincirler, kullanıcı tercihleri, alan bazlı politikalar için daha esnektir ve test etmesi kolaydır.
- **Cache:** Çeviriler işlem verisine göre nadiren değişir; çözümlenmiş (resolved) içerik dil bazlı anahtarla cache'lenebilir. Cache anahtarına **istenen dili** eklemeyi ve çeviri güncellenince ilgili anahtarları geçersiz kılmayı unutmayın.

---

## 11. Performans, Indeksleme ve Bakım

**Indeksleme**

- `(product_id, language_code)` bileşik primary key'i, "bu ürünün şu dildeki çevirisi" aramasını doğrudan karşılar.
- `language_code` için ayrı indeks (EF Core foreign key için otomatik oluşturur), dile göre toplu sorgulara yardımcı olur.
- Ürün adına göre arama yapılacaksa çeviri tablosunda `(language_code, name)` indeksi veya PostgreSQL için dile özel full-text (`tsvector`) indeksleri düşünülebilir. Translation table yaklaşımında her satır tek bir dili temsil ettiği için dil bazlı `tsvector` kolonu doğal olarak uygulanabilir.

**Sorgu**

- Dil filtresini `left join` içinde `on` koşuluna koyun (Bölüm 8.1).
- Listelerde tüm dilleri `Include` ile çekmeyin; yalnızca gereken dili sorgulayın.
- Fallback ek join'i gerektirir; gerçek veriyle `EXPLAIN ANALYZE` çalıştırın.

**Veri bütünlüğü**

- `language_code` için foreign key kullanın; uygulama hata yapsa bile geçersiz dil kodu yazılamasın.
- Ana tablo ve çeviri tabloları birlikte yedeklenmeli ve geri yüklenmelidir; yalnızca `products` tablosunu farklı bir zamandan geri yüklemek çeviri tutarlılığını bozar.
- Dil sütunlarında değişken uzunluklu tipler (`varchar`, `text`) kullanın; çeviri uzunlukları dillere göre değişir. Almanca metin genellikle İngilizceden uzundur.
- Tüm zincirde UTF-8 kullanın (veritabanı, tablo, bağlantı). PostgreSQL varsayılan olarak UTF-8 ile oluşturulur; MySQL'de `utf8mb4` tercih edilmelidir.

**Yeni dil eklemek**

Translation table yaklaşımında yeni dil eklemek için tablo şeması değişmez:

1. `languages` tablosuna yeni satır ekleyin (`de`, German).
2. Çevirileri `*_translations` tablolarına yeni satırlar olarak ekleyin.

Örnek projede `SupportedLanguages.Codes = ["tr", "en", "fr"]` sabittir ve `CategoryService` her kategori için tüm dillerin girilmesini zorunlu kılar. Yeni dil eklemek için bu listenin değiştirilmesi gerekir. Dil listesini `languages` tablosundan okumak, bu bağımlılığı kaldıran bir iyileştirme olur.

---

### Anti-Pattern ve Sık Yapılan Hatalar

| Hata | Neden sorun? | Çözüm |
|---|---|---|
| Evrensel alanı (fiyat, SKU) çeviri tablosuna koymak | Her dilde tekrar eder, senkronizasyon bozulur | Ana tabloda tut |
| Dil filtresini `where` içine yazmak | `left join` `inner join`'a döner, çevirisiz kayıtlar kaybolur | `on` koşuluna yaz |
| `(entity_id, language_code)` için unique kısıt / PK olmaması | Aynı dilde birden çok çeviri oluşur | Bileşik PK |
| Dil kodu için foreign key olmaması | Geçersiz dil kodları DB'ye yazılır | `languages` tablosuna FK |
| Listelerde `Include(Translations)` ile tüm dilleri çekmek | Gereksiz veri ve bellek | Yalnızca istenen dili sorgula |
| Fallback davranışını belirlememek | Boş sayfalar veya tutarsız deneyim | Bölüm 10'daki stratejilerden bilinçli seç |
| Fallback'te hangi dilin gösterildiğini söylememek | Kullanıcı yanlış dili fark etmez | `isFallback` / `resolvedLanguageCode` döndür |
| Dil listesini kodda sabit bırakmak | Yeni dil için deploy gerekir | `languages` tablosundan oku |
| Çevirinin durumunu (taslak/onaylı) takip etmemek | Yarım veya makine çevirisi canlıya çıkar | `status` / `updated_at` alanları |

---

## 12. Örnek Proje Referansı

Bu yazıdaki kod örnekleri aşağıdaki örnek projeden alınmıştır:

[https://github.com/DTVegaArchChapter/dotnet-ef-multilingual-per-entity-translation-table](https://github.com/DTVegaArchChapter/dotnet-ef-multilingual-per-entity-translation-table)

**Gereksinimler:** .NET 10 SDK, Node.js 20.19+, `localhost:5432` üzerinde çalışan PostgreSQL.

**Çalıştırmak için:**

```powershell
# Gerekirse bağlantı cümlesini override edin
$env:ConnectionStrings__DefaultConnection = "Host=localhost;Port=5432;Database=translation_tables;Username=postgres;Password=<parola>"

# Migration'ı uygulayın
dotnet ef database update --project src/api/TranslationTables.Api.csproj --startup-project src/api/TranslationTables.Api.csproj

# API'yi başlatın (SpaProxy Vite dev server'ı da başlatır)
dotnet run --project src/api/TranslationTables.Api.csproj --launch-profile http
```

OpenAPI dokümanı `http://localhost:5072/openapi/v1.json` adresindedir.

**Örnek akışlar:**

- Kategoriler `tr`, `en`, `fr` çevirileriyle birlikte oluşturulur ve düzenlenir.
- Ürünler seçili dilde oluşturulur; dil değiştirilerek diğer dillerin çevirileri eklenir.
- Listeler dile göre filtrelenir; çevirisi olmayan kayıtlar eksik olarak işaretlenir.

---

## 13. Hangi Yaklaşımı Seçmeliyim?

- **2-3 sabit dil, az alan, basit model:** Kolon per dil yeterli olabilir.
- **Çok dil, büyüyen model, bütünlük önemli:** Per-entity translation table.
- **Çevrilebilir çok sayıda farklı entity, hızlı prototip, bütünlük ikinci planda:** Ortak translation tablosu veya JSON kolon.
- **Dokümana benzeyen, dil bazında farklı yapıda içerik:** JSON/doküman veritabanı.

Eksik çeviri için de bir politika seçin: yönetim ekranlarında **fallback yok**, kullanıcıya dönük listelerde **fallback dil (+ rozet)**, hukuki içerikte **"Translation Not Available"**.

---

## FAQ

**S: Çok dilli veri için en iyi veritabanı tasarımı hangisidir?**

C: Tek bir doğru cevap yoktur. Dil sayısı, çevrilebilir alan sayısı, sorgu kalıpları ve ekip tercihleri belirleyicidir. Az sayıda sabit dil için kolon per dil, çok dil ve büyüyen modeller için translation table, esnek ve seyrek çeviriler için JSON kolon tercih edilir.

**S: Translation table yaklaşımında her sorguda join gerekmesi performans problemi yaratmaz mı?**

C: Bileşik primary key ve doğru yazılmış `left join` ile join maliyeti genellikle küçüktür; çünkü her çeviri satırı tek bir `(entity_id, language_code)` değerine denk gelir. Liste sorgularında yalnızca istenen dili join edin, gerekirse sonuçları cache'leyin.

**S: Per-entity translation table ile ortak translation tablosu arasındaki fark nedir?**

C: Per-entity yaklaşımda her entity'nin kendi çeviri tablosu vardır; foreign key, alan bazlı tip ve uzunluk kısıtları ile tek satırda okuma sağlar. Ortak tabloda tüm entity'ler tek tabloyu paylaşır; yeni entity için tablo gerekmez ancak foreign key bütünlüğü ve tip güvenliği kaybolur.

**S: Çeviri yoksa fallback dil mi kullanmalıyım, yoksa "Translation Not Available" mı göstermeliyim?**

C: İçeriğin niteliğine bağlıdır. Ürün adı veya açıklaması gibi içeriklerde fallback dil (tercihen "İngilizce olarak gösteriliyor" rozetiyle) daha yararlıdır. Hukuki metinler veya bölgeye özel içeriklerde yanlış dil riskli olduğu için "EN Translation Not Available" gibi açık bir mesaj daha güvenlidir. Admin ekranlarında ise eksik çeviriyi olduğu gibi göstermek en doğrusudur.

**S: Fallback mantığı SQL'de mi uygulama katmanında mı yazılmalı?**

C: Tek adımlı fallback için SQL (`COALESCE` + ikinci `left join`) yeterli ve verimlidir. Çok adımlı zincirler (`pt-BR → pt → en`), kullanıcı tercihleri ve alan bazlı politikalar için uygulama katmanı daha esnek ve test edilebilirdir.

**S: Yeni bir dil eklemek için şema değişikliği gerekir mi?**

C: Hayır. `languages` tablosuna bir satır eklemek ve çevirileri yeni satırlar olarak yazmak yeterlidir. Örnek projede ayrıca `SupportedLanguages` sabit listesinin güncellenmesi gerekir; bu listeyi `languages` tablosundan okumak bu bağımlılığı ortadan kaldırır.

**S: Okuma için neden EF Core yerine Dapper kullanılıyor?**

C: Okuma tarafı iş kuralı çalıştırmaz, yalnızca seçilen dile göre DTO üretir. Dapper ile dil parametreli düz SQL yazmak change tracking maliyetini ortadan kaldırır. İsterseniz aynı sorguları EF Core `AsNoTracking` ve `Select` projeksiyonlarıyla da yazabilirsiniz.

---

## Kaynaklar

- [Database Localization: Strategies for Storing Multilingual Data — better-i18n](https://better-i18n.com/it/blog/database-localization/)
- [Multilingual Database Design: Architecture and Optimization Guide — Translated](https://translated.com/resources/multilingual-database-design-architecture-optimization-guide)
- [Mastering Multi-lingual Database Design in ASP.NET Core with EF Core — ASP.NET Zero](https://aspnetzero.com/blog/mastering-multi-lingual-database-design-in-asp.net-core-with-ef-core)
- [EF Core — Relationships](https://learn.microsoft.com/en-us/ef/core/modeling/relationships)
- [EF Core — Composite Keys](https://learn.microsoft.com/en-us/ef/core/modeling/keys#composite-keys)
- [Npgsql Entity Framework Core Provider](https://www.npgsql.org/efcore/)
- [Dapper](https://github.com/DapperLib/Dapper)
- [https://github.com/DTVegaArchChapter/dotnet-ef-multilingual-per-entity-translation-table](https://github.com/DTVegaArchChapter/dotnet-ef-multilingual-per-entity-translation-table)


---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
        {
            "@type": "Question",
            "name": "Çok dilli veri için en iyi veritabanı tasarımı hangisidir?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Tek bir doğru cevap yoktur. Az sayıda sabit dil için kolon per dil, çok dil ve büyüyen modeller için translation table, esnek ve seyrek çeviriler için JSON kolon tercih edilir."
            }
        },
        {
            "@type": "Question",
            "name": "Per-entity translation table ile ortak translation tablosu arasındaki fark nedir?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Per-entity yaklaşımda her entity'nin kendi çeviri tablosu vardır; foreign key, alan bazlı tip ve uzunluk kısıtları ve tek satırda okuma sağlar. Ortak tabloda tüm entity'ler tek tabloyu paylaşır; yeni entity için tablo gerekmez ancak foreign key bütünlüğü ve tip güvenliği kaybolur."
            }
        },
        {
            "@type": "Question",
            "name": "Çeviri yoksa fallback dil mi kullanmalıyım, yoksa Translation Not Available mı göstermeliyim?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "İçeriğin niteliğine bağlıdır. Ürün adı veya açıklaması gibi içeriklerde fallback dil, tercihen rozetle, daha yararlıdır. Hukuki metin veya bölgeye özel içeriklerde yanlış dil riskli olduğu için EN Translation Not Available gibi açık bir mesaj daha güvenlidir. Admin ekranlarında eksik çeviriyi olduğu gibi göstermek en doğrusudur."
            }
        },
        {
            "@type": "Question",
            "name": "Fallback mantığı SQL'de mi uygulama katmanında mı yazılmalı?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Tek adımlı fallback için SQL (COALESCE ve ikinci left join) yeterlidir. Çok adımlı zincirler, kullanıcı tercihleri ve alan bazlı politikalar için uygulama katmanı daha esnek ve test edilebilirdir."
            }
        },
        {
            "@type": "Question",
            "name": "Yeni bir dil eklemek için şema değişikliği gerekir mi?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Hayır. languages tablosuna bir satır eklemek ve çevirileri yeni satırlar olarak yazmak yeterlidir."
            }
        }
    ]
}
</script>
<!-- markdownlint-enable MD033 -->
