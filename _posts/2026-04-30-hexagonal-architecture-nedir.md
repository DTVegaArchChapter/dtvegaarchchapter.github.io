---
layout: post
title: "Hexagonal Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber"
categories: [mimari, hexagonal architecture]
tags: [hexagonal architecture, ports and adapters, adapter pattern, dependency inversion, cqrs]
lang: tr
author: QuickOrBeDead
excerpt: Hexagonal Architecture (Ports & Adapters) nedir, nasıl uygulanır, avantajları/dezavantajları ve örnek proje ile pratik rehber.
date: 2026-04-30
last_modified_at: 2026-04-30 15:00:00 +0300
---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "Hexagonal Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber",
    "datePublished": "2026-04-30",
    "author": { "@type": "Person", "name": "QuickOrBeDead" }
}
</script>
<!-- markdownlint-enable MD033 -->

> 📚 **Architecture Patterns Serisi**
> Bu yazı, farklı mimari yaklaşımları karşılaştırmalı olarak ele aldığımız serinin **3. yazısıdır**.
> - Yazı 1: [Vertical Slice Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/vertical%20slice%20architecture/2026/02/03/vertical-slice-architecture-nedir.html)
> - Yazı 2: [Onion Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/onion%20architecture/2026/02/24/onion-architecture-nedir.html)
> - **Yazı 3: Hexagonal Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber** _(bu yazı)_

---

## TL;DR

- Hexagonal Architecture (Ports & Adapters) uygulama çekirdeğini (domain + use-cases) dış bağımlılıklardan soyutlar.
- Çekirdek, **port** adı verilen arayüzler ile dış dünyaya açılır; somut adaptörler (adapters) bu portları uygular.
- Inbound adaptörler (HTTP, CLI, Messaging) uygulamaya gelen istekleri çeker; outbound adaptörler (DB, HTTP client) uygulamanın dışa erişimini sağlar.
- Bağımlılık yönü çekirdeğe doğrudur: adaptörler çekirdeğe bağımlıdır, çekirdek adaptörlere değil.
- Orta ve büyük ölçekli, uzun ömürlü, test edilebilirlik ve teknoloji bağımsızlığının önemli olduğu projeler için uygundur.

---

## 1. Hexagonal Architecture Nedir?

Hexagonal Architecture, Alistair Cockburn tarafından popülerleştirilen ve uygulama çekirdeğini dış dünyadan (UI, DB, üçüncü parti servisler) izole eden bir desen/organizasyon modelidir. Bu modelde uygulama merkezinde iş kuralları ve use-case'ler (uygulama mantığı) durur. Dış dünya ile iletişim, "ports" (arayüzler) ve bu arayüzleri uygulayan "adapters" (adaptörler) aracılığıyla yapılır.

### Temel fikir

- İş mantığı (çekirdek) hiçbir altyapı kütüphanesine bağlı olmamalıdır.
- Çekirdek hangi operasyonların gerektiğini (port) bildirir; adaptörler bu operasyonları somut olarak gerçekleştirir.
- Bu sayede veri deposu, mesajlaşma altyapısı, web framework gibi teknolojiler değiştirildiğinde çekirdeğe dokunulmaz.

---

## 2. Temel Prensipler

- **Port & Adapter** ayrımı: `INotificationSender` gibi portlar çekirdekte tanımlanır; `SmtpNotificationSender` veya `QueueNotificationSender` gibi adaptörler Infrastructure/Adapters içinde yer alır.
- **Bağımlılık yönü içe doğru**: Adaptörler çekirdeğe bağımlıdır, çekirdek adaptörlere değil.
- **Teknoloji soyutlama**: DB, message broker, framework gibi bağımlılıklar adaptör seviyesinde tutulur.
- **Test edilebilirlik**: Çekirdek kolayca birim test edilir; portlar mock'lanır.

---

## 3. Ports vs Adapters — Inbound / Outbound

- **Inbound port**: Uygulamaya gelen eylemleri tanımlar (ör. `CreateOrder`, `GetOrders`). Bunlar genellikle uygulama servisleri veya use-case arayüzleri olur.
- **Inbound adapter**: HTTP controller, gRPC server, CLI, message consumer gibi dış dünyadan gelen istekleri inbound port'a çeviren katman.
- **Outbound port**: Çekirdekten dışarıya yapılacak çağrıları tanımlar (ör. `IOrderRepository`, `INotificationSender`).
- **Outbound adapter**: Outbound port'u implement eden sınıflardır (EF Core repository, SMTP client, HTTP client wrapper).

Örnek akış:

1. `OrdersController` HTTP isteğini alır (inbound adapter).
2. Controller, `ICreateOrderUseCase` portunu çağırır (inbound port).
3. Use-case, iş mantığını çalıştırır; veriyi saklamak için `IOrderRepository` (outbound port) kullanır.
4. `OrderRepository` (outbound adapter) DB ile konuşur.

---

## 4. Örnek Kod Parçacıkları (C#)

Domain / Port tanımı:

```csharp
// Core/Ports/IOrderRepository.cs
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task SaveAsync(Order order, CancellationToken ct = default);
}
```

Outbound adapter (Infrastructure):

```csharp
// Adapters/Persistence/OrderRepository.cs
public class OrderRepository : IOrderRepository
{
    private readonly AppDbContext _db;
    public OrderRepository(AppDbContext db) => _db = db;

    public async Task<Order?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => await _db.Orders.FindAsync(new object[]{id}, ct);

    public async Task SaveAsync(Order order, CancellationToken ct = default)
    {
        _db.Orders.Update(order);
        await _db.SaveChangesAsync(ct);
    }
}
```

Inbound adapter örneği (Web controller):

```csharp
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ICreateOrderUseCase _createOrder;
    public OrdersController(ICreateOrderUseCase createOrder) => _createOrder = createOrder;

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderRequest req)
    {
        var result = await _createOrder.ExecuteAsync(req.ToCommand());
        return result.IsSuccess ? Created(...): BadRequest(result.ErrorMessage);
    }
}
```

---

## 5. Örnek Klasör/Yapı Önerisi

```text
src/
├─ Core/                # Domain + UseCases (çekirdek)
│  ├─ Domain/
│  └─ UseCases/
├─ Adapters/
│  ├─ Inbound/          # Web, Messaging, CLI
│  └─ Outbound/         # Persistence, Email, HTTP clients
└─ CompositionRoot/     # DI kayıtları, program startup
```

Bu yapı çekirdeği dış etkenlerden net şekilde izole eder ve adaptörleri değiştirmeyi kolaylaştırır.

---

## 6. Avantajlar

- **Güçlü izolasyon ve test edilebilirlik** — iş mantığı framework ve infra'dan bağımsızdır.
- **Kolay teknoloji değişimi** — DB veya message broker değişse bile çekirdeğe dokunulmaz.
- **Net sorumluluk ayrımı** — inbound/outbound dönüşümleri adaptörlerde.

## 7. Dezavantajlar

- **Başlangıç maliyeti** — küçük projeler için fazla yapı/boilerplate.
- **Öğrenme eğrisi** — port/adapters kavramlarını oturtmak zaman alır.

---

## 8. Ne Zaman Kullanmalı / Kullanılmamalı?

- Kullanmalı: Orta-büyük projeler, uzun ömürlü servisler, test ve teknoloji bağımsızlığı önemli projeler.
- Kullanmamalı: Basit CRUD uygulamaları veya hızlı prototipler (MVP) — overengineering riski.

---

## 9. Anti-Pattern'ler ve Kırmızı Bayraklar

- Çekirdeğe altyapı referansları koymak (ör. DbContext doğrudan Domain sınıfı içinde).
- Controller veya adaptörlerin iş mantığını içermesi (adapterlar sadece çevirici olmalı).

---

## 10. Örnek Proje

### Örnek: Restoran Sipariş ve Mutfak Yönetim Sistemi (Hexagonal)

Bu repo, Hexagonal (Ports & Adapters) desenini gerçek bir .NET projesi üzerinde gösterir. Proje .NET 10 ile yazılmış olup amaç; uygulama çekirdeğini (domain + use-cases) altyapıdan izole etmek, adapter'ların nasıl organize edildiğini ve yeni bir özelliğin hangi adımlarla eklendiğini öğretmektir.

- Kaynak: https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Hexagonal

Kısa özet:

- Dil/Platform: .NET 10 (ASP.NET Core Web API)
- Temel teknolojiler: ASP.NET Core, Entity Framework Core (In-Memory örnek), FluentValidation, OpenAPI

🏗️ Proje yapısına hızlı bakış (özet):

```text
src/
├── RestaurantManagement.Domain/                        # Saf domain modelleri
├── RestaurantManagement.Application/                   # Application çekirdeği (Ports & UseCases)
│   ├── Ports/
│   │   ├── Input/    # Use-case (driving/input) arayüzleri
│   │   └── Output/   # Repository (driven/output) arayüzleri
│   └── UseCases/     # Input port implementasyonları
├── RestaurantManagement.Adapters.Primary.Http/         # Primary (driving) adapter: Controllers, API contracts
└── RestaurantManagement.Adapters.Secondary.Persistence/ # Secondary (driven) adapter: EF Core, Repositories
```

Öne çıkan noktalar ve önemli dosyalar:

- Domain: `Entities` — iş kuralları ve davranışlar (framework bağımsız)
- Application/Ports: `Input` (use-case arayüzleri) ve `Output` (repository arayüzleri)
- Application/UseCases: Use-case uygulamaları; sadece port arayüzlerine bağımlıdır
- Adapters.Primary.Http: API contract'lar (`Contracts/`), `Controllers/`, `Program.cs` (DI + startup)
- Adapters.Secondary.Persistence: `RestaurantDbContext`, EF Core repository implementasyonları, `UnitOfWork`

Kurulum ve çalıştırma (özet):

```bash
git clone https://github.com/DTVegaArchChapter/ArchitecturePatterns.git
cd ArchitecturePatterns/Examples/Hexagonal
dotnet restore
cd src/RestaurantManagement.Adapters.Primary.Http
dotnet run
```

Örnek API uç noktaları (özet):

- Masa Yönetimi: `GET /api/tables`, `PUT /api/tables/{tableId}/status`
- Menü Yönetimi: `GET /api/menuitems`, filtreleme desteği
- Sipariş Yönetimi: `POST /api/orders`, `PUT /api/orders/{orderId}/status`, `GET /api/orders/kitchen`

Yeni bir özellik (ör. Rezervasyon) ekleme adımları — pratik akış (özet):

1. Domain: Yeni entity (`Reservation`) oluşturun.
2. Application: `Output` port (ör. `IReservationRepository`) tanımlayın.
3. Application: DTO ve `Input` port (`IReservationUseCase`) ekleyin.
4. Application/UseCases: Use-case implementasyonunu yazın (validation explicit çağrılır).
5. Secondary Adapter: EF Core repository implementasyonu ekleyin.
6. Primary Adapter: HTTP controller ve API contract'ı ekleyin.
7. DI: `Program.cs` içinde port → implementasyon kayıtlarını yapın.

Neler öğrenebilirsiniz (pratik çıkarımlar):

- Domain katmanı dış bağımlılık içermez; iş mantığı saf tutulur.
- Use-case'ler sadece port arayüzlerine bağımlıdır; test edilebilirlik yüksek.
- Adapter'lar (Primary/Secondary) portları implemente eder ve altyapıyı izole eder.
- DI kayıtları composition root'ta yapılır; bu sayede farklı adapter'lar (in-memory, prod DB) kolayca değiştirilebilir.

Detaylı rehber, kod örnekleri ve adım adım açıklamalar için örnek repo README'sine bakın:

- https://github.com/DTVegaArchChapter/ArchitecturePatterns/blob/main/Examples/Hexagonal/README.md

Lisans: Örnek proje MIT lisansı ile paylaşılmıştır; katkılar için PR açabilirsiniz.


---

## 11. Hızlı Uygulama Rehberi

1. Çekirdeği (`Core/Domain` + `Core/UseCases`) oluşturun, dış bağımlılıktan kaçının.
2. Gerekli port arayüzlerini tanımlayın (`IRepository`, `INotificationSender`, vb.).
3. Adaptörleri (DB, Web, Messaging) `Adapters/` altında yazın ve DI ile kayıt edin.
4. Unit testleri çekirdeğe odaklayın; adaptörleri mock veya in-memory ile test edin.

## 12. Diğer Mimarilerle Karşılaştırma

Hexagonal mimariyi benzer yaklaşımlarla (Onion, Clean, Vertical Slice) kısa ve pratik
bir şekilde karşılaştıralım.

| Kriter | Hexagonal | Onion | Clean | Vertical Slice |
|---|---:|---:|---:|---:|
| Temel metafor | Ports & Adapters — çekirdek ve adaptörler | İç içe halkalar (domain merkezli) | Bağımlılık kuralı + interface adapters | Özellik (feature) bazlı dikey dilimler |
| Bağımlılık yönü | Adaptör → Çekirdek | Dış → İç (halkalar içe bağımlı) | Dış → İç (Dependency Rule) | Her feature kendi içinde tam yığın |
| Kod organizasyonu | Katman/adapter odaklı (`Ports`, `Adapters`) | Katmanlı, domain merkezli | Katmanlı, adapter + interface odaklı | Feature-first; handler, model, validator birlikte |
| Tipik kullanım | Çoklu giriş/çıkış adaptörü olan sistemler, test edilebilirlik | Zengin domain ve DDD senaryoları | Framework bağımsızlığı ve bağımlılık kuralları önemliyken | Hızlı teslimat, küçük ekipler, CRUD-ağırlıklı projeler |
| Öğrenme / boilerplate | Orta–Yüksek (port/adapters) | Yüksek | Yüksek | Düşük–Orta |
| Değiştirilebilirlik | Yüksek (adapter swap kolay) | Yüksek | Yüksek | Düşük–Orta |

Kısa karar rehberi:

- Hexagonal: Birden fazla adapter (REST, CLI, Queue, test harness) varsa ve teknoloji
    bağımsızlığı, test edilebilirlik öncelikse.
- Onion: Zengin domain mantığı ve DDD uygulamaları için uygun; domain modelin merkezde
    olması gerektiğinde tercih edilir.
- Clean: Bağımlılık kuralı ve interface adapter ayrımı çok katı uygulanacaksa; framework
    bağımsızlığı önemliyse.
- Vertical Slice: Küçük ekipler, hızlı feature teslimi veya basit CRUD odaklı uygulamalar
    için daha az boilerplate ile hızlı sonuç verir.

Bu karşılaştırma, mimari seçiminin bağlama (ekip, proje büyüklüğü, uzun ömür, test
gereksinimleri) bağlı olduğunu vurgular — yanlış seçim over-engineering veya
zorunlu bakım yükü getirebilir.

## 13. Sık Sorulan Sorular (FAQ)

Aşağıda Hexagonal Architecture ile ilgili sıkça sorulan kısa sorular ve cevapları
bulabilirsiniz.

- **S: Hexagonal Architecture nedir, kısaca?**  
    Uygulama çekirdeğini (domain + use-cases) portlar aracılığıyla dış bağımlılıklardan
    izole eden bir tasarım desenidir; adaptörler portları uygular ve bağımlılık içe
    doğrudur.

- **S: Hangi projelerde tercih etmeliyim?**  
    Orta–büyük ölçekli, çoklu adaptör (REST, CLI, Queue, test harness) veya uzun
    ömürlü servislerde; test edilebilirlik ve teknoloji bağımsızlığı ön plandaysa.

- **S: Küçük projelerde kullanmalı mıyım?**  
    Küçük, kısa ömürlü CRUD uygulamalarında over-engineering riski vardır;
    basitleştirilmiş yaklaşımlar tercih edilebilir.

- **S: Domain ve portlar hangi katmanda olmalı?**  
    Domain saf tutulmalıdır (entities, iş kuralları). Portlar (Input/Output)
    Application katmanında tanımlanır; adaptörler ise `Adapters/` altında yer alır.

- **S: Test stratejisi nasıl olmalı?**  
    Use-case'leri birim test edin (port'lar mock'lanır). Adapter'lar için entegrasyon
    testleri yazın; uçtan uca testlerle API davranışını doğrulayın.

- **S: Mevcut monolith'i Hexagonal'a nasıl dönüştürürüm?**  
    Adım adım ilerleyin: önce kritik use-case'leri izole edin, port arayüzlerini
    tanımlayın, DB/servis çağrılarını adapter'lara taşıyın ve DI ile bağlayın; her
    adımda test yapın.

- **S: Performans maliyeti var mı?**  
    Ek soyutlama katmanları küçük bir maliyet getirir; çoğu uygulamada kabul
    edilebilir. Kritik yolları profil çıkararak optimize edin.

- **S: Hexagonal ile DDD veya CQRS birlikte kullanılır mı?**  
    Evet — Hexagonal, DDD/CQRS ile iyi uyum sağlar; domain modellerini ve use-case'leri
    izole ederek kombinasyon kolaylaşır.

- **S: Hangi anti-pattern'lere dikkat etmeliyim?**  
    Domain içine altyapı (DbContext, framework sınıfları) sokmak veya controller'larda
    iş mantığını tutmak başlıca anti-pattern'lerdir.

- **S: Nereden başlamalıyım / örnek kod nerede?**  
    Örnek proje ve adım adım rehber için: https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Hexagonal

---

## Kaynaklar

- [Alistair Cockburn - Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Netflix Tech Blog - Hexagonal Architecture](https://netflixtechblog.com/ready-for-changes-with-hexagonal-architecture-b315ec967749)
- DTVegaArchChapter/ArchitecturePatterns — Hexagonal örneği: https://github.com/DTVegaArchChapter/ArchitecturePatterns/blob/main/Examples/Hexagonal/README.md

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
        {
            "@type": "Question",
            "name": "Hexagonal Architecture nedir?",
            "acceptedAnswer": { "@type": "Answer", "text": "Hexagonal Architecture (Ports & Adapters), uygulama çekirdeğini (domain + use-cases) portlar ve adaptörler aracılığıyla dış bağımlılıklardan izole eden tasarım desenidir." }
        },
        {
            "@type": "Question",
            "name": "Hangi projelerde tercih etmeliyim?",
            "acceptedAnswer": { "@type": "Answer", "text": "Orta-büyük ölçekli, çoklu adaptör gereksinimi olan ve teknoloji bağımsızlığı ile test edilebilirliğin önemli olduğu projelerde tercih edilmelidir." }
        },
        {
            "@type": "Question",
            "name": "Küçük projelerde kullanmalı mıyım?",
            "acceptedAnswer": { "@type": "Answer", "text": "Basit CRUD veya hızlı prototipler için over-engineering riski vardır; daha basit yaklaşımlar tercih edilebilir." }
        },
        {
            "@type": "Question",
            "name": "Domain ve portlar hangi katmanda olmalı?",
            "acceptedAnswer": { "@type": "Answer", "text": "Domain saf tutulmalıdır; portlar Application katmanında tanımlanır; adaptörler Adapters/ altında yer alır." }
        },
        {
            "@type": "Question",
            "name": "Test stratejisi nasıl olmalı?",
            "acceptedAnswer": { "@type": "Answer", "text": "Use-case'leri birim test edin (port'lar mock'lanır). Adapter'lar için entegrasyon testleri; uçtan uca testlerle API davranışı doğrulanmalıdır." }
        },
        {
            "@type": "Question",
            "name": "Mevcut monolith'i Hexagonal'a nasıl dönüştürürüm?",
            "acceptedAnswer": { "@type": "Answer", "text": "Adım adım ilerleyin: kritik use-case'leri izole edin, port arayüzleri tanımlayın, DB/servis çağrılarını adapter'lara taşıyın ve DI ile bağlayın; her adımda test ekleyin." }
        },
        {
            "@type": "Question",
            "name": "Performans maliyeti var mı?",
            "acceptedAnswer": { "@type": "Answer", "text": "Ek soyutlama katmanları küçük bir maliyet getirir; çoğu uygulamada kabul edilebilir. Kritik yolları profil çıkararak optimize edin." }
        },
        {
            "@type": "Question",
            "name": "Hexagonal ile DDD veya CQRS birlikte kullanılır mı?",
            "acceptedAnswer": { "@type": "Answer", "text": "Evet — Hexagonal, DDD ve CQRS ile uyumludur; domain modellerini ve use-case'leri izole ederek kombinasyon kolaylaşır." }
        },
        {
            "@type": "Question",
            "name": "Hangi anti-pattern'lere dikkat etmeliyim?",
            "acceptedAnswer": { "@type": "Answer", "text": "Domain içine altyapı (DbContext, framework sınıfları) sokmak veya controller'larda iş mantığını tutmak başlıca anti-pattern'lerdir." }
        },
        {
            "@type": "Question",
            "name": "Nereden başlamalıyım / örnek kod nerede?",
            "acceptedAnswer": { "@type": "Answer", "text": "Örnek proje ve rehber için: https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Hexagonal" }
        }
    ],
    "inLanguage": "tr-TR"
}
</script>
<!-- markdownlint-enable MD033 -->