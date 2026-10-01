---
layout: post
title: "Clean Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber"
categories: [mimari, clean architecture]
tags: [clean architecture, cqrs, mediator, repository pattern]
lang: tr
author: QuickOrBeDead
excerpt: Clean Architecture nedir, nasıl uygulanır, hangi problemleri çözer? Katman yapısı, Dependency Rule, CQRS ve Mediator ile Use Case'ler, Repository, Read Service, Result pattern, mimari testler ve gerçek dünya örneğiyle detaylı rehber.
date: 2026-10-01
last_modified_at: 2026-10-01 11:00:00 +0300
---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "Clean Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber",
    "datePublished": "2026-05-31",
    "author": { "@type": "Person", "name": "QuickOrBeDead" }
}
</script>
<!-- markdownlint-enable MD033 -->

> 📚 **Architecture Patterns Serisi**
> Bu yazı, farklı mimari yaklaşımları karşılaştırmalı olarak ele aldığımız serinin **4. yazısıdır**.
> - Yazı 1: [Vertical Slice Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/vertical%20slice%20architecture/2026/02/03/vertical-slice-architecture-nedir.html)
> - Yazı 2: [Onion Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/onion%20architecture/2026/02/24/onion-architecture-nedir.html)
> - Yazı 3: [Hexagonal Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/hexagonal%20architecture/2026/04/30/hexagonal-architecture-nedir.html)
> - **Yazı 4: Clean Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber** _(bu yazı)_

---

## TL;DR

- Clean Architecture, Robert C. Martin (Uncle Bob) tarafından 2012'de tanıtılan ve uygulamayı **dört eş merkezli halka** olarak organize eden bir mimari yaklaşımdır: **Entities → Use Cases → Interface Adapters → Frameworks & Drivers**.
- Temel kural olan **Dependency Rule**'a göre kaynak kodu bağımlılıkları her zaman içe doğru akar; dış katmanlar iç katmanlara bağımlıdır, iç katmanlar dış katmanları bilmez.
- İş mantığı framework, veritabanı, UI veya dış servislere bağımlı değildir; bu bileşenler değiştirilebilir dış detaylardır.
- Use Case'ler uygulama iş mantığını sarar; örnek projede her senaryo **Command/Query + Handler** çifti olarak ifade edilir ve **Mediator** ile çalıştırılır (CQRS). Mediator, Clean Architecture için zorunlu değil, tercih edilen bir araçtır.
- Yazma tarafı **Repository + Unit of Work** (EF Core), okuma tarafı **Read Service** (Dapper) ile ayrılır; arayüzler Application katmanında tanımlanır, implementasyonları Infrastructure katmanında kalır.
- Doğrulama `ValidationBehavior` pipeline'ı ile, hata yönetimi `Result<T>` ve domain'de `DomainResult` ile yapılır; mimari kurallar **NetArchTest** ile otomatik doğrulanır.
- Kullanılması gereken yerler: Orta-büyük ölçekli, domain karmaşıklığı yüksek, uzun ömürlü uygulamalar.
- Kullanılmaması gereken yerler: Basit CRUD uygulamaları, kısa ömürlü MVP/prototip, domain karmaşıklığı olmayan sistemler.

---

## 1. Clean Architecture Nedir?

Clean Architecture, Robert C. Martin (Uncle Bob) tarafından 2012 yılında yayınlanan [blog yazısı](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) ve ardından 2017 yılında kaleme aldığı **Clean Architecture: A Craftsman's Guide to Software Structure and Design** adlı kitapta detaylandırılan bir mimari yaklaşımdır. Temel iddiası şudur: **iş kuralları, framework'lerden, veritabanlarından, UI'dan ve dış servislerden bağımsız olmalıdır**.

Uncle Bob, Hexagonal Architecture (Alistair Cockburn, 2005), Onion Architecture (Jeffrey Palermo, 2008) ve BCE (Ivar Jacobson) gibi önceki yaklaşımları sentezleyerek Clean Architecture modelini ortaya koymuştur. Tüm bu yaklaşımların ortak paydası şudur: **bağımlılıkları merkeze doğru yönlendirmek**.

### Temel Prensipler

- **Dependency Rule (Bağımlılık Kuralı)**: Kaynak kodu bağımlılıkları yalnızca içe doğru işaret edebilir. Dıştaki bir halka, içteki bir halkayı kullanabilir; ama içteki bir halka dıştaki bir halkayı asla bilmez.
- **Framework Bağımsızlığı**: Mimari, herhangi bir kütüphane veya framework'e bağımlı değildir. Framework'ler araç olarak kullanılır, kısıtlayıcı iskelet olarak değil.
- **Test Edilebilirlik**: İş kuralları UI, veritabanı, web sunucusu veya dış bileşen olmadan test edilebilir.
- **UI Bağımsızlığı**: UI kolayca değiştirilebilir; iş kuralları değişmez.
- **Veritabanı Bağımsızlığı**: İş kuralları veritabanına bağlı değildir; SQL Server yerine MongoDB veya in-memory kullanılabilir.
- **Dış Servis Bağımsızlığı**: Dış dünya hakkında iş kurallarının hiçbir bilgisi yoktur.

### Motivasyon: Hangi Problemi Çözer?

Geleneksel katmanlı mimarilerde sıkça karşılaşılan sorunlar:

1. **Framework'e Kilitleniyor**: Uygulama framework etrafında şekillendiğinden, framework değiştiğinde her şey değişmek zorunda kalır.
2. **Ters Bağımlılık**: Domain katmanı veritabanına, ORM'e veya dış servislere doğrudan bağımlıdır.
3. **Test Zorluğu**: İş mantığı altyapı bileşenlerine sıkıştığında birim test yazmak için gerçek veritabanı veya harici servis gerekmektedir.
4. **Sorumluluk Karışıklığı**: Servis sınıfları hem iş mantığını hem de veri erişim, validasyon ve harici servis çağrılarını barındırır.
5. **Değişim Maliyeti**: Küçük bir iş kuralı değişikliği birçok katmanı etkiler ve riskli hale gelir.

Clean Architecture bu sorunları şu şekilde çözer:

- **Entities** katmanı kurumsal iş kurallarını barındırır; framework'ten, veritabanından ve UI'dan tamamen bağımsızdır.
- **Use Cases** katmanı uygulama iş kurallarını düzenler; hangi verinin ne zaman aktığını belirler.
- **Interface Adapters** katmanı verileri kullanım senaryoları ve entity'lerden uygun bir formata dönüştürür (controller, presenter, gateway).
- **Frameworks & Drivers** en dıştaki halkadır; veritabanı, web framework, harici kütüphaneler burada yer alır.

### Avantajlar

- **Yüksek Test Edilebilirlik**: Domain ve Use Case katmanları tamamen izole; herhangi bir framework veya veritabanı bağımlılığı olmadan test edilebilir.
- **Framework Bağımsızlığı**: Uygulama iş mantığı ASP.NET Core, Entity Framework Core veya herhangi bir harici kütüphaneye bağımlı değildir.
- **Uzun Ömürlü Mimari**: İş kuralları teknoloji değişimlerinden etkilenmez; yalnızca dış katman güncellenir.
- **Açık Sorumluluk Sınırları**: Her katmanın görevi nettir; Use Case nedir, Entity nedir, Controller nedir — belirsizlik yoktur.
- **Değişime Kapalı İç Katman**: Veritabanı değişse de, UI teknolojisi değişse de Entities ve Use Cases katmanları etkilenmez.
- **Kolay Ölçeklenebilirlik**: Use Case bazlı yapı sayesinde yeni özellikler eklemek mevcut kodu bozmaz.

### Dezavantajlar

- **Yüksek Başlangıç Karmaşıklığı**: Dört farklı proje (Domain, Application, Infrastructure, API) ve katmanlar arası veri dönüşümleri küçük projeler için fazla yapı oluşturabilir.
- **Boilerplate Kod**: Her yeni özellik için Command/Query, Handler, DTO, Validator, Repository/Read Service arayüzü ve implementasyonu gerekmektedir.
- **Öğrenme Eğrisi**: Dependency Rule, Interface Adapters kavramı ve katmanlar arası veri akışı yeni geliştiriciler için kafa karıştırıcı olabilir.
- **Aşırı Mühendislik Riski**: Basit bir CRUD işlemi için Entity → Command/Query Handler → Repository Interface → Repository Implementation → Endpoint yolu gerektiğinden küçük projeler için overkill olabilir.
- **DTO Çoğalması**: Katmanlar arası veri taşımak için çok sayıda DTO, record ve mapping kodu yazılması gerekir.

### Ne Zaman Kullanmalı?

| Senaryo | Uygun mu? | Neden |
|---|---|---|
| Orta-büyük ölçekli, domain karmaşık uygulama | ✅ Evet | Katmanlar arası bağımsızlık uzun vadede düşük değişim maliyeti sağlar |
| Birden fazla UI (web + mobil + CLI) olan proje | ✅ Evet | Use Cases katmanı UI teknolojisinden bağımsızdır; her UI aynı use case'i kullanır |
| ORM veya veritabanı değişimi öngörülen proje | ✅ Evet | Repository arayüzleri sayesinde Infrastructure değişimi iş mantığını etkilemez |
| Yüksek test kapsamı hedeflenen proje | ✅ Evet | Domain ve Use Cases izole; mock olmadan bile test yazılabilir |
| Çok geliştiricili, uzun ömürlü proje | ✅ Evet | Net katman sınırları paralel geliştirmeyi kolaylaştırır |
| Basit CRUD uygulaması (3-5 tablo) | ❌ Hayır | Mimari overhead fazla; Vertical Slice daha pratik olur |
| Kısa ömürlü prototip veya MVP | ❌ Hayır | Hız öncelikli; karmaşık yapı geliştirmeyi yavaşlatır |
| Domain karmaşıklığı olmayan sistem | ❌ Hayır | Tüm katman ayrımı anlamsız hale gelir |
| Tek geliştirici, küçük proje | ❌ Hayır | Yönetim maliyeti faydayı aşar |

---

## 2. Katman Yapısı

GitHub deposunda hazırladığımız **Restaurant Management API** örneği üzerinden Clean Architecture yapısını ve pratiklerini inceleyecek, kavramları örnek kodlarla açıklayacağız.

🔗 [DTVegaArchChapter/ArchitecturePatterns — Clean Architecture: Restaurant Management API](https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Clean)

Clean Architecture dört eş merkezli halkadan oluşur. Halkaların isimleri değişebilir ancak Dependency Rule değişmez: **bağımlılıklar daima içe doğru işaret eder**.

```
┌─────────────────────────────────────────────────────────┐
│           Frameworks & Drivers (Dış Çevre)              │
│  ┌─────────────────────────────────────────────────┐    │
│  │         Interface Adapters (Adaptörler)         │    │
│  │  ┌───────────────────────────────────────────┐  │    │
│  │  │       Use Cases (Uygulama İş Kuralları)   │  │    │
│  │  │  ┌─────────────────────────────────────┐  │  │    │
│  │  │  │    Entities (Kurumsal İş Kuralları) │  │  │    │
│  │  │  └─────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**Bağımlılık yönü (Dependency Flow):**

```
RestaurantManagement.Api          →  Application  →  Domain
RestaurantManagement.Api          →  Infrastructure  (yalnızca composition root: Program.cs)
RestaurantManagement.Infrastructure  →  Application  →  Domain
```

### Halka 1: Entities (Domain Katmanı)

**Kurumsal iş kurallarını** barındırır. Herhangi bir framework veya kütüphaneye bağımlılığı yoktur. Entity'ler, sadece C# sınıflarıdır; iş kurallarını private setter'lar ve domain metotlarıyla korur.

Örnek projemizde:
- `Order` — Sipariş aggregate root'u; durum geçişlerini (`StartPreparation`, `MarkAsReady`, `Serve`, `Cancel`) iş kurallarıyla zorunlu kılar.
- `MenuItem` — Menü öğesi; fiyat ve kullanılabilirlik kurallarını içerir.
- `Table` — Masa aggregate root'u; rezervasyon ve doluluk durumlarını yönetir.
- `OrderItem` — Sipariş kalemi; miktar ve fiyat kurallarını korur. Yalnızca `Order` üzerinden erişilir.

Domain katmanında iki yardımcı yapı bulunur: Aggregate root'ları işaretleyen `IAggregateRoot` (yalnızca aggregate root'lar repository üzerinden erişilir) ve iş kuralı ihlallerini exception fırlatmadan döndüren `DomainResult`.

```csharp
// src/RestaurantManagement.Domain/Common/BaseEntity.cs
namespace RestaurantManagement.Domain.Common;

public abstract class BaseEntity
{
    public int Id { get; protected set; }
}
```

```csharp
// src/RestaurantManagement.Domain/Common/IAggregateRoot.cs
namespace RestaurantManagement.Domain.Common;

public interface IAggregateRoot
{
}
```

```csharp
// src/RestaurantManagement.Domain/Common/DomainResult.cs
namespace RestaurantManagement.Domain.Common;

public readonly record struct DomainResult(bool IsSuccess, string? Error)
{
    public static DomainResult Success() => new(true, null);

    public static DomainResult Failure(string error) => new(false, error);
}
```

Beklenen iş kuralı ihlalleri (örneğin yanlış durumdaki bir siparişi iptal etmek) exception yerine `DomainResult` ile döndürülür; exception yalnızca programlama hataları (geçersiz constructor argümanı gibi) için kullanılır.

```csharp
// src/RestaurantManagement.Domain/Entities/Order.cs
using RestaurantManagement.Domain.Common;

namespace RestaurantManagement.Domain.Entities;

public class Order : BaseEntity, IAggregateRoot
{
    public string OrderNumber { get; private set; } = null!;
    public int TableId { get; private set; }
    public DateTime OrderDate { get; private set; }
    public OrderStatus Status { get; private set; }
    public decimal TotalAmount { get; private set; }
    public string? Notes { get; private set; }

    private readonly List<OrderItem> _orderItems = [];
    public IReadOnlyCollection<OrderItem> OrderItems => _orderItems.AsReadOnly();

    private Order() { } // EF Core için

    public Order(string orderNumber, int tableId, string? notes = null)
    {
        if (string.IsNullOrWhiteSpace(orderNumber))
            throw new ArgumentException("Order number cannot be null or empty", nameof(orderNumber));

        OrderNumber = orderNumber;
        TableId = tableId;
        OrderDate = DateTime.UtcNow;
        Status = OrderStatus.Pending;
        Notes = notes;
        TotalAmount = 0;
    }

    public DomainResult AddOrderItem(int menuItemId, int quantity, decimal price, string? specialInstructions = null)
    {
        if (Status != OrderStatus.Pending)
            return DomainResult.Failure($"Cannot add items to order with status: {Status}");

        if (_orderItems.Any(oi => oi.MenuItemId == menuItemId))
            return DomainResult.Failure($"Menu item {menuItemId} is already in the order");

        var orderItem = new OrderItem(menuItemId, quantity, price, specialInstructions);
        _orderItems.Add(orderItem);
        RecalculateTotal();
        return DomainResult.Success();
    }

    public DomainResult RemoveOrderItem(int menuItemId)
    {
        if (Status != OrderStatus.Pending)
            return DomainResult.Failure($"Cannot remove items from order with status: {Status}");

        var item = _orderItems.FirstOrDefault(oi => oi.MenuItemId == menuItemId);
        if (item != null)
        {
            _orderItems.Remove(item);
            RecalculateTotal();
        }
        return DomainResult.Success();
    }

    public DomainResult UpdateOrderItemQuantity(int menuItemId, int newQuantity)
    {
        if (Status != OrderStatus.Pending)
            return DomainResult.Failure($"Cannot update items in order with status: {Status}");

        var item = _orderItems.FirstOrDefault(oi => oi.MenuItemId == menuItemId);
        if (item != null)
        {
            item.UpdateQuantity(newQuantity);
            RecalculateTotal();
        }
        return DomainResult.Success();
    }

    public DomainResult StartPreparation()
    {
        if (Status != OrderStatus.Pending)
            return DomainResult.Failure($"Cannot start preparation for order with status: {Status}");

        if (!_orderItems.Any())
            return DomainResult.Failure("Cannot start preparation for order with no items");

        Status = OrderStatus.InPreparation;
        return DomainResult.Success();
    }

    public DomainResult MarkAsReady()
    {
        if (Status != OrderStatus.InPreparation)
            return DomainResult.Failure($"Cannot mark order as ready with status: {Status}");

        Status = OrderStatus.Ready;
        return DomainResult.Success();
    }

    public DomainResult Serve()
    {
        if (Status != OrderStatus.Ready)
            return DomainResult.Failure($"Cannot serve order with status: {Status}");

        Status = OrderStatus.Served;
        return DomainResult.Success();
    }

    public DomainResult Cancel()
    {
        if (Status == OrderStatus.Served)
            return DomainResult.Failure("Cannot cancel a served order");
        if (Status == OrderStatus.Cancelled)
            return DomainResult.Failure("Order is already cancelled");

        Status = OrderStatus.Cancelled;
        return DomainResult.Success();
    }

    public void UpdateNotes(string? notes)
    {
        Notes = notes;
    }

    private void RecalculateTotal()
    {
        TotalAmount = _orderItems.Sum(item => item.GetTotalPrice());
    }

    public bool CanBeModified => Status == OrderStatus.Pending;
}
```

```csharp
// src/RestaurantManagement.Domain/Entities/Table.cs
using RestaurantManagement.Domain.Common;

namespace RestaurantManagement.Domain.Entities;

public class Table : BaseEntity, IAggregateRoot
{
    public int TableNumber { get; private set; }
    public int Capacity { get; private set; }
    public TableStatus Status { get; private set; }
    public DateTime? ReservedAt { get; private set; }

    private Table() { } // EF Core için

    public Table(int tableNumber, int capacity)
    {
        if (tableNumber <= 0)
            throw new ArgumentException("Table number must be positive", nameof(tableNumber));
        if (capacity <= 0)
            throw new ArgumentException("Capacity must be positive", nameof(capacity));

        TableNumber = tableNumber;
        Capacity = capacity;
        Status = TableStatus.Available;
    }

    public bool IsAvailable => Status == TableStatus.Available;

    public DomainResult Reserve(DateTime reservationTime)
    {
        if (Status != TableStatus.Available)
            return DomainResult.Failure($"Cannot reserve table {TableNumber}. Current status: {Status}");

        Status = TableStatus.Reserved;
        ReservedAt = reservationTime;
        return DomainResult.Success();
    }

    public DomainResult Occupy()
    {
        if (Status != TableStatus.Available && Status != TableStatus.Reserved)
            return DomainResult.Failure($"Cannot occupy table {TableNumber}. Current status: {Status}");

        Status = TableStatus.Occupied;
        ReservedAt = null;
        return DomainResult.Success();
    }

    public DomainResult MakeAvailable()
    {
        if (Status == TableStatus.Available)
            return DomainResult.Failure($"Table {TableNumber} is already available");

        Status = TableStatus.Available;
        ReservedAt = null;
        return DomainResult.Success();
    }

    public DomainResult TakeOutOfService()
    {
        if (Status == TableStatus.Occupied)
            return DomainResult.Failure($"Cannot take occupied table {TableNumber} out of service");

        Status = TableStatus.OutOfService;
        ReservedAt = null;
        return DomainResult.Success();
    }
}
```

### Halka 2: Use Cases (Application Katmanı)

**Uygulama iş kurallarını** barındırır. Entity'lere bağımlıdır; veritabanı veya framework'e bağımlı değildir. Veri erişim sözleşmelerini (repository arayüzleri) burada **tanımlar**; implementasyonları dış katmana bırakır.

Her kullanım senaryosu kendi klasöründe yer alan bir **Command** (yazma) veya **Query** (okuma) ile bunu işleyen bir **Handler** sınıfıyla temsil edilir. Handler'lar [Mediator](https://github.com/martinothamar/Mediator) kütüphanesi (source generator tabanlı) üzerinden çalıştırılır; her handler tek sorumluluğa sahip bağımsız bir sınıftır. Mediator Clean Architecture'ın zorunlu bir parçası değildir; ancak cross-cutting concern'leri (örneğin validation) pipeline behavior olarak merkezi yönetmeyi kolaylaştırır.

Yazma ve okuma tarafı ayrıdır (CQRS):

- **Yazma tarafı**: Aggregate'ler `IUnitOfWork` üzerinden repository'lerle yüklenir, domain metotlarıyla değiştirilir ve kaydedilir (EF Core).
- **Okuma tarafı**: `I*ReadService` arayüzleri aggregate yüklemeden doğrudan DTO döner (Dapper).

**Repository Arayüzleri (Uygulama Sözleşmeleri):**

Repository yalnızca aggregate root'lar için vardır ve yalnızca yazma tarafının ihtiyaç duyduğu metotları içerir.

```csharp
// src/RestaurantManagement.Application/Common/Interfaces/IOrderRepository.cs
using RestaurantManagement.Domain.Entities;

namespace RestaurantManagement.Application.Common.Interfaces;

public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task AddAsync(Order order, CancellationToken cancellationToken = default);
    Task DeleteAsync(Order order, CancellationToken cancellationToken = default);
}
```

**Read Service Arayüzleri (Okuma Sözleşmeleri):**

```csharp
// src/RestaurantManagement.Application/Common/Interfaces/IOrderReadService.cs
using RestaurantManagement.Application.Common.DTOs;

namespace RestaurantManagement.Application.Common.Interfaces;

/// <summary>
/// Read-only query side. Returns DTOs directly and never loads aggregates.
/// </summary>
public interface IOrderReadService
{
    Task<OrderDto?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<OrderDto>> GetKitchenOrdersAsync(CancellationToken cancellationToken = default);
}
```

```csharp
// src/RestaurantManagement.Application/Common/Interfaces/IUnitOfWork.cs
namespace RestaurantManagement.Application.Common.Interfaces;

public interface IUnitOfWork
{
    ITableRepository Tables { get; }
    IMenuItemRepository MenuItems { get; }
    IOrderRepository Orders { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
```

### Halka 3: Interface Adapters (Adaptör Katmanı)

**Verileri dönüştürür**; Use Cases ve Entity'lerden gelen verileri web framework, veritabanı veya dış servisler için uygun formata çevirir. Controller'lar, Endpoint'ler, Presenter'lar ve Gateway'ler bu katmanda yer alır.

Örnek projede bu katman `RestaurantManagement.Api` projesindeki Minimal API endpoint'leri, API sözleşme modelleri (`Contracts`) ve `ResultHelper` aracılığıyla gerçekleştirilir.

### Halka 4: Frameworks & Drivers (Altyapı Katmanı)

En **dıştaki halkadır**; veritabanı, web framework, harici kütüphaneler burada yer alır. Repository ve Read Service implementasyonları, `DbContext`, dependency injection konfigürasyonu bu katmandadır. Bu katmanı tamamen değiştirmek iş kurallarını etkilememelidir.

---

## 3. Klasör Yapısı

```
src/
├── RestaurantManagement.Domain/                  # Entities (İç halka)
│   ├── Common/
│   │   ├── BaseEntity.cs                        # Tüm entity'lerin base sınıfı
│   │   ├── IAggregateRoot.cs                    # Aggregate root işaretleyicisi
│   │   └── DomainResult.cs                      # Domain işlem sonucu
│   └── Entities/
│       ├── Order.cs                             # Sipariş entity'si (iş kuralları)
│       ├── OrderItem.cs                         # Sipariş kalemi
│       ├── OrderStatus.cs                       # Sipariş durumu enum
│       ├── MenuItem.cs                          # Menü öğesi
│       ├── Table.cs                             # Masa entity'si
│       └── TableStatus.cs                       # Masa durumu enum
│
├── RestaurantManagement.Application/             # Use Cases (2. halka)
│   ├── Common/
│   │   ├── Result.cs                            # Explicit hata yönetimi
│   │   ├── Behaviors/
│   │   │   └── ValidationBehavior.cs            # Otomatik validation pipeline'ı
│   │   ├── DTOs/
│   │   │   ├── OrderDto.cs
│   │   │   ├── OrderItemDto.cs
│   │   │   ├── MenuItemDto.cs
│   │   │   └── TableDto.cs
│   │   └── Interfaces/
│   │       ├── IOrderRepository.cs              # Yazma tarafı: arayüz burada tanımlanır
│   │       ├── IMenuItemRepository.cs
│   │       ├── ITableRepository.cs
│   │       ├── IUnitOfWork.cs
│   │       ├── IOrderReadService.cs             # Okuma tarafı: DTO dönen sorgu sözleşmeleri
│   │       ├── IMenuItemReadService.cs
│   │       └── ITableReadService.cs
│   ├── Orders/
│   │   ├── CreateOrder/
│   │   │   ├── CreateOrderCommand.cs            # Input modeli (ICommand)
│   │   │   ├── CreateOrderCommandHandler.cs     # Sipariş oluşturma kullanım senaryosu
│   │   │   └── CreateOrderCommandValidator.cs   # FluentValidation doğrulayıcı
│   │   ├── UpdateOrderStatus/
│   │   │   ├── UpdateOrderStatusCommand.cs
│   │   │   ├── UpdateOrderStatusCommandHandler.cs
│   │   │   └── UpdateOrderStatusCommandValidator.cs
│   │   └── GetKitchenOrders/
│   │       ├── GetKitchenOrdersQuery.cs         # IQuery
│   │       └── GetKitchenOrdersQueryHandler.cs
│   ├── MenuItems/
│   │   └── GetMenuItems/
│   │       ├── GetMenuItemsQuery.cs
│   │       └── GetMenuItemsQueryHandler.cs
│   ├── Tables/
│   │   ├── GetAllTables/
│   │   │   ├── GetAllTablesQuery.cs
│   │   │   └── GetAllTablesQueryHandler.cs
│   │   └── UpdateTableStatus/
│   │       ├── UpdateTableStatusCommand.cs
│   │       ├── UpdateTableStatusCommandHandler.cs
│   │       └── UpdateTableStatusCommandValidator.cs
│   └── DependencyInjection.cs                   # AddApplication()
│
├── RestaurantManagement.Infrastructure/          # Frameworks & Drivers (Dış halka)
│   ├── Data/
│   │   ├── RestaurantDbContext.cs               # EF Core DbContext
│   │   └── DbConnectionFactory.cs               # Dapper için bağlantı fabrikası
│   ├── Repositories/                            # Yazma tarafı (EF Core)
│   │   ├── OrderRepository.cs                   # IOrderRepository implementasyonu
│   │   ├── MenuItemRepository.cs
│   │   ├── TableRepository.cs
│   │   └── UnitOfWork.cs                        # IUnitOfWork implementasyonu
│   ├── ReadServices/                            # Okuma tarafı (Dapper)
│   │   ├── DapperOrderReadService.cs            # IOrderReadService implementasyonu
│   │   ├── DapperMenuItemReadService.cs
│   │   └── DapperTableReadService.cs
│   └── DependencyInjection.cs                   # AddInfrastructure()
│
└── RestaurantManagement.Api/                     # Interface Adapters (3. halka)
    ├── Program.cs                               # Composition root
    ├── Endpoints/
    │   ├── OrderEndpoints.cs                    # Minimal API endpoint'leri
    │   ├── MenuItemEndpoints.cs
    │   └── TableEndpoints.cs
    ├── Common/
    │   └── ResultHelper.cs                      # Result → IResult dönüşümü
    └── Contracts/
        ├── Orders/
        │   ├── CreateOrderRequest.cs            # API sözleşmesi (DTO)
        │   └── UpdateOrderStatusRequest.cs
        └── Tables/
            └── UpdateTableStatusRequest.cs

test/
├── RestaurantManagement.Api.Tests/               # Domain, Application ve Api birim testleri
├── RestaurantManagement.Api.IntegrationTests/    # Repository, read service ve UnitOfWork testleri (SQLite)
├── RestaurantManagement.Api.FunctionalTests/     # WebApplicationFactory ile uçtan uca testler
└── RestaurantManagement.Api.ArchTests/           # Mimari kuralların doğrulanması (NetArchTest)
```

---

## 4. Use Case Pattern: CQRS ve Mediator

Clean Architecture'ın en belirgin özelliklerinden biri **Use Case'lerdir**. Örnek projede her Use Case, kendi klasöründe izole üç parçadan oluşur:

- **Command / Query**: Use Case'in girdisini tanımlayan `record` (`ICommand<TResponse>` veya `IQuery<TResponse>`).
- **Handler**: İş akışını yöneten sınıf (`ICommandHandler` veya `IQueryHandler`).
- **Validator**: (Yalnızca command'lar için) FluentValidation kuralları.

Command/Query'ler `ISender.Send(...)` ile gönderilir; Mediator ilgili handler'ı bulup çalıştırır. Böylece Api katmanı handler sınıflarını doğrudan tanımaz, yalnızca command/query'yi bilir.

**Command Handler'ın sorumluluğu (yazma):**
1. Gerekli aggregate'leri yüklemek (`IUnitOfWork` üzerinden repository'ler)
2. İş kurallarını çalıştırmak (entity metotları → `DomainResult`)
3. Sonucu persist etmek (`SaveChangesAsync`)
4. DTO içeren `Result<T>` dönmek

**Query Handler'ın sorumluluğu (okuma):** Read Service'i çağırıp DTO'yu `Result<T>` içinde dönmek. Aggregate yüklenmez.

Input validasyonu handler'ın içinde değil, `ValidationBehavior` pipeline'ında yapılır (bkz. [Validation](#6-validation)).

### CreateOrderCommand ve Handler

```csharp
// src/RestaurantManagement.Application/Orders/CreateOrder/CreateOrderCommand.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;

namespace RestaurantManagement.Application.Orders.CreateOrder;

public sealed record OrderItemInput(int MenuItemId, int Quantity, string? SpecialInstructions);

public sealed record CreateOrderCommand(int TableId, List<OrderItemInput> Items, string? Notes)
    : ICommand<Result<OrderDto>>;
```

```csharp
// src/RestaurantManagement.Application/Orders/CreateOrder/CreateOrderCommandHandler.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Domain.Entities;

namespace RestaurantManagement.Application.Orders.CreateOrder;

public sealed class CreateOrderCommandHandler(IUnitOfWork unitOfWork)
    : ICommandHandler<CreateOrderCommand, Result<OrderDto>>
{
    public async ValueTask<Result<OrderDto>> Handle(CreateOrderCommand command, CancellationToken cancellationToken)
    {
        // 1. Masa kontrolü
        var table = await unitOfWork.Tables.GetByIdAsync(command.TableId, cancellationToken);
        if (table is null)
            return Result<OrderDto>.NotFound($"Table {command.TableId} not found");

        if (!table.IsAvailable)
            return Result<OrderDto>.Failure($"Table {table.TableNumber} is not available for orders");

        // 2. Menü öğesi kontrolü
        var menuItemIds = command.Items.Select(i => i.MenuItemId).ToList();
        var menuItems = await unitOfWork.MenuItems.GetByIdsAsync(menuItemIds, cancellationToken);
        var availableMenuItems = menuItems.Where(m => m.IsAvailable).ToList();

        var availableMenuItemIds = availableMenuItems.Select(m => m.Id).ToList();
        var unavailableMenuItemIds = menuItemIds.Where(id => !availableMenuItemIds.Contains(id)).ToList();

        if (unavailableMenuItemIds.Count != 0)
            return Result<OrderDto>.Failure(
                $"The following menu items are not available: {string.Join(", ", unavailableMenuItemIds)}",
                errorDetails: new Dictionary<string, object> { ["UnavailableMenuItemIds"] = unavailableMenuItemIds });

        // 3. Domain aggregate oluşturma
        var orderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..8].ToUpperInvariant()}";
        var order = new Order(orderNumber, command.TableId, command.Notes);

        foreach (var itemRequest in command.Items)
        {
            var menuItem = availableMenuItems.First(m => m.Id == itemRequest.MenuItemId);
            var added = order.AddOrderItem(itemRequest.MenuItemId, itemRequest.Quantity, menuItem.Price, itemRequest.SpecialInstructions);
            if (!added.IsSuccess)
                return Result<OrderDto>.Conflict(added.Error!);
        }

        // 4. Masayı dolu olarak işaretle (aynı transaction içinde)
        var occupied = table.Occupy();
        if (!occupied.IsSuccess)
            return Result<OrderDto>.Conflict(occupied.Error!);

        // 5. Persist
        await unitOfWork.Orders.AddAsync(order, cancellationToken);
        try
        {
            await unitOfWork.SaveChangesAsync(cancellationToken);
        }
        catch (InvalidOperationException ex)
        {
            // Eşzamanlılık çakışması (örn. aynı masaya aynı anda iki sipariş)
            return Result<OrderDto>.Conflict(ex.Message);
        }

        // 6. DTO dönüşümü
        var orderItemDtos = order.OrderItems.Select(oi =>
        {
            var menuItem = availableMenuItems.First(m => m.Id == oi.MenuItemId);
            return new OrderItemDto(oi.Id, menuItem.Name, oi.Quantity, oi.Price, oi.SpecialInstructions);
        }).ToList();

        var orderDto = new OrderDto(
            order.Id, order.OrderNumber, order.TableId,
            order.OrderDate, order.Status.ToString(),
            order.TotalAmount, order.Notes, orderItemDtos);

        return Result<OrderDto>.Success(orderDto);
    }
}
```

Dikkat edilmesi gerekenler:

- Handler `DbContext`'i değil, yalnızca Application katmanında tanımlı `IUnitOfWork` arayüzünü kullanır.
- Validasyon kodu yoktur; handler'a ulaşan command zaten geçerlidir.
- Masanın `Occupy()` edilmesi ve siparişin eklenmesi tek `SaveChangesAsync` çağrısıyla atomik kaydedilir. `Table.Status` EF Core'da concurrency token olduğundan eşzamanlı çakışmalar `UnitOfWork` tarafından `InvalidOperationException`'a çevrilir ve `409 Conflict` olarak döner.

### UpdateOrderStatusCommand ve Handler

Durum güncelleme `Order` aggregate'ini yükler, domain metodunu çağırır ve **sonucu Read Service ile okur**; yani aynı use case içinde yazma tarafı EF Core, okuma tarafı Dapper kullanır.

```csharp
// src/RestaurantManagement.Application/Orders/UpdateOrderStatus/UpdateOrderStatusCommand.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;

namespace RestaurantManagement.Application.Orders.UpdateOrderStatus;

public sealed record UpdateOrderStatusCommand(int OrderId, string NewStatus) : ICommand<Result<OrderDto>>;
```

```csharp
// src/RestaurantManagement.Application/Orders/UpdateOrderStatus/UpdateOrderStatusCommandHandler.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Domain.Common;
using RestaurantManagement.Domain.Entities;

namespace RestaurantManagement.Application.Orders.UpdateOrderStatus;

public sealed class UpdateOrderStatusCommandHandler(
    IUnitOfWork unitOfWork,
    IOrderReadService orderReadService)
    : ICommandHandler<UpdateOrderStatusCommand, Result<OrderDto>>
{
    public async ValueTask<Result<OrderDto>> Handle(UpdateOrderStatusCommand command, CancellationToken cancellationToken)
    {
        // 1. Aggregate yükleme
        var order = await unitOfWork.Orders.GetByIdAsync(command.OrderId, cancellationToken);
        if (order is null)
            return Result<OrderDto>.NotFound($"Order {command.OrderId} not found");

        // 2. Domain iş kuralı — durum geçişi (validator geçerli bir enum değeri olduğunu garanti eder)
        var newStatus = Enum.Parse<OrderStatus>(command.NewStatus, true);
        DomainResult transition;
        switch (newStatus)
        {
            case OrderStatus.InPreparation:
                transition = order.StartPreparation();
                break;
            case OrderStatus.Ready:
                transition = order.MarkAsReady();
                break;
            case OrderStatus.Served:
                transition = order.Serve();
                break;
            case OrderStatus.Cancelled:
                transition = order.Cancel();
                break;
            default:
                return Result<OrderDto>.Failure($"Cannot transition order to status: {newStatus}");
        }

        if (!transition.IsSuccess)
            return Result<OrderDto>.Conflict(transition.Error!);

        // 3. Persist (EF Core change tracking; Update çağrısına gerek yok)
        await unitOfWork.SaveChangesAsync(cancellationToken);

        // 4. Okuma tarafı: DTO doğrudan Read Service'ten gelir
        var orderDto = await orderReadService.GetByIdAsync(order.Id, cancellationToken);

        return orderDto is null
            ? Result<OrderDto>.NotFound($"Order {command.OrderId} not found")
            : Result<OrderDto>.Success(orderDto);
    }
}
```

### Query Handler: GetKitchenOrders

Query handler'lar iş kuralı içermez; yalnızca Read Service'i çağırır. Aggregate yüklenmez, `IUnitOfWork` kullanılmaz.

```csharp
// src/RestaurantManagement.Application/Orders/GetKitchenOrders/GetKitchenOrdersQuery.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;

namespace RestaurantManagement.Application.Orders.GetKitchenOrders;

public sealed record GetKitchenOrdersQuery : IQuery<Result<List<OrderDto>>>;
```

```csharp
// src/RestaurantManagement.Application/Orders/GetKitchenOrders/GetKitchenOrdersQueryHandler.cs
using Mediator;
using RestaurantManagement.Application.Common;
using RestaurantManagement.Application.Common.DTOs;
using RestaurantManagement.Application.Common.Interfaces;

namespace RestaurantManagement.Application.Orders.GetKitchenOrders;

public sealed class GetKitchenOrdersQueryHandler(IOrderReadService orderReadService)
    : IQueryHandler<GetKitchenOrdersQuery, Result<List<OrderDto>>>
{
    public async ValueTask<Result<List<OrderDto>>> Handle(GetKitchenOrdersQuery query, CancellationToken cancellationToken)
    {
        var orders = await orderReadService.GetKitchenOrdersAsync(cancellationToken);

        return Result<List<OrderDto>>.Success([.. orders]);
    }
}
```

### DTO Modelleri

Command/Query'ler input, DTO'lar output modelidir. Domain entity'leri Application katmanının dışına çıkmaz.

```csharp
// src/RestaurantManagement.Application/Common/DTOs/OrderDto.cs
namespace RestaurantManagement.Application.Common.DTOs;

public record OrderDto(
    int Id,
    string OrderNumber,
    int TableId,
    DateTime OrderDate,
    string Status,
    decimal TotalAmount,
    string? Notes,
    List<OrderItemDto> OrderItems);
```

---

## 5. Result Pattern

Result pattern iki seviyede kullanılır:

- **Domain**: Entity metotları `DomainResult` döner (bkz. Katman Yapısı bölümü).
- **Application**: Handler'lardan dönen sonuçlar `Result<T>` ile sarılır. Handler, `DomainResult` hatasını `Result<T>.Conflict(...)` gibi uygun sonuca çevirir.

Bu pattern, exception fırlatmadan hata durumlarını açıkça ifade eder ve Interface Adapters katmanında tek bir yerden HTTP yanıtına dönüştürülür.

```csharp
// src/RestaurantManagement.Application/Common/Result.cs
using FluentValidation.Results;

namespace RestaurantManagement.Application.Common;

public enum ResultType
{
    Success,
    NotFound,
    Conflict,
    Failure
}

public interface IOperationResult
{
    bool IsSuccess { get; }
    string? ErrorMessage { get; }
    ResultType ResultType { get; }
    IReadOnlyDictionary<string, object> ErrorDetails { get; }
}

// ValidationBehavior, herhangi bir Result<T> tipini generic olarak oluşturabilsin diye
public interface IResultFactory<TSelf> where TSelf : IResultFactory<TSelf>
{
    static abstract TSelf From(ValidationResult validationResult);
}

public sealed class Result<T> : IOperationResult, IResultFactory<Result<T>>
{
    private static readonly IReadOnlyDictionary<string, object> Empty = new Dictionary<string, object>();

    private IReadOnlyDictionary<string, object>? _errorDetails;
    public bool IsSuccess { get; private init; }
    public T? Data { get; private set; }
    public string? ErrorMessage { get; private init; }
    public ResultType ResultType { get; private init; }

    public IReadOnlyDictionary<string, object> ErrorDetails => _errorDetails ?? Empty;

    private Result() { }

    public static Result<T> Success(T data) =>
        new() { IsSuccess = true, Data = data, ResultType = ResultType.Success };

    public static Result<T> Failure(string errorMessage,
        ResultType resultType = ResultType.Failure,
        IReadOnlyDictionary<string, object>? errorDetails = null) =>
        new() { IsSuccess = false, ErrorMessage = errorMessage, ResultType = resultType, _errorDetails = errorDetails };

    public static Result<T> NotFound(string errorMessage, IReadOnlyDictionary<string, object>? errorDetails = null) =>
        Failure(errorMessage, ResultType.NotFound, errorDetails);

    public static Result<T> Conflict(string errorMessage, IReadOnlyDictionary<string, object>? errorDetails = null) =>
        Failure(errorMessage, ResultType.Conflict, errorDetails);

    public static Result<T> From(ValidationResult validationResult)
    {
        ArgumentNullException.ThrowIfNull(validationResult);

        var errors = validationResult.Errors;
        var message = $"Validation failed: {string.Join("; ", errors.Select(e => e.ErrorMessage))}";
        var details = errors
            .GroupBy(e => e.PropertyName)
            .ToDictionary(g => g.Key, g => (object)g.Select(e => e.ErrorMessage).ToArray());

        return Failure(message, ResultType.Failure, details);
    }
}
```

Interface Adapters katmanındaki `ResultHelper`, `Result<T>`'yi HTTP yanıtına dönüştürür:

```csharp
// src/RestaurantManagement.Api/Common/ResultHelper.cs
using RestaurantManagement.Application.Common;

namespace RestaurantManagement.Api.Common;

public static class ResultHelper
{
    public static IResult ToApiResult<T>(
        this Result<T> result,
        Func<T?, IResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Data) ?? Results.Ok(result.Data);

        var errorDetails = new
        {
            error = result.ErrorMessage,
            errorDetails = result.ErrorDetails
        };

        return result.ResultType switch
        {
            ResultType.NotFound => Results.NotFound(errorDetails),
            ResultType.Conflict => Results.Conflict(errorDetails),
            ResultType.Failure => Results.BadRequest(errorDetails),
            _ => Results.BadRequest(errorDetails)
        };
    }
}
```

---

## 6. Validation

Input validasyonu **Application katmanında**, FluentValidation ile yapılır. Validator'lar handler'lardan ayrıdır; `ValidationBehavior` isimli Mediator pipeline behavior'ı handler çalışmadan önce ilgili command için kayıtlı tüm validator'ları çalıştırır. Hata varsa handler hiç çalışmaz ve `Result<T>` (validation hatası) döner.

```csharp
// src/RestaurantManagement.Application/Orders/CreateOrder/CreateOrderCommandValidator.cs
using FluentValidation;

namespace RestaurantManagement.Application.Orders.CreateOrder;

public sealed class OrderItemInputValidator : AbstractValidator<OrderItemInput>
{
    public OrderItemInputValidator()
    {
        RuleFor(x => x.MenuItemId)
            .GreaterThan(0).WithMessage("MenuItemId must be greater than 0");

        RuleFor(x => x.Quantity)
            .GreaterThan(0).WithMessage("Quantity must be greater than 0");

        RuleFor(x => x.SpecialInstructions)
            .MaximumLength(250).WithMessage("Special instructions cannot exceed 250 characters");
    }
}

public sealed class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.TableId)
            .GreaterThan(0).WithMessage("TableId must be greater than 0");

        RuleFor(x => x.Items)
            .NotEmpty().WithMessage("Order must contain at least one item");

        RuleFor(x => x.Items)
            .Must(items => items is null || items.Select(i => i.MenuItemId).Distinct().Count() == items.Count)
            .WithMessage("Order cannot contain duplicate menu items");

        RuleForEach(x => x.Items)
            .SetValidator(new OrderItemInputValidator());

        RuleFor(x => x.Notes)
            .MaximumLength(500).WithMessage("Notes cannot exceed 500 characters");
    }
}
```

```csharp
// src/RestaurantManagement.Application/Orders/UpdateOrderStatus/UpdateOrderStatusCommandValidator.cs
using FluentValidation;
using RestaurantManagement.Domain.Entities;

namespace RestaurantManagement.Application.Orders.UpdateOrderStatus;

public sealed class UpdateOrderStatusCommandValidator : AbstractValidator<UpdateOrderStatusCommand>
{
    public UpdateOrderStatusCommandValidator()
    {
        RuleFor(x => x.OrderId)
            .GreaterThan(0).WithMessage("OrderId must be greater than 0");

        RuleFor(x => x.NewStatus)
            .Must(s => Enum.TryParse<OrderStatus>(s, true, out var status) && Enum.IsDefined(status))
            .WithMessage("Invalid order status value");
    }
}
```

Pipeline behavior, generic ve tüm command'lar için tek bir yerde tanımlanır:

```csharp
// src/RestaurantManagement.Application/Common/Behaviors/ValidationBehavior.cs
using FluentValidation;
using Mediator;

namespace RestaurantManagement.Application.Common.Behaviors;

public sealed class ValidationBehavior<TMessage, TResponse>(IEnumerable<IValidator<TMessage>> validators)
    : IPipelineBehavior<TMessage, TResponse>
    where TMessage : IMessage
    where TResponse : IResultFactory<TResponse>
{
    public async ValueTask<TResponse> Handle(
        TMessage message,
        MessageHandlerDelegate<TMessage, TResponse> next,
        CancellationToken cancellationToken)
    {
        var failures = new List<FluentValidation.Results.ValidationFailure>();
        foreach (var validator in validators)
        {
            var validationResult = await validator.ValidateAsync(message, cancellationToken);
            failures.AddRange(validationResult.Errors);
        }

        if (failures.Count == 0)
            return await next(message, cancellationToken);

        return TResponse.From(new FluentValidation.Results.ValidationResult(failures));
    }
}
```

Bu yaklaşım sayesinde handler'lar yalnızca iş akışına odaklanır; yeni bir command için yalnızca bir validator sınıfı eklemek yeterlidir.

---

## 7. Interface Adapters Katmanı: Minimal API Endpoint'leri

Endpoint'ler yalnızca HTTP çevirisini yapar: API sözleşme modelini (`Contracts/`) Command/Query'ye çevirir, `ISender` ile gönderir ve `Result<T>`'yi HTTP yanıtına dönüştürür. Handler sınıflarını tanımazlar. API sözleşme modelleri Application katmanı modellerinden ayrı tutulur; böylece API sözleşmesi değiştiğinde Application katmanı etkilenmez.

```csharp
// src/RestaurantManagement.Api/Contracts/Orders/CreateOrderRequest.cs
namespace RestaurantManagement.Api.Contracts.Orders;

public record OrderItemRequest(int MenuItemId, int Quantity, string? SpecialInstructions);

public record CreateOrderRequest(int TableId, List<OrderItemRequest> Items, string? Notes);
```

```csharp
// src/RestaurantManagement.Api/Endpoints/OrderEndpoints.cs
using Mediator;
using RestaurantManagement.Api.Common;
using RestaurantManagement.Api.Contracts.Orders;
using RestaurantManagement.Application.Common.DTOs;
using RestaurantManagement.Application.Orders.CreateOrder;
using RestaurantManagement.Application.Orders.GetKitchenOrders;
using RestaurantManagement.Application.Orders.UpdateOrderStatus;

namespace RestaurantManagement.Api.Endpoints;

public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("api/orders").WithTags("Orders");

        group.MapPost("/", async (CreateOrderRequest request, ISender sender, CancellationToken ct) =>
            {
                // API sözleşmesinden Application katmanı modeline dönüşüm
                var items = request.Items
                    .Select(i => new OrderItemInput(i.MenuItemId, i.Quantity, i.SpecialInstructions))
                    .ToList();

                var result = await sender.Send(new CreateOrderCommand(request.TableId, items, request.Notes), ct);
                return result.ToApiResult(data => Results.Created($"/api/orders/{data?.Id}", data));
            })
            .Produces<OrderDto>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapPut("{orderId:int}/status", async (int orderId, UpdateOrderStatusRequest request, ISender sender, CancellationToken ct) =>
            {
                var result = await sender.Send(new UpdateOrderStatusCommand(orderId, request.NewStatus), ct);
                return result.ToApiResult();
            })
            .Produces<OrderDto>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapGet("kitchen", async (ISender sender, CancellationToken ct) =>
            {
                var result = await sender.Send(new GetKitchenOrdersQuery(), ct);
                return result.ToApiResult();
            })
            .Produces<List<OrderDto>>();

        return app;
    }
}
```

`ResultHelper` (bkz. [Result Pattern](#5-result-pattern)) `ResultType` değerini HTTP durum koduna çevirir: `NotFound` → `404`, `Conflict` → `409`, `Failure` → `400`.

---

## 8. Frameworks & Drivers Katmanı: Infrastructure

Repository, Read Service implementasyonları ve `DbContext` bu katmanda yer alır. Application katmanındaki arayüzleri implement eder; ama Application katmanı bu implementasyonları bilmez.

### Yazma Tarafı: Repository ve Unit of Work (EF Core)

Repository yalnızca aggregate root'u yükler. `Order` aggregate'i `OrderItems` ile birlikte gelir; Update metodu yoktur, çünkü EF Core change tracking değişiklikleri `SaveChangesAsync` sırasında algılar.

```csharp
// src/RestaurantManagement.Infrastructure/Repositories/OrderRepository.cs
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Domain.Entities;
using RestaurantManagement.Infrastructure.Data;

namespace RestaurantManagement.Infrastructure.Repositories;

public sealed class OrderRepository(RestaurantDbContext context) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await context.Orders
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);
    }

    public async Task AddAsync(Order order, CancellationToken cancellationToken = default)
    {
        await context.Orders.AddAsync(order, cancellationToken);
    }

    public Task DeleteAsync(Order order, CancellationToken cancellationToken = default)
    {
        context.Orders.Remove(order);
        return Task.CompletedTask;
    }
}
```

```csharp
// src/RestaurantManagement.Infrastructure/Repositories/UnitOfWork.cs
using Microsoft.EntityFrameworkCore.Storage;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Infrastructure.Data;

namespace RestaurantManagement.Infrastructure.Repositories;

public sealed class UnitOfWork(
    RestaurantDbContext context,
    ITableRepository tableRepository,
    IMenuItemRepository menuItemRepository,
    IOrderRepository orderRepository) : IUnitOfWork
{
    private IDbContextTransaction? _transaction;

    public ITableRepository Tables => tableRepository;
    public IMenuItemRepository MenuItems => menuItemRepository;
    public IOrderRepository Orders => orderRepository;

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            return await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // EF Core'a özgü exception Application katmanına sızmaz
            throw new InvalidOperationException("The data was modified by another request. Please retry.");
        }
    }

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default) =>
        _transaction = await context.Database.BeginTransactionAsync(cancellationToken);

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }
}
```

### Okuma Tarafı: Read Service (Dapper)

Okuma tarafı aggregate yüklemez; SQL ile doğrudan DTO üretir. Böylece sorgular domain modelinden ve EF Core `Include` zincirlerinden bağımsız olarak optimize edilebilir. Dapper, yalnızca bu katmanda kullanılır; Application katmanı `IOrderReadService` arayüzünü bilir.

```csharp
// src/RestaurantManagement.Infrastructure/Data/DbConnectionFactory.cs
using System.Data.Common;
using Microsoft.Data.Sqlite;

namespace RestaurantManagement.Infrastructure.Data;

public interface IDbConnectionFactory
{
    DbConnection CreateConnection();
}

public sealed class SqliteConnectionFactory(string connectionString) : IDbConnectionFactory
{
    public DbConnection CreateConnection() => new SqliteConnection(connectionString);
}
```

```csharp
// src/RestaurantManagement.Infrastructure/ReadServices/DapperTableReadService.cs
using Dapper;
using RestaurantManagement.Application.Common.DTOs;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Domain.Entities;
using RestaurantManagement.Infrastructure.Data;

namespace RestaurantManagement.Infrastructure.ReadServices;

public sealed class DapperTableReadService(IDbConnectionFactory connectionFactory) : ITableReadService
{
    public async Task<IReadOnlyList<TableDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT Id, TableNumber, Capacity, Status, ReservedAt
            FROM Tables
            ORDER BY TableNumber
            """;

        await using var connection = connectionFactory.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var rows = await connection.QueryAsync<TableRow>(
            new CommandDefinition(sql, cancellationToken: cancellationToken));

        return rows
            .Select(r => new TableDto(r.Id, r.TableNumber, r.Capacity, ((TableStatus)r.Status).ToString(), r.ReservedAt))
            .ToList();
    }

    private sealed class TableRow
    {
        public int Id { get; set; }
        public int TableNumber { get; set; }
        public int Capacity { get; set; }
        public int Status { get; set; }
        public DateTime? ReservedAt { get; set; }
    }
}
```

`DapperOrderReadService` aynı yaklaşımla `Orders` ve `OrderItems` tablolarını (`MenuItems` ile join yaparak) iki sorguda okuyup `OrderDto` listesine dönüştürür; tam hali örnek projededir.

---

## 9. Dependency Injection Konfigürasyonu

Her katman kendi servislerini bir extension metodla kaydeder. `Program.cs` (composition root) yalnızca bu metotları çağırır; Infrastructure'ın Application arayüzlerini implement ettiğini DI container'a bildiren yer bu katmandır. Bu dosyalar Frameworks & Drivers katmanına aittir.

```csharp
// src/RestaurantManagement.Application/DependencyInjection.cs
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using RestaurantManagement.Application.Common.Behaviors;

namespace RestaurantManagement.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssembly(typeof(DependencyInjection).Assembly, ServiceLifetime.Scoped);

        services.AddMediator(options =>
        {
            options.ServiceLifetime = ServiceLifetime.Scoped;
            options.PipelineBehaviors = [typeof(ValidationBehavior<,>)];
        });

        return services;
    }
}
```

```csharp
// src/RestaurantManagement.Infrastructure/DependencyInjection.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using RestaurantManagement.Application.Common.Interfaces;
using RestaurantManagement.Infrastructure.Data;
using RestaurantManagement.Infrastructure.ReadServices;
using RestaurantManagement.Infrastructure.Repositories;

namespace RestaurantManagement.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<RestaurantDbContext>(options =>
            options.UseSqlite(connectionString));

        // Okuma tarafı (Dapper)
        services.AddSingleton<IDbConnectionFactory>(new SqliteConnectionFactory(connectionString));
        services.AddScoped<IOrderReadService, DapperOrderReadService>();
        services.AddScoped<ITableReadService, DapperTableReadService>();
        services.AddScoped<IMenuItemReadService, DapperMenuItemReadService>();

        // Yazma tarafı (EF Core)
        services.AddScoped<ITableRepository, TableRepository>();
        services.AddScoped<IMenuItemRepository, MenuItemRepository>();
        services.AddScoped<IOrderRepository, OrderRepository>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        return services;
    }
}
```

```csharp
// src/RestaurantManagement.Api/Program.cs
using RestaurantManagement.Api.Endpoints;
using RestaurantManagement.Application;
using RestaurantManagement.Infrastructure;
using RestaurantManagement.Infrastructure.Data;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddAuthorization();

builder.Services.AddInfrastructure(
    builder.Configuration.GetConnectionString("RestaurantDb") ?? "Data Source=restaurant.db");

builder.Services.AddApplication();

var app = builder.Build();

// Seed database
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<RestaurantDbContext>();
    await context.Database.EnsureCreatedAsync().ConfigureAwait(false);
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapMenuItemEndpoints();
app.MapOrderEndpoints();
app.MapTableEndpoints();

await app.RunAsync().ConfigureAwait(false);

public partial class Program { }
```

Handler'lar ve validator'lar assembly taraması / source generator ile otomatik bulunur; yeni bir use case için `Program.cs` veya DI dosyalarında değişiklik gerekmez.

---

## 10. Mimari Testler (Architecture Tests)

Dependency Rule'un yalnızca dokümanla değil, **otomatik testlerle** korunması gerekir. Örnek projedeki `RestaurantManagement.Api.ArchTests` projesi [NetArchTest.Rules](https://github.com/BenMorris/NetArchTest) ile kuralları derleme sonrası doğrular; bir kural ihlal edilirse test başarısız olur ve ihlal eden tipler hata mesajında listelenir.

```csharp
// test/RestaurantManagement.Api.ArchTests/LayerDependencyTests.cs
public class LayerDependencyTests
{
    [Fact]
    public void Domain_ShouldNotDependOnOtherLayers() =>
        AssertNoDependency(DomainAssembly, ApplicationNs, InfrastructureNs, ApiNs);

    [Fact]
    public void Application_ShouldNotDependOnInfrastructureOrApi() =>
        AssertNoDependency(ApplicationAssembly, InfrastructureNs, ApiNs);

    [Fact]
    public void Infrastructure_ShouldNotDependOnApi() =>
        AssertNoDependency(InfrastructureAssembly, ApiNs);

    [Fact]
    public void Application_ShouldNotDependOnInfrastructurePackages() =>
        AssertNoDependency(ApplicationAssembly, [.. InfrastructurePackages, "Microsoft.AspNetCore"]);
}
```

Katman bağımlılıklarının dışında her katman için konvansiyon kuralları da bulunur:

| Katman | Örnek kurallar |
|---|---|
| Domain | Entity'ler `BaseEntity`'den türemeli; public setter olmamalı; `Dto`, `Command`, `Handler` gibi ekler kullanılmamalı |
| Application | Her command/query için tam olarak bir handler olmalı; handler'lar `sealed` olmalı ve birbirine bağımlı olmamalı; command/query'ler immutable olmalı |
| Infrastructure | Repository'ler ve read service'ler Application arayüzünü implement etmeli; yazma tarafı okuma tarafına bağımlı olmamalı |
| Api | Endpoint'ler Domain'e, repository'lere ve `DbContext`'e bağımlı olmamalı; contract'lar `Request`/`Response` ile bitmeli |

Projedeki diğer test projeleri: `Api.Tests` (domain, handler, validator ve behavior birim testleri), `Api.IntegrationTests` (repository, read service ve UnitOfWork — SQLite), `Api.FunctionalTests` (`WebApplicationFactory` ile uçtan uca endpoint testleri).

---

## 11. Örnek Proje Referansı

Bu yazıdaki tüm kod örnekleri aşağıdaki GitHub deposundan alınmıştır:

🔗 [DTVegaArchChapter/ArchitecturePatterns — Clean Architecture](https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Clean)

**Çalıştırmak için:**

```bash
git clone https://github.com/DTVegaArchChapter/ArchitecturePatterns.git
cd ArchitecturePatterns/Examples/Clean
dotnet run --project src/RestaurantManagement.Api
```

API Scalar arayüzüne `https://localhost:{port}/scalar` adresinden erişebilirsiniz. Proje SQLite kullanır; veritabanı (`restaurant.db`) ilk çalışmada otomatik oluşturulur.

Testleri çalıştırmak için:

```bash
dotnet test
```

---

## 12. Clean Architecture vs Onion Architecture vs Hexagonal Architecture

| Özellik | Clean Architecture | Onion Architecture | Hexagonal Architecture |
|---|---|---|---|
| **Kaynakça** | Robert C. Martin (Uncle Bob), 2012 | Jeffrey Palermo, 2008 | Alistair Cockburn, 2005 |
| **Katman sayısı** | 4 (Entities, Use Cases, Interface Adapters, Frameworks & Drivers) | Esnek (Domain, Application, Infrastructure, Presentation) | 3 (Domain, Ports, Adapters) |
| **Uygulama katmanı** | Use Case'ler (Command/Query + Handler; Mediator tercih edilebilir) | Command/Query Handler (CQRS + Mediator) | Port + Use Case |
| **Interface Adapters** | Açıkça tanımlanmış katman | Presentation katmanına dahil | Adapter sınıfları |
| **Bağımlılık yönü** | İçe doğru | İçe doğru | Domain'e doğru |
| **Birincil odak** | Use Case izolasyonu | Domain modeli | Port/Adapter ayrımı |
| **Mediator/CQRS** | Zorunlu değil; örnek projede kullanılır | Yaygın tercih | Gerekmez |
| **Test edilebilirlik** | Çok yüksek | Çok yüksek | Çok yüksek |
| **Başlangıç karmaşıklığı** | Orta-Yüksek | Orta-Yüksek | Orta |
| **Uygun proje tipi** | Domain karmaşık, çoklu UI | Domain karmaşık, uzun ömürlü | Çoklu dış sistem entegrasyonu |

### Özet Karar Rehberi

```
Basit CRUD, hız öncelik?
  → Vertical Slice Architecture

Çoklu dış sistem (API, mesaj kuyruğu, dosya) entegrasyonu kritik?
  → Hexagonal Architecture

CQRS/Mediator pipeline tercih edilir, büyük domain modeli?
  → Onion Architecture veya Clean Architecture (ikisi de CQRS ile uyumludur)

Use Case izolasyonu öncelik, framework bağımsızlığı kritik, çoklu UI?
  → Clean Architecture
```

---

## 13. Anti-Patterns ve Yaygın Hatalar

### Handler içinde doğrudan DbContext kullanımı

```csharp
// ❌ YANLIŞ — Handler Infrastructure'a bağımlı; test edilemez
public sealed class CreateOrderCommandHandler(RestaurantDbContext context)
    : ICommandHandler<CreateOrderCommand, Result<OrderDto>>
{
    public async ValueTask<Result<OrderDto>> Handle(CreateOrderCommand command, CancellationToken ct)
    {
        var table = await context.Tables.FindAsync(command.TableId);
        // ...
    }
}

// ✅ DOĞRU — Handler arayüze bağımlı; Infrastructure değiştirilebilir
public sealed class CreateOrderCommandHandler(IUnitOfWork unitOfWork)
    : ICommandHandler<CreateOrderCommand, Result<OrderDto>>
{
    public async ValueTask<Result<OrderDto>> Handle(CreateOrderCommand command, CancellationToken ct)
    {
        var table = await unitOfWork.Tables.GetByIdAsync(command.TableId, ct);
        // ...
    }
}
```

### Domain entity içinde iş mantığı yerine servis çağrısı

```csharp
// ❌ YANLIŞ — Entity dış servise bağımlı; Dependency Rule ihlali
public class Order
{
    public void StartPreparation(INotificationService notificationService)
    {
        Status = OrderStatus.InPreparation;
        notificationService.NotifyKitchen(this); // Domain'de infrastructure!
    }
}

// ✅ DOĞRU — Entity yalnızca kuralı uygular; çağrı Handler içinde yapılır
public class Order
{
    public DomainResult StartPreparation()
    {
        if (Status != OrderStatus.Pending)
            return DomainResult.Failure("...");

        Status = OrderStatus.InPreparation;
        return DomainResult.Success();
    }
}
// Handler içinde: order.StartPreparation(); await notificationService.NotifyKitchenAsync(order);
```

### Katmanlar arasında doğrudan entity geçirme (API → Domain)

```csharp
// ❌ YANLIŞ — Endpoint Domain entity'sini döndürüyor
group.MapGet("{id}", async (int id, IOrderRepository orders) =>
    await orders.GetByIdAsync(id)); // Order domain entity'si!

// ✅ DOĞRU — Interface Adapters yalnızca DTO dönen Query gönderir
group.MapGet("{id}", async (int id, ISender sender, CancellationToken ct) =>
{
    var result = await sender.Send(new GetOrderQuery(id), ct);
    return result.ToApiResult(); // OrderDto döner, Order değil
});
```

### Query'lerde aggregate yükleme

```csharp
// ❌ YANLIŞ — Okuma için aggregate yükleyip DTO'ya map etmek (gereksiz Include, change tracking)
public sealed class GetKitchenOrdersQueryHandler(IUnitOfWork unitOfWork) { ... }

// ✅ DOĞRU — Okuma tarafı Read Service ile doğrudan DTO üretir
public sealed class GetKitchenOrdersQueryHandler(IOrderReadService orderReadService)
    : IQueryHandler<GetKitchenOrdersQuery, Result<List<OrderDto>>> { ... }
```

### Beklenen iş kuralı ihlallerinde exception fırlatmak

```csharp
// ❌ YANLIŞ — Akış kontrolü için exception; her yerde try/catch gerektirir
public void Serve()
{
    if (Status != OrderStatus.Ready)
        throw new InvalidOperationException("Cannot serve order");
    Status = OrderStatus.Served;
}

// ✅ DOĞRU — DomainResult döndür; Handler bunu Result<T>.Conflict'e çevirir
public DomainResult Serve()
{
    if (Status != OrderStatus.Ready)
        return DomainResult.Failure($"Cannot serve order with status: {Status}");

    Status = OrderStatus.Served;
    return DomainResult.Success();
}
```

### Tüm Use Case'leri tek bir God Handler içinde birleştirme

```csharp
// ❌ YANLIŞ — OrderHandler tüm order işlemlerini biliyor
public class OrderHandler
{
    public Task CreateAsync(...) { ... }
    public Task UpdateStatusAsync(...) { ... }
    public Task GetKitchenOrdersAsync() { ... }
    public Task CancelAsync(...) { ... }
}

// ✅ DOĞRU — Her senaryo izole, bağımsız bir Command/Query + Handler çifti
public sealed class CreateOrderCommandHandler : ICommandHandler<CreateOrderCommand, Result<OrderDto>> { ... }
public sealed class UpdateOrderStatusCommandHandler : ICommandHandler<UpdateOrderStatusCommand, Result<OrderDto>> { ... }
public sealed class GetKitchenOrdersQueryHandler : IQueryHandler<GetKitchenOrdersQuery, Result<List<OrderDto>>> { ... }
```

---

## FAQ

**S: Clean Architecture ile Onion Architecture arasındaki temel fark nedir?**

C: İkisi de bağımlılıkları içe doğru yönlendirir ve aynı temel prensibi paylaşır. Onion Architecture katman isimlerine daha az önem verir, CQRS/Mediator ile sıkça birleştirilir ve repository arayüzlerini Domain katmanında tanımlar. Clean Architecture ise **Interface Adapters** katmanını açıkça adlandırır, **Use Case** sınıflarını ön plana çıkarır ve "Use Case izolasyonu" kavramını merkeze alır. Pratik uygulamada farklar küçüktür; her ikisi de aynı testedilebilirlik ve framework bağımsızlığı hedefini taşır.

**S: Use Case'ler için Mediator/CQRS şart mı?**

C: Hayır. Uncle Bob'un orijinal Clean Architecture tanımında Mediator yoktur; Use Case'ler doğrudan DI container'a kayıtlı sınıflar olarak da yazılabilir ve Controller/Endpoint'e inject edilebilir. Örnek projede ise [Mediator](https://github.com/martinothamar/Mediator) kullanılır; çünkü Api katmanını handler sınıflarından ayırır ve `ValidationBehavior` gibi cross-cutting concern'leri pipeline olarak merkezi yönetmeyi sağlar. CQRS de zorunlu değildir; ancak okuma ve yazma tarafını ayrı modellemek (Repository + Read Service) sorgu performansını ve domain modelinin sadeliğini artırır.

**S: Okuma tarafında neden EF Core yerine Dapper (Read Service) kullanılıyor?**

C: Okuma tarafı iş kuralı çalıştırmaz; yalnızca DTO üretir. Aggregate yüklemek (Include, change tracking) gereksiz maliyettir. Read Service arayüzü Application katmanında tanımlıdır, Dapper yalnızca Infrastructure'da kalır. İsterseniz aynı arayüzü EF Core `AsNoTracking` sorgularıyla da implement edebilirsiniz; Application katmanı etkilenmez.

**S: Repository arayüzleri neden Infrastructure katmanında değil Application katmanında tanımlanır?**

C: Dependency Rule gereği; Use Cases katmanı (Application) dış katmanları (Infrastructure) bilmemelidir. Arayüz Application'da tanımlanır, implementasyon Infrastructure'da yapılır. Bu sayede Infrastructure tamamen değiştirilse bile Application katmanı etkilenmez. Dependency Inversion Principle'ın doğrudan uygulamasıdır.

**S: Domain entity'lerine EF Core navigasyon özellikleri eklemek Dependency Rule'u ihlal eder mi?**

C: Teknik olarak evet; ancak bu pragmatik bir uzlaşıdır. Domain entity'si EF Core attribute'larından bağımsız kalır (sadece POCO class), navigasyon özellikleri sadece C# referanslarıdır. EF Core konfigürasyonu `OnModelCreating` içinde Infrastructure katmanında yapılır; Domain katmanında `using Microsoft.EntityFrameworkCore;` bulunmaz. Bu yaklaşım çoğu projede kabul görür.

**S: Her Use Case için ayrı bir sınıf oluşturmak çok fazla dosya yaratmıyor mu?**

C: Evet, dosya sayısı artar. Ancak her sınıfın tek sorumluluğu olduğundan test yazımı, değişiklik takibi ve kod incelemesi kolaylaşır. `CreateOrderCommandHandler` değiştiğinde `GetKitchenOrdersQueryHandler` etkilenmez; mimari testler handler'ların birbirine bağımlı olmasını da engeller. Bu tradeoff, orta-büyük projelerde net bir avantajdır; küçük projelerde Vertical Slice Architecture daha pratik olabilir.

**S: Clean Architecture'da event sourcing veya domain event nasıl eklenir?**

C: Domain event'ler Entities katmanına eklenir; Use Case execute edildikten sonra yayınlanır. Örnek: `order.AddDomainEvent(new OrderCreatedEvent(order.Id))`. Event handler'lar Application katmanında tanımlanır. Bu yapı Clean Architecture ile uyumludur çünkü event yayınlama mekanizması Use Cases aracılığıyla çalışır; Domain hiçbir event bus kütüphanesine bağımlı değildir.

---

## Kaynaklar

- [Uncle Bob — The Clean Architecture (Blog, 2012)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Clean Architecture: A Craftsman's Guide to Software Structure and Design — Robert C. Martin](https://www.amazon.com/Clean-Architecture-Craftsmans-Software-Structure/dp/0134494164)
- [DTVegaArchChapter/ArchitecturePatterns — Clean Architecture Örnek Proje](https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Clean)
- [Onion Architecture Nedir? — Bu Serinin 2. Yazısı](/mimari/onion%20architecture/2026/02/24/onion-architecture-nedir.html)
- [Hexagonal Architecture Nedir? — Bu Serinin 3. Yazısı](/mimari/hexagonal%20architecture/2026/04/30/hexagonal-architecture-nedir.html)

---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
        {
            "@type": "Question",
            "name": "Clean Architecture ile Onion Architecture arasındaki temel fark nedir?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "İkisi de bağımlılıkları içe doğru yönlendirir. Onion Architecture CQRS/Mediator ile sıkça birleştirilir ve repository arayüzlerini Domain katmanında tanımlar. Clean Architecture ise Interface Adapters katmanını açıkça adlandırır ve Use Case sınıflarını ön plana çıkarır. Pratik uygulamada farklar küçüktür."
            }
        },
        {
            "@type": "Question",
            "name": "Use Case'ler için Mediator veya CQRS şart mı?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Hayır. Uncle Bob'un orijinal Clean Architecture tanımında Mediator yoktur; Use Case'ler doğrudan DI container'a kayıtlı sınıflar olarak da yazılabilir. Örnek projede Mediator, Api katmanını handler sınıflarından ayırmak ve ValidationBehavior gibi cross-cutting concern'leri pipeline olarak yönetmek için kullanılır ancak zorunlu değildir."
            }
        },
        {
            "@type": "Question",
            "name": "Repository arayüzleri neden Application katmanında tanımlanır?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Dependency Rule gereği Use Cases katmanı dış katmanları bilmemelidir. Arayüz Application'da tanımlanır, implementasyon Infrastructure'da yapılır. Bu sayede Infrastructure tamamen değiştirilse bile Application katmanı etkilenmez. Dependency Inversion Principle'ın doğrudan uygulamasıdır."
            }
        },
        {
            "@type": "Question",
            "name": "Clean Architecture ne zaman kullanılmalıdır?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Orta-büyük ölçekli, domain karmaşıklığı yüksek ve uzun ömürlü uygulamalarda tercih edilmelidir. Birden fazla UI, ORM değişimi öngörüsü veya yüksek test kapsamı hedeflendiğinde Clean Architecture güçlü bir seçenektir. Basit CRUD uygulamaları veya kısa ömürlü MVP'ler için overkill olabilir."
            }
        },
        {
            "@type": "Question",
            "name": "Her Use Case için ayrı sınıf oluşturmak gerekli mi?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Evet, her kullanım senaryosu kendi sınıfında izole edilir. Bu dosya sayısını artırır ancak her sınıfın tek sorumluluğu olduğundan test yazımı, değişiklik takibi ve kod incelemesi kolaylaşır. Küçük projelerde Vertical Slice Architecture daha pratik olabilir."
            }
        },
        {
            "@type": "Question",
            "name": "Domain entity'lerine EF Core navigasyon özellikleri eklemek Dependency Rule'u ihlal eder mi?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Teknik olarak evet ancak bu pragmatik bir uzlaşıdır. Domain entity'si EF Core attribute'larından bağımsız kalır (sadece POCO class), navigasyon özellikleri sadece C# referanslarıdır. EF Core konfigürasyonu Infrastructure katmanında yapılır; Domain katmanında EF Core bağımlılığı bulunmaz."
            }
        }
    ]
}
</script>
<!-- markdownlint-enable MD033 -->
