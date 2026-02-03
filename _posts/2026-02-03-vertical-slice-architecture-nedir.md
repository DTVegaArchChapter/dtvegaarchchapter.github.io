---
layout: post
title: "Vertical Slice Architecture Nedir? Kullanım Senaryoları ve Pratik Rehber"
categories: [mimari, vertical slice architecture]
tags: [vertical slice architecture, feature based architecture, cqrs, mediator]
lang: tr
author: QuickOrBeDead
excerpt: Vertical Slice Architecture nedir, nasıl uygulanır, hangi problemleri çözer? Pratik örnekler, klasör yapısı, karar kriterleri, anti-pattern'ler ve gerçek dünya senaryolarıyla detaylı rehber.
date: 2026-02-03
last_modified_at: 2026-02-03 10:00:00 +0300
---

## TL;DR

- Vertical Slice Architecture (VSA), kodu işlevsel özelliklere bölerek, her özelliği (feature/use case) bağımsız, dikey bir dilim halinde organize eder.
- Çok katmanlı mimaride (Controller → Service → Repository → DB) bir değişiklik birçok farklı katmanı etkilerken, Vertical Slice Architecture'da değişiklik tek bir dilimle sınırlı kalır.
- Mediator, CQRS pattern'i ve handler tabanlı pipeline ile her özellik (feature/use case) izole edilir; cross-cutting concern'ler (validation, logging, caching) behavior olarak eklenir.
- Kullanılması gereken yerler: Orta-büyük ölçekli uygulamalar, sık değişen gereksinimler ve ekipleri büyüyen projeler.
- Kullanılmaması gereken yerler: Çok basit CRUD uygulamaları (3-5 tablo), kısa ömürlü prototip/MVP, domain karmaşıklığı olmayan sistemler.

---

## 1. Vertical Slice Architecture Nedir?

Vertical Slice Architecture, yazılım sistemini **yatay katmanlar** (horizontal layers) yerine **dikey dilimler** (vertical slices) halinde organize eden bir mimari yaklaşımdır. Her dilim, tek bir kullanıcı senaryosunu (use case) veya özelliği (feature) uçtan uca kapsayan bağımsız bir modül oluşturur.

### Temel Prensipler

- Her use case kendi dosya grubuna izole edilir (Command/Query, Handler, Validator, Mapping, DTO).
- Katmanlar arası paylaşım yerine, her dilim kendi ihtiyacını karşılar. Ortak kod gerçekten gerektiğinde oluşturulur.
- Klasör yapısı teknik katmanlara (Controllers, Services, Repositories) değil, iş özelliklerine (feature) göre düzenlenir.
- Mediator patternini uygulayan kütüphanelerle request/response pipeline'ı üzerinden handler'lar çalışır.

### Motivasyon: Hangi Problemi Çözer?

Geleneksel katmanlı mimaride yaygın sorunlar:

1. **Değişim Serpilmesi (Shotgun Surgery)**: Yeni bir özellik eklemek veya mevcut birini değiştirmek için Controller, Service, Repository, DTO, Mapping ve Config dosyalarında değişiklik yapmak gerekir.
2. **God Service Sınıfları**: `OrderService.cs` dosyası 3000+ satıra ulaşır, bakımı zorlaşır.
3. **Sınır Belirsizliği**: Hangi service hangi repository'yi kullanır? Bağımlılık ağacı karmaşıklaşır.
4. **Onboarding Zorluğu**: Yeni geliştirici "siparişi iptal et" özelliğini anlamak için 8 farklı klasör dolaşır.
5. **Test Kapsamı**: Büyük service sınıfları unit test'i zorlaştırır; mock sayısı artar.

Vertical Slice Architecture Çözümü:

- Her use case bir klasör; değişim izole.
- Handler'lar küçük ve odaklı; test kolay.
- Yeni geliştirici bir özelliği tek klasörde görebilir.

### Avantajlar

- **Değişim İzolasyonu**: Bir özellik değiştiğinde sadece o slice'ın dosyaları güncellenir; diğer özellikler etkilenmez. Merge conflict riski minimize edilir.
- **Yüksek Cohesion (Bağlılık)**: İlgili tüm kod (validation, mapping, business logic, tests) bir arada; özellik anlaşılması ve bakımı kolay.
- **Düşük Coupling (Bağımlılık)**: Slice'lar birbirinden bağımsız; bir slice'taki değişiklik diğerlerini kırmaz.
- **Test Edilebilirlik**: Handler'lar küçük ve odaklı olduğu için unit test yazmak kolay; mock sayısı az.
- **Ekip Paralelliği**: Farklı geliştiriciler aynı anda farklı slice'larda çalışabilir; kod çakışması minimumda.
- **Onboarding Hızı**: Yeni geliştirici bir özelliği anlamak için tek klasöre bakması yeterli; kod gezinme basit.
- **CQRS Uyumu**: Command/Query ayrımı uygulanır; okuma ve yazma optimizasyonları bağımsız yapılabilir.
- **Pipeline Esnekliği**: Mediator patternini kullanan kütüphanelerle cross-cutting concern'ler (validation, logging, caching) behavior olarak merkezi bir şekilde eklenir.
- **Kod Keşfi (Discoverability)**: Klasör yapısı iş özelliklerine göre olduğu için hangi kod neyi yaptığı hızlı bulunur.

### Dezavantajlar

- **Başlangıç Karmaşıklığı**: Basit CRUD uygulamalarında gereksiz karmaşıklık yaratabilir; 3-5 tablolu sistemlerde aşırı mühendislik (over-engineering) riski.
- **Kod Tekrarı Riski**: Slice'lar arası ortak kod tekrar edilebilir; shared kernel veya common klasörü disiplinle yönetilmezse duplication artar.
- **Öğrenme Eğrisi**: Ekip için yeni bir yaklaşımsa adapte olma süresi gerekir; Mediator, CQRS, pipeline behavior kavramlarını öğrenme gereksinimi.
- **Fazla Dosya**: Her slice için ayrı dosyalar (Command, Handler, Validator, DTO, Tests) oluştuğundan dosya sayısı artar; IDE'de gezinme biraz zorlaşabilir.
- **Cross-Cutting Concern Yönetimi**: Validation, logging, authorization gibi ortak işlemler behavior olarak eklenmediyse her slice'ta tekrar edilebilir.
- **Aşırı Granülerlik**: Çok küçük use case'ler için slice oluşturmak gereksiz yönetsel yük yaratabilir.
- **Ortak Kod Kararları**: Hangi kodun shared, hangisinin slice içinde kalacağına karar vermek zor olabilir; yanlış kararlar coupling artırır veya duplication yaratır.

### Ne Zaman Kullanmalı?

- Orta-büyük ölçekli uygulamalar (10+ özellik/use case)
- Sık değişim gerektiren sistemler (agile/iterative development)
- Ekip büyüdükçe paralel çalışma ihtiyacı olan projeler
- Domain karmaşıklığı orta/yüksek seviyede olan projeler

### Ne Zaman Kullanmamalı?

- Çok basit CRUD uygulamaları (3-5 tablo, minimal business logic)
- Kısa ömürlü prototip veya MVP (Minimum Viable Product)
- Tek geliştirici veya çok küçük ekip (2-3 kişi) ve basit gereksinimler
- Sadece raporlama/ETL ağırlıklı sistemler (domain logic yok)
- Legacy sistemde küçük iyileştirme (tam yeniden yapılanma planı yoksa)

---

## 2. Yatay Katmanlı vs Vertical Slice Karşılaştırması

### Yatay Katmanlı Mimari (Traditional Layered)

```text
src/
  Controllers/
    OrdersController.cs (150 satır: Create, Update, Delete, Get, List...)
  Services/
    OrderService.cs (800 satır: tüm order business logic)
  Repositories/
    OrderRepository.cs
  DTOs/
    CreateOrderDto.cs
    UpdateOrderDto.cs
    OrderResponseDto.cs
  Mappings/
    OrderMappingProfile.cs
```

**Değişiklik Senaryosu**: "Sipariş iptal et" özelliğini ekle.

- `OrdersController.cs`: Yeni endpoint ekle.
- `OrderService.cs`: `CancelOrder` metodu ekle.
- `OrderRepository.cs`: Gerekirse yeni query.
- `DTOs/`: `CancelOrderDto.cs` ekle.
- `Mappings/`: Mapping güncelle.

→ **5 farklı dosya, 3 farklı klasörde değişiklik**; merge conflict riski yüksek, kod review zor.

### Vertical Slice Mimari

```text
src/
  Features/
    Orders/
      Create/
        CreateOrderCommand.cs
        CreateOrderHandler.cs
        CreateOrderValidator.cs
        Dto.cs
        Tests.cs
      Cancel/
        CancelOrderCommand.cs
        CancelOrderHandler.cs
        CancelOrderValidator.cs
        Tests.cs
      GetById/
        GetOrderQuery.cs
        GetOrderHandler.cs
        Dto.cs
```

**Değişiklik Senaryosu**: "Sipariş iptal et" özelliğini ekle.

- `Features/Orders/Cancel/` klasörü altında tüm elemanlar mevcut (Command, Handler, Validator, Tests).

→ **Tek klasör, izole değişim**; diğer özelliklere dokunma riski yok.

---

## 3. Vertical Slice Elemanları

Her slice tipik olarak şu dosyaları içerir:

### Command/Query (Request)

```csharp
// Features/Orders/Cancel/CancelOrderCommand.cs
public sealed record CancelOrderCommand(int OrderId, string Reason) : ICommand<Result>;
```

### Handler (Business Logic)

```csharp
// Features/Orders/Cancel/CancelOrderHandler.cs
public sealed class CancelOrderHandler(IOrderRepository repo, IUnitOfWork uow)
    : ICommandHandler<CancelOrderCommand, Result>
{
    public async Task<Result> Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await repo.GetByIdAsync(cmd.OrderId, ct);
        if (order is null) return Result.NotFound();

        var cancelResult = order.Cancel(cmd.Reason); // Domain method
        if (!cancelResult.IsSuccess) return cancelResult;

        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}
```

### Validator (FluentValidation)

```csharp
// Features/Orders/Cancel/CancelOrderValidator.cs
public sealed class CancelOrderValidator : AbstractValidator<CancelOrderCommand>
{
    public CancelOrderValidator()
    {
        RuleFor(x => x.OrderId).GreaterThan(0);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(500);
    }
}
```

### DTO (Response)

```csharp
// Features/Orders/Cancel/CancelOrderResponse.cs
public sealed record CancelOrderResponse(int OrderId, string Status);
```

### Tests

```csharp
// Features/Orders/Cancel/CancelOrderTests.cs
public class CancelOrderHandlerTests
{
    [Fact]
    public async Task Handle_ValidOrder_ShouldCancelSuccessfully()
    {
        // Arrange
        var order = Order.Create(...);
        var repo = Substitute.For<IOrderRepository>();
        repo.GetByIdAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(order);
        var handler = new CancelOrderHandler(repo, ...);

        // Act
        var result = await handler.Handle(new CancelOrderCommand(1, "Müşteri talebi"), CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
    }
}
```

---

## 4. Mediator ve Pipeline Behaviors

Vertical Slice Architecture genellikle **Mediator** patternini uygulayan kütüphaneler ile uygulanır. Mediator, request/response tabanlı bir pipeline sağlar ve cross-cutting concern'leri (validation, logging, caching, transaction) behavior olarak ekler.

### MediatR Request/Response Flow

```text
Endpoint
  ↓ (Command/Query gönderir)
MediatR Pipeline
  ↓ (Behavior 1: Validation)
  ↓ (Behavior 2: Logging)
  ↓ (Behavior 3: Transaction)
  ↓ Handler (Business Logic)
  ↓ (Response)
Endpoint (Result döner)
```

### Örnek Validation Behavior

```csharp
public sealed class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
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

### Logging Behavior Örneği

```csharp
public sealed class LoggingBehavior<TRequest, TResponse>(ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var requestName = typeof(TRequest).Name;
        logger.LogInformation("Handling {RequestName}", requestName);

        var sw = Stopwatch.StartNew();
        var response = await next();
        sw.Stop();

        logger.LogInformation("Handled {RequestName} in {ElapsedMs}ms", requestName, sw.ElapsedMilliseconds);
        return response;
    }
}
```

---

## 5. Klasör Yapısı Örnekleri

### 5.1 Minimal Vertical Slice Architecture (Küçük-Orta Uygulamalar)

```text
src/
  Features/
    Orders/
      Create/
        CreateOrderCommand.cs
        CreateOrderHandler.cs
        CreateOrderValidator.cs
        CreateOrderDto.cs
      Cancel/
        CancelOrderCommand.cs
        CancelOrderHandler.cs
        CancelOrderValidator.cs
      GetById/
        GetOrderQuery.cs
        GetOrderHandler.cs
        OrderDto.cs
    Products/
      Add/
        ...
      Update/
        ...
```

### 5.2 Hibrit (DDD + Vertical Slice)

```text
src/
  Domain/
    Orders/
      Order.cs (Aggregate Root)
      OrderLine.cs (Entity)
      OrderStatus.cs (Enum/Value Object)
    Products/
      Product.cs
  Application/
    Abstractions/
      IUnitOfWork.cs
      IRepository.cs
    Orders/
      Create/
        CreateOrderCommand.cs
        CreateOrderHandler.cs
        CreateOrderValidator.cs
      Cancel/
        CancelOrderCommand.cs
        CancelOrderHandler.cs
      Queries/
        GetOrderById/
          GetOrderByIdQuery.cs
          GetOrderByIdHandler.cs
  Infrastructure/
    Persistence/
      EfOrderRepository.cs
      AppDbContext.cs
  Web/
    Endpoints/
      Orders/
        CreateOrderEndpoint.cs (Minimal API)
        CancelOrderEndpoint.cs
```

Bu yapıda:

- **Domain**: İş kuralları ve aggregate'ler (paylaşımlı, yeniden kullanılabilir).
- **Application**: Use case'ler vertical slice olarak organize.
- **Infrastructure**: Port implementasyonları.
- **Web**: Endpoint'ler (Controller veya Minimal API).

---

## 6. CQRS ile Entegrasyon

Vertical Slice Architecture doğal olarak CQRS (Command Query Responsibility Segregation) ile uyumludur:

- **Command Slice**: Durum değiştirir (Create, Update, Delete, Cancel).
- **Query Slice**: Sadece okuma (GetById, List, Search).

### CQRS Avantajları Vertical Slice Architecture ile

- **Ayrı Optimizasyon**: Query slice'ları DTO projection ile performans kazanır; Command slice'ları domain model üzerinden invariant uygular.
- **Farklı Veri Kaynakları**: Command → Write DB; Query → Read DB (veya cache, Elasticsearch).
- **Bağımsız Ölçekleme**: Query yoğunluğu fazlaysa query handler'lar ayrı instance'da çalışabilir.

### Örnek Query Slice (DTO Projection)

```csharp
// Features/Orders/Queries/GetOrderById/GetOrderByIdQuery.cs
public sealed record GetOrderByIdQuery(int OrderId) : IQuery<OrderDto>;

// GetOrderByIdHandler.cs
public sealed class GetOrderByIdHandler(AppDbContext db)
    : IQueryHandler<GetOrderByIdQuery, OrderDto>
{
    public async Task<OrderDto> Handle(GetOrderByIdQuery query, CancellationToken ct)
    {
        return await db.Orders
            .Where(o => o.Id == query.OrderId)
            .Select(o => new OrderDto(o.Id, o.CustomerName, o.Total, o.Status))
            .FirstOrDefaultAsync(ct);
    }
}
```

---

## 7. Karar Matrisi: Ne Zaman Kullanmalı/Kullanmamalı?

| Senaryo | VSA Uygun mu? | Neden? |
| --------- | --------------- | -------- |
| Startup MVP (3-5 tablo, basit CRUD) | ❌ Hayır | Gereksiz karmaşıklık; klasik katmanlı yeterli |
| Orta ölçek, büyüme beklentisi | ✅ Evet | Modülerlik ve test edilebilirlik erken kazanılır |
| Yüksek değişim hızı, sık özellik ekleme | ✅ Evet | Değişim izolasyonu kritik |
| Mikroservis geçiş planı | ✅ Evet | Slice'lar doğrudan mikroservise taşınabilir |
| Legacy modülerleştirme | ✅ Evet | Adım adım slice'lara bölünerek iyileştirilir |
| Basit raporlama/ETL sistemi | ❌ Hayır | Domain karmaşıklığı yok; script/pipeline yeterli |
| Çok karmaşık domain (DDD aggregate yoğun) | ✅ Evet (Hibrit) | Domain katmanı + VSA kombinasyonu ideal |
| Ekip büyümesi ve paralelizasyon | ✅ Evet | Her ekip üyesi farklı slice'ta çalışır, conflict azalır |

---

## 8. Anti-Pattern ve Kırmızı Bayraklar

| Anti-Pattern | Sonuç | Çözüm |
|--------------|-------|-------|
| God Handler | Handler 500+ satır, birden fazla sorumluluk | Handler'ı küçük alt handler'lara veya domain servislere böl |
| Slice İçinde Duplication | Aynı mapping/validation kodu her slice'ta tekrar | Shared kernel (Value Object, Policy, Mapping Profile) çıkar |
| Cross-Slice Bağımlılık | Slice A, Slice B'nin handler'ını çağırır | Domain event veya integration event kullan; handler'lar birbirini çağırmamalı |
| Infrastructure Sızıntısı | Handler içinde `new SqlConnection()` | Port/adapter soyutlama; DI ile inject et |
| Test Eksikliği | Handler test edilmemiş | Her slice için handler test zorunlu; coverage hedefi %80+ |
| Aşırı Soyutlama | Her şey için interface, generic katmanlar | Gerçekten değişim beklenen noktalar için soyutla; YAGNI prensibi |

---

## 9. Örnek Proje Referansı: C# Vertical Slice Architecture

Projemizde C# ile Vertical Slice Architecture uygulamasını görebilirsiniz:

**Repo**: [DTVegaArchChapter/Architecture - VerticalSlice](https://github.com/DTVegaArchChapter/Architecture/tree/main/ArchitecturePatterns/Examples/VerticalSlice)

### Proje Özellikleri

- **.NET 9** ile geliştirilmiş örnek uygulama
- **MediatR** ile pipeline tabanlı handler yapısı
- **FluentValidation** ile validation behavior
- **Minimal API** endpoint'leri
- **Entity Framework Core** ile repository pattern
- **Command/Query** ayrımı (CQRS)
- **Unit Tests** ile test coverage

### Klasör Yapısı (Gerçek Proje)

```text
src/
  RestaurantManagement.Api/
    Features/
      Tables/
        GetAllTables/
          GetAllTablesEndpoint.cs
          GetAllTablesHandler.cs
          GetAllTablesResponse.cs
        UpdateTableStatus/
          UpdateTableStatusEndpoint.cs
          UpdateTableStatusHandler.cs
          UpdateTableStatusRequest.cs
          UpdateTableStatusResponse.cs
          UpdateTableStatusValidator.cs
      MenuItems/
        GetMenuItems/
          GetMenuItemsEndpoint.cs
          GetMenuItemsHandler.cs
          GetMenuItemsResponse.cs
          GetMenuItemsValidator.cs
      Orders/
        CreateOrder/
          CreateOrderEndpoint.cs
          CreateOrderHandler.cs
          CreateOrderRequest.cs
          CreateOrderResponse.cs
          CreateOrderValidator.cs
        UpdateOrderStatus/
          UpdateOrderStatusEndpoint.cs
          UpdateOrderStatusHandler.cs
          UpdateOrderStatusRequest.cs
          UpdateOrderStatusResponse.cs
          UpdateOrderStatusValidator.cs
        GetKitchenOrders/
          GetKitchenOrdersEndpoint.cs
          GetKitchenOrdersHandler.cs
          GetKitchenOrdersResponse.cs
    Entities/
      Table.cs
      TableStatus.cs
      MenuItem.cs
      Order.cs
      OrderItem.cs
      OrderStatus.cs
    Common/
      Result.cs
      ResultHelper.cs
      Behaviors/
        ValidationBehavior.cs
    Data/
      RestaurantDbContext.cs
    Program.cs
  test/
    RestaurantManagement.Api.FunctionalTests/
      Features/
        Orders/
          CreateOrderEndpointTests.cs
          UpdateOrderStatusEndpointTests.cs
          GetKitchenOrdersEndpointTests.cs
        Tables/
          GetAllTablesEndpointTests.cs
          UpdateTableStatusEndpointTests.cs
```

### Örnek Command Handler (Gerçek Kod)

```csharp
// Features/Orders/CreateOrder/CreateOrderRequest.cs
public record CreateOrderRequest(int TableId, List<OrderItemRequest> Items, string? Notes);
public record OrderItemRequest(int MenuItemId, int Quantity, string? SpecialInstructions);

// Features/Orders/CreateOrder/CreateOrderCommand.cs
public sealed record CreateOrderCommand(int TableId, List<OrderItemRequest> Items, string? Notes) 
    : IRequest<Result<CreateOrderResponse>>;

// Features/Orders/CreateOrder/CreateOrderHandler.cs
public sealed class CreateOrderHandler(RestaurantDbContext context) 
    : IRequestHandler<CreateOrderCommand, Result<CreateOrderResponse>>
{
    public async ValueTask<Result<CreateOrderResponse>> Handle(
        CreateOrderCommand request, 
        CancellationToken cancellationToken)
    {
        // Validate table exists and is available
        var table = await context.Tables.FindAsync([request.TableId], cancellationToken);
        if (table == null)
            return Result<CreateOrderResponse>.NotFound($"Table {request.TableId} not found");

        if (table.Status is TableStatus.Occupied or TableStatus.Reserved)
            return Result<CreateOrderResponse>.Failure($"Table {table.Id} is not available");

        // Get and validate menu items
        var menuItemIds = request.Items.Select(i => i.MenuItemId).ToList();
        var menuItems = await context.MenuItems
            .Where(m => menuItemIds.Contains(m.Id) && m.IsAvailable)
            .ToListAsync(cancellationToken);

        var unavailableIds = menuItemIds.Where(id => !menuItems.Select(m => m.Id).Contains(id)).ToList();
        if (unavailableIds.Count != 0)
            return Result<CreateOrderResponse>.Failure(
                $"Menu items not available: {string.Join(", ", unavailableIds)}");

        // Create order items
        var orderItems = request.Items.Select(itemRequest =>
        {
            var menuItem = menuItems.First(m => m.Id == itemRequest.MenuItemId);
            return new OrderItem
            {
                MenuItemId = itemRequest.MenuItemId,
                Quantity = itemRequest.Quantity,
                Price = menuItem.Price,
                SpecialInstructions = itemRequest.SpecialInstructions
            };
        }).ToList();

        // Create order
        var order = new Order
        {
            OrderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd-HHmmss}",
            TableId = request.TableId,
            OrderDate = DateTime.UtcNow,
            Status = OrderStatus.Pending,
            Notes = request.Notes,
            TotalAmount = orderItems.Sum(i => i.Price * i.Quantity),
            OrderItems = orderItems
        };

        context.Orders.Add(order);
        await context.SaveChangesAsync(cancellationToken);

        return Result<CreateOrderResponse>.Success(new CreateOrderResponse(
            order.Id,
            order.OrderNumber,
            order.TableId,
            order.OrderDate,
            order.Status.ToString(),
            order.TotalAmount,
            orderItems.Select(oi => new OrderItemDto(
                oi.Id,
                menuItems.First(m => m.Id == oi.MenuItemId).Name,
                oi.Quantity,
                oi.Price,
                oi.SpecialInstructions)).ToList()));
    }
}

// Features/Orders/CreateOrder/CreateOrderValidator.cs
public class CreateOrderValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderValidator()
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

// Features/Orders/CreateOrder/CreateOrderEndpoint.cs
public static class CreateOrderEndpoint
{
    public static void MapCreateOrder(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/orders", async (
            IMediator mediator,
            CreateOrderRequest request) =>
        {
            var command = new CreateOrderCommand(request.TableId, request.Items, request.Notes);
            var result = await mediator.Send(command);
            return result.ToApiResult(data => Results.Created($"/api/orders/{data?.Id}", data));
        })
        .WithName("CreateOrder")
        .WithSummary("Create a new order")
        .WithOpenApi()
        .Accepts<CreateOrderRequest>("application/json")
        .Produces<CreateOrderResponse>(StatusCodes.Status201Created);
    }
}
```

## 10. Domain-Driven Design ile Birlikte Kullanım

Virtual Slice Architecture, DDD ile mükemmel uyumludur:

- **Aggregate**: Domain katmanında tanımlanır; tüm slice'lar tarafından kullanılır.
- **Domain Events**: Aggregate'den çıkar, handler'da publish edilir, başka slice'lar subscribe olur.
- **Bounded Context**: Her context kendi slice'larını içerir; context'ler arası integration event kullanılır.

### Örnek: Order Aggregate + Virtual Slice Architecture

```csharp
// Domain/Orders/Order.cs (Aggregate Root)
public sealed class Order : Entity, IAggregateRoot
{
    private readonly List<OrderLine> _lines = new();
    public IReadOnlyCollection<OrderLine> Lines => _lines;
    public OrderStatus Status { get; private set; }

    public Result Cancel(string reason)
    {
        if (Status == OrderStatus.Shipped)
            return Result.Error("Kargoya verilmiş sipariş iptal edilemez");

        Status = OrderStatus.Cancelled;
        AddDomainEvent(new OrderCancelledEvent(Id, reason));
        return Result.Success();
    }
}

// Application/Orders/Cancel/CancelOrderHandler.cs
public sealed class CancelOrderHandler(IOrderRepository repo, IUnitOfWork uow, IEventPublisher events)
    : ICommandHandler<CancelOrderCommand, Result>
{
    public async Task<Result> Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await repo.GetByIdAsync(cmd.OrderId, ct);
        if (order is null) return Result.NotFound();

        var cancelResult = order.Cancel(cmd.Reason); // Domain logic
        if (!cancelResult.IsSuccess) return cancelResult;

        await uow.SaveChangesAsync(ct); // Transaction
        await events.PublishAsync(order.DomainEvents, ct); // Event publish
        return Result.Success();
    }
}
```

---

## 11. Mikroservis Geçişi ve Vertical Slice Architecture

Vertical Slice Architecture, monolith'ten mikroservise geçişte kritik avantaj sağlar:

### Adımlar

1. **Slice Bazlı Modülerleştirme**: Mevcut monolith'i slice'lara böl.
2. **Bounded Context Belirleme**: İlişkili slice'ları grupla (örn: Orders, Products, Payments).
3. **Slice Taşıma**: Bir context'teki slice'ları bağımsız servise taşı.
4. **Integration Event**: Servisler arası iletişim için event bus (RabbitMQ, Kafka, Azure Service Bus).

### Örnek: Orders Context → Mikroservis

**Monolith (Öncesi)**:

```text
src/
  Features/
    Orders/
      Create/
      Cancel/
      GetById/
    Products/
      ...
    Payments/
      ...
```

**Mikroservis (Sonrası)**:

```text
OrdersService/
  Features/
    Create/
    Cancel/
    GetById/
  IntegrationEvents/
    OrderCreatedEvent.cs
    OrderCancelledEvent.cs
```

---

## 12. Performans ve Ölçeklenebilirlik

### Performans Optimizasyonları

- **Query Slice DTO Projection**: EF Core `.Select()` ile sadece gerekli alanlar çekilir; N+1 sorgusu engellenir.
- **Caching Behavior**: Sık okunan query'lerde Redis cache katmanı eklenir.
- **Async/Await**: Tüm handler'lar asenkron; I/O bloklamaz.

### Örnek Caching Behavior

```csharp
public sealed class CachingBehavior<TRequest, TResponse>(IDistributedCache cache)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICacheableQuery
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var cacheKey = request.CacheKey;
        var cached = await cache.GetStringAsync(cacheKey, ct);
        if (cached is not null)
            return JsonSerializer.Deserialize<TResponse>(cached);

        var response = await next();
        await cache.SetStringAsync(cacheKey, JsonSerializer.Serialize(response), ct);
        return response;
    }
}
```

---

## 13. Sık Sorulan Sorular (FAQ)

**Vertical Slice ile Layered Architecture arasındaki temel fark nedir?** Layered (yatay): Teknik katmanlara göre organize (Controllers, Services, Repositories). Vertical Slice Architecture (dikey): Use case/feature'a göre organize; her slice uçtan uca bağımsız.

**Mediator kullanmak zorunlu mu?** Hayır; ancak Mediator pipeline (validation, logging, transaction) otomasyonu sağlar. Alternatif: Manuel dispatcher veya endpoint içinde doğrudan handler çağırma (daha az esneklik).

**Slice başına kaç dosya olmalı?** Tipik: Command/Query, Handler, Validator, DTO, Tests (5-7 dosya). Karmaşık senaryoda Mapping Profile, Authorization Policy eklenebilir.

**Domain katmanı nereye gider?** Hibrit yaklaşımda Domain ayrı klasör (paylaşımlı aggregate'ler). Pure Vertical Slice Architecture'da her slice kendi domain logic'ini içerir (küçük projelerde).

**CQRS şart mı?** Hayır; basit CRUD için Command/Query ayrımı yapmadan tek Request/Handler yeterli. CQRS, okuma/yazma optimizasyonu gerektiren senaryolarda değer katar.

**Yeniden kullanılabilir kod nereye konur?** Shared Kernel klasörüne: Value Objects, Common Validators, Utility Extensions. Gerçekten 3+ slice'ta kullanılmadıkça çıkarılmamalı (YAGNI).

**Büyük handler'ları nasıl yönetelim?** Handler → Orchestration; logic → Domain Service/Aggregate. Handler 100+ satır oluyorsa domain metoduna taşı.

---

## 14. Özet Yol Haritası (Uygulama Adımları)

1. **Feature Belirleme**: Use case'leri listele (CreateOrder, CancelOrder, GetOrderById...).
2. **Klasör Oluştur**: `Features/<Domain>/<UseCase>/` yapısı.
3. **Sınıflar Ekle**: Command/Query, Handler, Validator, DTO.
4. **Mediator Kur**: Pipeline behavior'ları ekle (Validation, Logging, Transaction).
5. **Test Yaz**: Handler unit test; integration test endpoint ile.
6. **Refactor**: Ortak kodları Shared Kernel'a taşı; duplication azalt.
7. **Ölçümle**: Slice bazlı metrikler (latency, error rate, throughput).

---

## 15. Sonuç

Vertical Slice Architecture, monolitik uygulamalarda modülerlik, test edilebilirlik ve değişim izolasyonunu artıran güçlü bir mimari pattern'dir. Yatay katmanlı mimarinin "shotgun surgery" problemini çözerken, mikroservis geçişine hazırlık sağlar.

Domain-Driven Design ile birlikte kullanıldığında (hibrit yaklaşım), hem domain kurallarının kapsüllenmesi hem de use case'lerin izolasyonu sağlanır. Mediator, CQRS ve pipeline behavior'ları ile cross-cutting concern'ler otomatikleşir.

Ekip üretkenliğini artırmak, kod kalitesini yükseltmek ve hızlı değişim süreçlerini yönetmek isteyen orta-büyük ölçekli projeler için ideal bir seçimdir. Ancak basit CRUD uygulamalarında gereksiz karmaşıklık yaratabilir; doğru kullanım senaryosunda büyük değer katar.

Örnek projemizi inceleyerek uygulamalı deneyim kazanabilir ve kendi projelerinizde Vertical Slice Architecture'ı uygulayabilirsiniz.

---

## 16. Kaynaklar

- Jimmy Bogard – Vertical Slice Architecture: [jimmybogard.com](https://jimmybogard.com/vertical-slice-architecture/)
- MediatR GitHub: [github.com/jbogard/MediatR](https://github.com/jbogard/MediatR)
- FluentValidation: [fluentvalidation.net](https://fluentvalidation.net/)
- Örnek Proje: [DTVegaArchChapter/Architecture - VerticalSlice](https://github.com/DTVegaArchChapter/Architecture/tree/main/ArchitecturePatterns/Examples/VerticalSlice)

---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {"@type": "Question", "name": "Vertical Slice Architecture nedir?", "acceptedAnswer": {"@type": "Answer", "text": "Her özelliği (feature/use case) bağımsız, dikey bir dilim halinde organize eden, değişim maliyetini azaltan mimari yaklaşımdır."}},
    {"@type": "Question", "name": "Layered Architecture ile farkı nedir?", "acceptedAnswer": {"@type": "Answer", "text": "Layered yatay katmanlara (Controller, Service, Repository) göre organize olurken, Vertical Slice Architecture use case/feature bazında dikey organize olur; değişim tek slice'a izole edilir."}},
    {"@type": "Question", "name": "MediatR zorunlu mu?", "acceptedAnswer": {"@type": "Answer", "text": "Hayır, ancak MediatR pipeline (validation, logging, transaction) otomasyonu sağlar. Manuel dispatcher veya doğrudan handler çağrısı da mümkündür."}},
    {"@type": "Question", "name": "Ne zaman kullanmalı?", "acceptedAnswer": {"@type": "Answer", "text": "Orta-büyük ölçekli uygulamalar, sık değişen gereksinimler, ekip büyümesi, mikroservis geçiş planı olan senaryolarda ideal. Basit CRUD için gereksiz karmaşıklık yaratabilir."}},
    {"@type": "Question", "name": "Domain katmanı nereye gider?", "acceptedAnswer": {"@type": "Answer", "text": "Hibrit yaklaşımda Domain ayrı klasör (paylaşımlı aggregate'ler). Pure Vertical Slice mimarisinde her slice kendi domain logic'ini içerebilir."}}
  ],
  "inLanguage": "tr-TR"
}
</script>
<!-- markdownlint-enable MD033 -->