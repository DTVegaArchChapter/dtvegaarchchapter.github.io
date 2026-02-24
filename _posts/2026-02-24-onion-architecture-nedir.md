---
layout: post
title: "Onion Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber"
categories: [mimari, onion architecture]
tags: [onion architecture, clean architecture, layered architecture, cqrs, mediator, repository pattern, dependency inversion]
lang: tr
author: QuickOrBeDead
excerpt: Onion Architecture nedir, nasıl uygulanır, hangi problemleri çözer? Katman yapısı, bağımlılık yönü, Repository Pattern, CQRS entegrasyonu, anti-pattern'ler ve gerçek dünya senaryolarıyla detaylı rehber.
date: 2026-02-24
last_modified_at: 2026-02-24 10:00:00 +0300
---

> 📚 **Architecture Patterns Serisi**
> Bu yazı, farklı mimari yaklaşımları karşılaştırmalı olarak ele aldığımız serinin **2. yazısıdır**.
> - Yazı 1: [Vertical Slice Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber](/mimari/vertical%20slice%20architecture/2026/02/03/vertical-slice-architecture-nedir.html)
> - **Yazı 2: Onion Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber** _(bu yazı)_

---

## TL;DR

- Onion Architecture, uygulamayı eş merkezli katmanlar (halkalar) halinde organize eder; en içteki halka Domain'dir ve hiçbir dış bağımlılığı yoktur.
- Bağımlılıklar her zaman içe doğru akar: Presentation → Application → Domain, Infrastructure → Application → Domain. Domain hiçbir katmana bağımlı değildir.
- Repository arayüzleri Domain katmanında tanımlanır, implementasyonlar Infrastructure katmanında yer alır; böylece iş mantığı veritabanı teknolojisinden bağımsız olur.
- CQRS ve Mediator ile Application katmanında Commands/Queries izole edilir; pipeline behavior'larla cross-cutting concern'ler (validation, logging) merkezi olarak yönetilir.
- Kullanılması gereken yerler: Orta-büyük ölçekli, uzun ömürlü ve domain karmaşıklığı yüksek uygulamalar.
- Kullanılmaması gereken yerler: Basit CRUD uygulamaları, kısa ömürlü MVP/prototip, domain karmaşıklığı olmayan sistemler.

---

## 1. Onion Architecture Nedir?

Onion Architecture, Jeffrey Palermo tarafından 2008 yılında tanıtılan ve uygulamayı **eş merkezli katmanlar** ile organize eden bir mimari yaklaşımdır. "Soğan mimarisi" olarak da bilinen bu yaklaşımda her katman, kendisinden daha içteki katmanlara bağımlıdır; bağımlılıklar her zaman içe doğru, yani merkezdeki **Domain** katmanına doğru akar.

![Onion Architecture](/assets/images/posts/onion-architecture.png)

### Temel Prensipler

- **Domain merkezdedir**: İş kuralları ve entity'ler en iç halkada yer alır; framework, veritabanı veya UI'a bağımlılık yoktur.
- **Bağımlılık yönü içe doğrudur**: Her katman yalnızca kendisinden daha içteki katmanlara bağımlı olabilir.
- **Dependency Inversion**: Üst katmanlar alt katman implementasyonlarına değil, arayüzlere (interface) bağımlıdır.
- **Repository arayüzleri Domain'de**: Veri erişim sözleşmeleri Domain katmanında tanımlanır; implementasyonlar Infrastructure'da kalır.
- **Teknoloji bağımsızlığı**: ORM, framework veya UI teknolojisi değiştiğinde iş mantığı etkilenmez.

### Motivasyon: Hangi Problemi Çözer?

Geleneksel N-katmanlı mimaride yaygın sorunlar:

1. **Ters Bağımlılık (Inverted Dependency)**: Domain katmanı Infrastructure'a (veritabanına) bağımlı olur; iş mantığı veri erişim koduna sıkışır.
2. **Test Zorluğu**: Repository'ler doğrudan Domain'de kullanıldığında birim test yazarken gerçek veritabanı bağlantısı gerekmektedir.
3. **Teknoloji Kilitlenme**: ORM veya veritabanı değiştiğinde iş mantığı kodu da değişmek zorunda kalır.
4. **Sorumluluk Karışıklığı**: Servis sınıfları hem iş mantığını hem de veri erişim detaylarını barındırır.
5. **Büyüme Sorunu**: Uygulama büyüdükçe katmanlar arası bağımlılıklar karmaşıklaşır, "spaghetti code" oluşur.

Onion Architecture Çözümü:

- Domain saf ve bağımsız; değişim maliyeti düşük.
- Repository arayüzleri sayesinde Infrastructure mock'lanabilir; unit test kolay.
- Teknoloji değişimi yalnızca Infrastructure katmanını etkiler.

### Avantajlar

- **Yüksek Test Edilebilirlik**: Domain iş mantığı tamamen izole, bağımlılıklar olmadan test edilebilir. Repository arayüzleri sayesinde mock'lama çok kolay.
- **Güçlü Bağımsızlık (Independence)**: İş mantığı framework, veritabanı veya UI teknolojisine bağımlı değildir. ORM değiştirmek sadece Infrastructure katmanını etkiler.
- **Dependency Inversion Prensibi**: Üst katmanlar alt katman implementasyonlarına değil, arayüzlere bağımlıdır. Sınıfların implementasyonları dışarıdan enjekte edilir.
- **Uzun Ömürlü ve Sürdürülebilir Mimari**: Domain modeli zaman içinde kararlı kalır. Teknoloji değişimleri iş mantığını etkilemez.
- **Açık Sorumluluk Sınırları**: Her katmanın görevi nettir. Kod nereye yazılacağı konusunda belirsizlik yoktur.

### Dezavantajlar

- **Yüksek Başlangıç Karmaşıklığı**: Küçük projeler için fazla yapı olabilir. Birden fazla proje ve katman yönetimi gerektirir.
- **Boilerplate Kod**: Her özellik için birden fazla katmanda değişiklik gerekir. Command, Handler, DTO, Repository gibi çok sayıda sınıf oluşturulur.
- **Öğrenme Eğrisi**: Yeni geliştiriciler için katmanlar arası geçiş ve bağımlılık yönü kafa karıştırıcı olabilir.
- **Aşırı Mühendislik (Over-Engineering)**: Sadece bir veritabanı tablosuna veri yazıp okuyacağın basit bir işlev için bile Entity, Repository Interface, Handler, DTO ve Mapping katmanlarından geçmek gerekir.
- **Yeni Feature Maliyeti**: Yeni bir özellik eklerken tüm katmanlara dokunmak gerekir; Vertical Slice Architecture'a kıyasla daha fazla dosya değişir.

### Ne Zaman Kullanmalı?

- Orta-büyük ölçekli, uzun ömürlü uygulamalar
- Domain karmaşıklığı orta/yüksek olan projeler
- Teknoloji bağımsızlığının kritik olduğu sistemler (ORM, DB değişim riski)
- Test edilebilirliğin ön planda olduğu kurumsal yazılımlar

### Ne Zaman Kullanmamalı?

- Çok basit CRUD uygulamaları (3-5 tablo, minimal business logic)
- Kısa ömürlü prototip veya MVP (Minimum Viable Product)
- Tek geliştirici ve basit gereksinimler
- Sadece raporlama/ETL ağırlıklı sistemler (domain logic yok)
- Legacy sistemde küçük iyileştirme (tam yeniden yapılanma planı yoksa)

---

## 2. Katman Yapısı ve Bağımlılık Yönü

### Bağımlılık Akışı

```text
Api          →  Application  →  Domain
Infrastructure →  Application  →  Domain
```

Domain katmanı hiçbir katmana bağımlı değildir; tüm bağımlılıklar Domain'e doğru akar.

### Domain Katmanı

Domain, uygulamanın kalbidir. Framework, ORM veya UI teknolojisine hiçbir bağımlılığı yoktur:

```csharp
// Domain/Entities/Order.cs
public class Order : BaseEntity
{
    public string OrderNumber { get; private set; }
    public int TableId { get; private set; }
    public OrderStatus Status { get; private set; }
    public List<OrderItem> OrderItems { get; private set; } = new();

    public void AddItem(MenuItem menuItem, int quantity, string? instructions = null)
    {
        // Saf iş mantığı - dışa bağımlılık yok
        OrderItems.Add(new OrderItem
        {
            MenuItemId = menuItem.Id,
            Quantity = quantity,
            Price = menuItem.Price,
            SpecialInstructions = instructions
        });
    }

    public void UpdateStatus(OrderStatus newStatus)
    {
        Status = newStatus;
    }
}

// Domain/Repositories/IOrderRepository.cs
// Repository ARAYÜZÜ Domain katmanında tanımlanır
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    Task<IEnumerable<Order>> GetKitchenOrdersAsync(CancellationToken ct = default);
}

// Domain/Repositories/IUnitOfWork.cs
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
```

### Application Katmanı

Application katmanı, use case'leri (iş senaryolarını) yönetir:

```csharp
// Application/Orders/Commands/CreateOrder/CreateOrderCommandHandler.cs
public class CreateOrderCommandHandler(
    IOrderRepository orderRepository,
    ITableRepository tableRepository,
    IMenuItemRepository menuItemRepository,
    IUnitOfWork unitOfWork)
    : IRequestHandler<CreateOrderCommand, Result<int>>
{
    public async Task<Result<int>> Handle(CreateOrderCommand request, CancellationToken ct)
    {
        var table = await tableRepository.GetByIdAsync(request.TableId, ct);
        if (table is null)
            return Result<int>.Failure($"Table {request.TableId} not found");

        if (table.Status is TableStatus.Occupied or TableStatus.Reserved)
            return Result<int>.Failure($"Table {table.Id} is not available");

        var menuItemIds = request.Items.Select(i => i.MenuItemId).ToList();
        var menuItems = await menuItemRepository.GetByIdsAsync(menuItemIds, ct);

        var order = new Order
        {
            OrderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd-HHmmss}",
            TableId = request.TableId,
            Notes = request.Notes
        };

        foreach (var item in request.Items)
        {
            var menuItem = menuItems.First(m => m.Id == item.MenuItemId);
            order.AddItem(menuItem, item.Quantity, item.SpecialInstructions);
        }

        await orderRepository.AddAsync(order, ct);
        await unitOfWork.SaveChangesAsync(ct);

        return Result<int>.Success(order.Id);
    }
}
```

### Infrastructure Katmanı

Infrastructure katmanı, Domain katmanında tanımlanan repository arayüzlerini somut teknolojilerle (EF Core) implemente eder:

```csharp
// Infrastructure/Repositories/OrderRepository.cs
public class OrderRepository(RestaurantDbContext context) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct = default)
        => await context.Orders
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task AddAsync(Order order, CancellationToken ct = default)
        => await context.Orders.AddAsync(order, ct);

    public async Task<IEnumerable<Order>> GetKitchenOrdersAsync(CancellationToken ct = default)
        => await context.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
            .Include(o => o.Table)
            .Where(o => o.Status == OrderStatus.Pending || o.Status == OrderStatus.Preparing)
            .OrderBy(o => o.OrderDate)
            .ToListAsync(ct);
}
```

### Presentation Katmanı

Presentation katmanı sadece Application katmanına bağımlıdır; HTTP isteklerini Command/Query'ye dönüştürür:

```csharp
// Api/Controllers/OrdersController.cs
[ApiController]
[Route("api/[controller]")]
public class OrdersController(IMediator mediator) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateOrder(
        [FromBody] CreateOrderRequest request,
        CancellationToken ct)
    {
        var command = new CreateOrderCommand(request.TableId, request.Items, request.Notes);
        var result = await mediator.Send(command, ct);
        return result.ToActionResult(id => CreatedAtAction(nameof(GetOrder), new { id }, id));
    }
}
```

---

## 3. Klasör Yapısı

### Tam Proje Yapısı

```text
src/
├── RestaurantManagement.Api/                       # Presentation Layer
│   ├── Common/
│   │   └── ResultHelper.cs                         # Result<T> → HTTP response dönüşüm yardımcısı
│   ├── Contracts/
│   │   ├── Orders/
│   │   │   ├── CreateOrderRequest.cs               # Sipariş oluşturma HTTP isteği modeli
│   │   │   ├── OrderItemRequest.cs                 # Sipariş kalemi HTTP isteği modeli
│   │   │   └── UpdateOrderStatusRequest.cs         # Sipariş durumu güncelleme HTTP isteği modeli
│   │   └── Tables/
│   │       └── UpdateTableStatusRequest.cs         # Masa durumu güncelleme HTTP isteği modeli
│   ├── Controllers/
│   │   ├── MenuItemsController.cs                  # Menü öğeleri API controller'ı
│   │   ├── OrdersController.cs                     # Sipariş yönetimi API controller'ı
│   │   └── TablesController.cs                     # Masa yönetimi API controller'ı
│   └── Program.cs                                  # Uygulama başlangıç noktası, DI kayıtları
│
├── RestaurantManagement.Application/               # Application Layer
│   ├── Common/
│   │   ├── Behaviors/
│   │   │   └── ValidationBehavior.cs               # MediatR Validation Behavior
│   │   ├── DTOs/
│   │   │   ├── MenuItemDto.cs
│   │   │   ├── OrderDto.cs
│   │   │   ├── OrderItemDto.cs
│   │   │   └── TableDto.cs
│   │   └── Result.cs                               # Result pattern implementasyonu
│   ├── Orders/
│   │   ├── Commands/
│   │   │   ├── CreateOrder/
│   │   │   │   ├── CreateOrderCommandHandler.cs
│   │   │   │   ├── CreateOrderCommandValidator.cs
│   │   │   │   └── OrderItemRequest.cs
│   │   │   └── UpdateOrderStatus/
│   │   │       ├── UpdateOrderStatusCommandHandler.cs
│   │   │       └── UpdateOrderStatusCommandValidator.cs
│   │   └── Queries/
│   │       └── GetKitchenOrders/
│   │           └── GetKitchenOrdersQuery.cs
│   ├── MenuItems/
│   │   └── Queries/
│   │       └── GetMenuItems/
│   │           └── GetMenuItemsQuery.cs
│   └── Tables/
│       ├── Commands/
│       │   └── UpdateTableStatus/
│       │       ├── UpdateTableStatusCommandHandler.cs
│       │       └── UpdateTableStatusCommandValidator.cs
│       └── Queries/
│           └── GetAllTables/
│               └── GetAllTablesQueryHandler.cs
│
├── RestaurantManagement.Domain/                    # Domain Layer
│   ├── Common/
│   │   └── BaseEntity.cs                           # Tüm entity'lerin temel sınıfı
│   ├── Entities/
│   │   ├── MenuItem.cs
│   │   ├── Order.cs
│   │   ├── OrderItem.cs
│   │   ├── OrderStatus.cs
│   │   ├── Table.cs
│   │   └── TableStatus.cs
│   └── Repositories/
│       ├── IMenuItemRepository.cs
│       ├── IOrderRepository.cs
│       ├── ITableRepository.cs
│       └── IUnitOfWork.cs
│
└── RestaurantManagement.Infrastructure/            # Infrastructure Layer
    ├── Data/
    │   └── RestaurantDbContext.cs
    └── Repositories/
        ├── MenuItemRepository.cs
        ├── OrderRepository.cs
        ├── TableRepository.cs
        └── UnitOfWork.cs
```

---

## 4. Repository Pattern ve Dependency Inversion

Onion Architecture'ın temel taşlarından biri **Repository Pattern** ile **Dependency Inversion Principle**'ın birlikte uygulanmasıdır.

### Neden Domain'de Arayüz Tanımlanır?

Domain katmanı, veri erişimin *nasıl* yapıldığını bilmez; yalnızca *ne* istediğini bildirir:

```csharp
// Domain/Repositories/IOrderRepository.cs
// Sözleşme Domain'de; implementasyon Infrastructure'da
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    Task<IEnumerable<Order>> GetKitchenOrdersAsync(CancellationToken ct = default);
}
```

Bu yaklaşımın faydaları:

- **ORM Bağımsızlığı**: EF Core yerine Dapper, MongoDB veya başka bir teknoloji kullanmak istediğinizde sadece Infrastructure katmanındaki implementasyon değişir; Domain ve Application dokunulmaz.
- **Test Kolaylığı**: Unit testlerde `IOrderRepository` mock'lanarak gerçek veritabanına ihtiyaç duyulmaz.
- **Açık Sözleşme**: Hangi veri erişim operasyonlarının gerekli olduğu Domain'de açıkça görülür.

### Unit of Work Pattern

Transaction yönetimi için Unit of Work arayüzü de Domain katmanında tanımlanır:

```csharp
// Domain/Repositories/IUnitOfWork.cs
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

// Infrastructure/Repositories/UnitOfWork.cs
public class UnitOfWork(RestaurantDbContext context) : IUnitOfWork
{
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
        => await context.SaveChangesAsync(ct);
}
```

---

## 5. CQRS ve Mediator Entegrasyonu

Onion Architecture, Application katmanında CQRS (Command Query Responsibility Segregation) ile doğal olarak uyumludur.

### CQRS Request/Response Flow

```text
Controller/Endpoint
  ↓ (Command/Query gönderir)
Mediator Pipeline
  ↓ (Behavior 1: Validation)
  ↓ (Behavior 2: Logging)
  ↓ Handler (Application katmanı - iş mantığı)
    ↓ Domain Entity/Repository arayüzü
    ↓ Infrastructure (Repository implementasyonu)
  ↓ (Response döner)
Controller/Endpoint (HTTP response)
```

### Command Örneği

```csharp
// Application/Tables/Commands/UpdateTableStatus/UpdateTableStatusCommandHandler.cs
public record UpdateTableStatusCommand(int TableId, TableStatus Status)
    : IRequest<Result>;

public class UpdateTableStatusCommandHandler(
    ITableRepository tableRepository,
    IUnitOfWork unitOfWork)
    : IRequestHandler<UpdateTableStatusCommand, Result>
{
    public async Task<Result> Handle(UpdateTableStatusCommand request, CancellationToken ct)
    {
        var table = await tableRepository.GetByIdAsync(request.TableId, ct);
        if (table is null)
            return Result.Failure($"Table {request.TableId} not found");

        table.UpdateStatus(request.Status);
        await unitOfWork.SaveChangesAsync(ct);
        return Result.Success();
    }
}
```

### Query Örneği (DTO Projection)

```csharp
// Application/Orders/Queries/GetKitchenOrders/GetKitchenOrdersQuery.cs
public record GetKitchenOrdersQuery : IRequest<Result<IEnumerable<KitchenOrderDto>>>;

public class GetKitchenOrdersQueryHandler(IOrderRepository orderRepository)
    : IRequestHandler<GetKitchenOrdersQuery, Result<IEnumerable<KitchenOrderDto>>>
{
    public async Task<Result<IEnumerable<KitchenOrderDto>>> Handle(
        GetKitchenOrdersQuery request,
        CancellationToken ct)
    {
        var orders = await orderRepository.GetKitchenOrdersAsync(ct);

        var dtos = orders.Select(o => new KitchenOrderDto(
            o.Id,
            o.OrderNumber,
            o.Table.TableNumber,
            o.OrderDate,
            o.Status.ToString(),
            o.OrderItems.Select(oi => new KitchenOrderItemDto(
                oi.MenuItem.Name,
                oi.MenuItem.Category,
                oi.Quantity,
                oi.SpecialInstructions)).ToList()));

        return Result<IEnumerable<KitchenOrderDto>>.Success(dtos);
    }
}
```

### Validation Behavior

```csharp
// Application/Common/Behaviors/ValidationBehavior.cs
public sealed class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var context = new ValidationContext<TRequest>(request);
        var failures = validators
            .Select(v => v.Validate(context))
            .SelectMany(r => r.Errors)
            .Where(f => f != null)
            .ToList();

        if (failures.Count != 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

---

## 6. Result Pattern

Exception fırlatmak yerine `Result<T>` döndürmek, Onion Architecture'da uygulamalar arası tutarlı hata yönetimi sağlar.

```csharp
// Application/Common/Result.cs
public class Result
{
    public bool IsSuccess { get; }
    public string? ErrorMessage { get; }

    protected Result(bool isSuccess, string? errorMessage)
    {
        IsSuccess = isSuccess;
        ErrorMessage = errorMessage;
    }

    public static Result Success() => new(true, null);
    public static Result Failure(string message) => new(false, message);
}

public class Result<T> : Result
{
    public T? Value { get; }

    private Result(bool isSuccess, T? value, string? errorMessage)
        : base(isSuccess, errorMessage)
    {
        Value = value;
    }

    public static Result<T> Success(T value) => new(true, value, null);
    public static Result<T> Failure(string message) => new(false, default, message);
    public static Result<T> NotFound(string message) => new(false, default, message);
}
```

### Controller'da HTTP Response Dönüşümü

```csharp
// Api/Common/ResultHelper.cs
public static class ResultHelper
{
    public static IActionResult ToActionResult<T>(
        this Result<T> result,
        Func<T, IActionResult>? successAction = null)
    {
        if (!result.IsSuccess)
            return result.ErrorMessage?.Contains("not found") == true
                ? new NotFoundObjectResult(result.ErrorMessage)
                : new BadRequestObjectResult(result.ErrorMessage);

        return successAction is not null && result.Value is not null
            ? successAction(result.Value)
            : new OkObjectResult(result.Value);
    }
}

// Api/Controllers/OrdersController.cs
[HttpPost]
public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request, CancellationToken ct)
{
    var result = await _mediator.Send(
        new CreateOrderCommand(request.TableId, request.Items, request.Notes), ct);
    return result.ToActionResult(id => CreatedAtAction(nameof(GetOrder), new { id }, id));
}
```

---

## 7. Karar Matrisi: Ne Zaman Kullanmalı/Kullanmamalı?

| Senaryo | Onion Architecture Uygun mu? | Neden? |
| --------- | ------------------------------ | -------- |
| Startup MVP (3-5 tablo, basit CRUD) | ❌ Hayır | Boilerplate ve katman yönetimi overkill |
| Orta ölçek, büyüme beklentisi | ✅ Evet | Domain izolasyonu ve test edilebilirlik erken kazanılır |
| Domain karmaşıklığı yüksek sistemler | ✅ Evet | İş kuralları saf, bağımsız geliştirilir |
| Uzun ömürlü kurumsal uygulama | ✅ Evet | Teknoloji değişimine karşı dirençli mimari |
| ORM/DB değişimi olasılığı | ✅ Evet | Sadece Infrastructure etkilenir; Domain ve Application dokunulmaz |
| Mikroservis geçiş planı | ✅ Evet | Her servis kendi Onion yapısında olabilir |
| Yüksek test coverage hedefi | ✅ Evet | Repository mock'lama çok kolay; unit test süreci hızlanır |
| Basit raporlama/ETL sistemi | ❌ Hayır | Domain logic yok; script veya basit katman yeterli |
| Prototip, kavram kanıtı (PoC) | ❌ Hayır | Geliştirme hızı öncelikli; aşırı yapılanma gerekmiyor |
| Ekip yeni, öğrenme sürecinde | ⚠️ Dikkatli | Öğrenme eğrisi yönetilmeli; pair programming önerilir |

---

## 8. Anti-Pattern ve Kırmızı Bayraklar

| Anti-Pattern | Sonuç | Çözüm |
|--------------|-------|-------|
| Domain'de Infrastructure Bağımlılığı | Domain katmanı EF Core, DbContext gibi kütüphanelere bağımlı hale gelir; test edilemez | Repository arayüzüne geç; Domain'e sadece `System.*` namespace'leri girmeli |
| Application'dan Infrastructure'a Doğrudan Erişim | Bağımlılık yönü bozulur; Infrastructure değiştiğinde Application kırılır | Her zaman arayüzler (`IOrderRepository`) üzerinden erişim |
| Anemic Domain Model | Entity'ler sadece property; tüm iş mantığı Service'te | Domain metodlarını entity'e taşı (`order.Cancel()`, `table.UpdateStatus()`) |
| Fat Application Handler | Handler 500+ satır, birden fazla sorumluluk | Domain servislerine veya özel sınıflara delege et |
| Aynı DTO'yu Tüm Katmanlarda Kullanmak | Katmanlar arası sıkı bağlılık; bir katman değişince diğerleri kırılır | Her katmanın kendi modeli: Domain Entity, Application DTO, API Contract |
| Repository İçinde Iş Mantığı | Veri erişim katmanına iş kuralları sızar; test ve bakım zorlaşır | İş mantığını Domain entity veya Application Handler'a taşı |
| Validation'ı Controller'da Yapmak | Validation mantığı dağınık; her katmanda tekrar eder | Pipeline behavior ile merkezi validation (ValidationBehavior) |

---

## 9. Örnek Proje Referansı: C# Onion Architecture

Projemizde C# ile Onion Architecture uygulamasını inceleyebilirsiniz:

**Repo**: [DTVegaArchChapter/ArchitecturePatterns - Onion](https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Onion)

### Proje Özellikleri

- **.NET 10** ile geliştirilmiş restoran sipariş ve mutfak yönetim sistemi
- **Mediator** ile CQRS tabanlı pipeline yapısı
- **FluentValidation** ile validation behavior
- **ASP.NET Core Web API** controller'lar
- **Entity Framework Core** (In-Memory) ile repository pattern
- **Command/Query** ayrımı (CQRS)
- **Result Pattern** ile tutarlı hata yönetimi

### Örnek Command Handler (Gerçek Proje'den)

```csharp
// Application/Orders/Commands/CreateOrder/CreateOrderCommandHandler.cs
public class CreateOrderCommandHandler(
    IOrderRepository orderRepository,
    ITableRepository tableRepository,
    IMenuItemRepository menuItemRepository,
    IUnitOfWork unitOfWork)
    : IRequestHandler<CreateOrderCommand, Result<CreateOrderResponse>>
{
    public async Task<Result<CreateOrderResponse>> Handle(
        CreateOrderCommand request,
        CancellationToken ct)
    {
        // Masa var mı ve uygun mu?
        var table = await tableRepository.GetByIdAsync(request.TableId, ct);
        if (table is null)
            return Result<CreateOrderResponse>.Failure($"Table {request.TableId} not found");

        if (table.Status is TableStatus.Occupied or TableStatus.Reserved)
            return Result<CreateOrderResponse>.Failure($"Table {table.Id} is not available");

        // Menü öğeleri kontrolü
        var menuItemIds = request.Items.Select(i => i.MenuItemId).ToList();
        var menuItems = await menuItemRepository.GetAvailableByIdsAsync(menuItemIds, ct);

        var unavailableIds = menuItemIds
            .Where(id => !menuItems.Select(m => m.Id).Contains(id))
            .ToList();

        if (unavailableIds.Count != 0)
            return Result<CreateOrderResponse>.Failure(
                $"Menu items not available: {string.Join(", ", unavailableIds)}");

        // Sipariş oluştur (Domain entity metodu)
        var order = new Order
        {
            OrderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd-HHmmss}",
            TableId = request.TableId,
            OrderDate = DateTime.UtcNow,
            Status = OrderStatus.Pending,
            Notes = request.Notes
        };

        foreach (var itemRequest in request.Items)
        {
            var menuItem = menuItems.First(m => m.Id == itemRequest.MenuItemId);
            order.AddItem(menuItem, itemRequest.Quantity, itemRequest.SpecialInstructions);
        }

        await orderRepository.AddAsync(order, ct);
        await unitOfWork.SaveChangesAsync(ct);

        return Result<CreateOrderResponse>.Success(
            new CreateOrderResponse(order.Id, order.OrderNumber, order.TableId,
                order.OrderDate, order.Status.ToString(), order.TotalAmount));
    }
}

// Application/Orders/Commands/CreateOrder/CreateOrderCommandValidator.cs
public class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.TableId)
            .GreaterThan(0).WithMessage("Table ID must be greater than 0");

        RuleFor(x => x.Items)
            .NotEmpty().WithMessage("Order must have at least one item");

        RuleFor(x => x.Notes)
            .MaximumLength(500).WithMessage("Order notes cannot exceed 500 characters");

        RuleForEach(x => x.Items).ChildRules(item =>
        {
            item.RuleFor(x => x.MenuItemId)
                .GreaterThan(0).WithMessage("Menu item ID must be greater than 0");
            item.RuleFor(x => x.Quantity)
                .GreaterThan(0).WithMessage("Quantity must be greater than 0");
            item.RuleFor(x => x.SpecialInstructions)
                .MaximumLength(250).WithMessage("Special instructions cannot exceed 250 characters");
        });
    }
}
```

---

## 10. Onion Architecture vs Diğer Mimariler

| Özellik | Onion Architecture | Vertical Slice | Clean Architecture |
|---------|-------------------|----------------|-------------------|
| Organizasyon | Katman bazlı | Feature bazlı | Katman bazlı |
| Bağımlılık Yönü | İçe doğru | Bağımsız slice | İçe doğru |
| Yeni Feature | Tüm katmanlara dokunur | Tek klasör | Tüm katmanlara dokunur |
| Test Edilebilirlik | Çok yüksek | Yüksek | Çok yüksek |
| Öğrenme Eğrisi | Orta-Yüksek | Düşük | Yüksek |
| Boilerplate | Yüksek | Minimum | Yüksek |
| Domain İzolasyonu | Güçlü | Orta | Güçlü |
| Değişim İzolasyonu | Orta (katman bazlı) | Yüksek (feature bazlı) | Orta (katman bazlı) |

### Onion vs Clean Architecture Farkı

Onion Architecture ile Clean Architecture çok benzerdir; temel fark terminoloji ve katman sayısındadır:

| Onion Architecture | Clean Architecture |
|--------------------|-------------------|
| Domain Layer | Entities |
| Application Layer | Use Cases |
| Infrastructure Layer | Interface Adapters + Frameworks |
| Presentation Layer | Frameworks & Drivers |

Her ikisinde de bağımlılıklar içe doğru akar; Clean Architecture daha fazla katman ayrımı (Interface Adapters gibi) önerir.

---

## 11. Yeni Feature Ekleme Süreç Rehberi

Onion Architecture'da yeni bir özellik eklemek için şu adımlar izlenir:

1. **Domain Entity Oluştur** (gerekiyorsa): `Domain/Entities/` altında yeni entity ve enum.
2. **Repository Arayüzünü Tanımla**: `Domain/Repositories/` altında `INewFeatureRepository.cs`.
3. **Application Command/Query Oluştur**: `Application/<Feature>/Commands|Queries/<UseCase>/` altında Command/Query ve Handler.
4. **DTO Ekle**: `Application/Common/DTOs/` altında response DTO.
5. **Validator Yaz**: Handler ile aynı klasörde `<UseCase>CommandValidator.cs`.
6. **Infrastructure Implementasyonu**: `Infrastructure/Repositories/` altında repository sınıfı.
7. **DI Kaydı**: `Program.cs` veya extension method ile yeni repository'yi arayüzüne kaydet.
8. **Controller/Endpoint Ekle**: `Api/Controllers/` altında action; `Api/Contracts/` altında HTTP request modeli.

---

## 12. Domain-Driven Design ile Birlikte Kullanım

Onion Architecture, DDD ile mükemmel uyumludur; Domain katmanı DDD yapı taşlarını barındırır:

```csharp
// Domain/Common/BaseEntity.cs
public abstract class BaseEntity
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}

// Domain/Entities/Order.cs (Aggregate Root)
public class Order : BaseEntity
{
    private readonly List<OrderItem> _orderItems = new();
    public IReadOnlyCollection<OrderItem> OrderItems => _orderItems.AsReadOnly();

    public string OrderNumber { get; private set; } = default!;
    public int TableId { get; set; }
    public OrderStatus Status { get; private set; } = OrderStatus.Pending;
    public decimal TotalAmount => _orderItems.Sum(i => i.Price * i.Quantity);

    // Domain metodu - iş kuralı entity içinde
    public Result AddItem(MenuItem menuItem, int quantity, string? instructions = null)
    {
        if (!menuItem.IsAvailable)
            return Result.Failure($"Menu item '{menuItem.Name}' is not available");

        if (Status != OrderStatus.Pending)
            return Result.Failure("Cannot add items to an order that is not pending");

        _orderItems.Add(new OrderItem
        {
            MenuItemId = menuItem.Id,
            Quantity = quantity,
            Price = menuItem.Price,
            SpecialInstructions = instructions
        });

        return Result.Success();
    }

    public Result UpdateStatus(OrderStatus newStatus)
    {
        // Domain invariant: geçerli durum geçişleri kontrol edilir
        var validTransitions = new Dictionary<OrderStatus, OrderStatus[]>
        {
            [OrderStatus.Pending] = [OrderStatus.Preparing, OrderStatus.Cancelled],
            [OrderStatus.Preparing] = [OrderStatus.Ready],
            [OrderStatus.Ready] = [OrderStatus.Delivered]
        };

        if (!validTransitions.TryGetValue(Status, out var allowed) || !allowed.Contains(newStatus))
            return Result.Failure($"Invalid status transition from {Status} to {newStatus}");

        Status = newStatus;
        UpdatedAt = DateTime.UtcNow;
        return Result.Success();
    }
}
```

---

## 13. Sık Sorulan Sorular (FAQ)

**Onion Architecture ile Layered Architecture arasındaki temel fark nedir?**
Geleneksel N-katmanlı mimaride Domain genellikle Infrastructure'a (veritabanına) bağımlıdır. Onion Architecture'da bağımlılık yönü tersine çevrilir: Infrastructure, Domain'e bağımlıdır; Domain hiçbir şeye bağımlı değildir.

**Onion ile Clean Architecture aynı şey mi?**
Çok benzerler; her ikisi de bağımlılıkların içe doğru aktığı katmanlı yapıyı savunur. Terminoloji ve katman ayrıntıları biraz farklıdır; Clean Architecture daha kapsamlı kurallar ve katman isimleri önerir.

**Repository arayüzleri neden Domain'de, Application'da değil?**
Domain'in veri erişim ihtiyacını beyan etmesi gerekir; Application bu ihtiyacı karşılar. Ayrıca Domain katmanı arayüzleri barındırdığında Application ve Infrastructure katmanları doğrudan Domain'e bağımlı olur, döngüsel bağımlılık oluşmaz.

**Mediator kullanmak zorunlu mu?**
Hayır; ancak Mediator pipeline (validation, logging, transaction) otomasyonu sağlar ve CQRS uygulamasını kolaylaştırır. Alternatif olarak Application servis sınıfları doğrudan çağrılabilir, ancak cross-cutting concern yönetimi daha zahmetli olur.

**Infrastructure katmanı Application'a mı, Domain'e mi bağımlı?**
Her ikisine de. Infrastructure, Domain repository arayüzlerini implemente eder (Domain'e bağımlı) ve Application'da tanımlı DTO'ları veya arayüzleri kullanabilir (Application'a bağımlı).

**DTO'lar hangi katmanda tanımlanmalı?**
Application katmanında tanımlanmaları önerilir. Presentation katmanının kendi request/response modelleri (Contracts) olabilir; Application DTO'larına eşleme Controller veya Mapping Profile aracılığıyla yapılır.

**DDD ile birlikte kullanırken Domain Events nasıl eklenir?**
Entity'lerde domain event listesi tutulur; Handler içinde `unitOfWork.SaveChangesAsync()` sonrası event'ler publish edilir. Event handler'lar Application katmanında veya ayrı bir subscription katmanında yer alır.

---

## 14. Özet Yol Haritası (Uygulama Adımları)

1. **Projeyi Başlat**: `Domain`, `Application`, `Infrastructure`, `Api` olmak üzere 4 proje oluştur; bağımlılık referanslarını ayarla.
2. **Domain Yaz**: Entity'ler, enum'lar, repository arayüzleri. Dışa bağımlılık yok.
3. **Application Kur**: Mediator kütüphanesini ekle; Command/Query, Handler, DTO, Validator oluştur.
4. **Pipeline Behavior Ekle**: ValidationBehavior, LoggingBehavior, TransactionBehavior.
5. **Infrastructure İmplemente Et**: EF Core DbContext, repository implementasyonları, Unit of Work.
6. **Presentation Oluştur**: Controller veya Minimal API endpoint, HTTP contract modelleri, DI kayıtları.
7. **Test Yaz**: Domain entity testleri (saf birim test), Application handler testleri (mock repository), Integration testleri (gerçek pipeline).
8. **Refactor**: God handler'ları böl; Domain metotlarını entity'e taşı; tekrar eden kodu Application Common'a çıkar.

---

## 15. Kaynaklar

- Jeffrey Palermo – Onion Architecture: [jeffreypalermo.com](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/)
- Mediator (Source Generator Based): [github.com/martinothamar/Mediator](https://github.com/martinothamar/Mediator)
- CQRS Pattern – Martin Fowler: [martinfowler.com/bliki/CQRS.html](https://martinfowler.com/bliki/CQRS.html)
- FluentValidation: [fluentvalidation.net](https://fluentvalidation.net/)
- Örnek Proje: [DTVegaArchChapter/ArchitecturePatterns - Onion](https://github.com/DTVegaArchChapter/ArchitecturePatterns/tree/main/Examples/Onion)

---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {"@type": "Question", "name": "Onion Architecture nedir?", "acceptedAnswer": {"@type": "Answer", "text": "Uygulamayı eş merkezli katmanlar halinde organize eden, merkezdeki Domain katmanının hiçbir dışa bağımlılığı olmadığı ve bağımlılıkların her zaman içe doğru aktığı bir mimari yaklaşımdır."}},
    {"@type": "Question", "name": "Onion Architecture ile Layered Architecture farkı nedir?", "acceptedAnswer": {"@type": "Answer", "text": "Geleneksel N-katmanlı mimaride Domain genellikle Infrastructure'a bağımlıdır. Onion Architecture'da bağımlılık yönü tersine döner: Infrastructure Domain'e bağımlıdır; Domain hiçbir şeye bağımlı değildir."}},
    {"@type": "Question", "name": "Repository arayüzleri neden Domain katmanında tanımlanır?", "acceptedAnswer": {"@type": "Answer", "text": "Domain katmanının veri erişim ihtiyacını beyan etmesi gerekir. Arayüzler Domain'de olduğunda Infrastructure, Domain'e bağımlı olur ve Dependency Inversion sağlanır; Domain temiz ve test edilebilir kalır."}},
    {"@type": "Question", "name": "Ne zaman kullanmalı?", "acceptedAnswer": {"@type": "Answer", "text": "Orta-büyük ölçekli, uzun ömürlü uygulamalar, domain karmaşıklığı yüksek sistemler, teknoloji bağımsızlığının kritik olduğu projeler ve yüksek test coverage hedefi olan ekipler için idealdir. Basit CRUD uygulamalarında gereksiz karmaşıklık yaratabilir."}},
    {"@type": "Question", "name": "Onion ile Clean Architecture aynı mı?", "acceptedAnswer": {"@type": "Answer", "text": "Çok benzerler; her ikisi de bağımlılıkların içe doğru aktığı katmanlı yapıyı savunur. Terminoloji ve katman ayrıntıları biraz farklıdır. Clean Architecture daha kapsamlı kurallar ve ek katman isimleri (Interface Adapters, Frameworks & Drivers) önerir."}}
  ],
  "inLanguage": "tr-TR"
}
</script>
<!-- markdownlint-enable MD033 -->
