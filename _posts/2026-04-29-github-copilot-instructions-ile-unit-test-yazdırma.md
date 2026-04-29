---
layout: post
title: "GitHub Copilot Instructions ile Unit Test Yazımı ve Standardizasyon"
categories: [software-engineering, testing]
tags: [copilot, unit-test, dotnet, xunit]
lang: tr
author: Burcu-Ozkan
excerpt: Copilot Instruction kullanarak birim test yazımını hızlandırın, coverage kalitesini artırın ve kurumsal projelerde testlerin tutarlı, tekrar üretilebilir ve doğru mimari prensiplerle oluşturulmasını sağlayan standart talimat
date: 2026-04-29
last_modified_at: 2026-04-29 13:00:00 +0300
---

## TL;DR
- Copilot Instruction, **unit test yazımını hızlandırır**; boilerplate, mock kurulumu ve tekrar eden yapıları otomatik üretir.
- Ekip içinde **herkesin aynı test stilini** üretmesini sağlar; kişisel farklılıkları ortadan kaldırır.
- Talimat seti; **naming, AAA (Arrange–Act–Assert), mocking kuralları, edge case zorunluluğu, test izolasyonu**, hata senaryoları ve coverage beklentilerini içerir.
- Kod üretirken Copilot'un *daima aynı formatta, deterministik ve okunabilir* testler yazmasını garanti eder.
- xUnit örneği referans alınmıştır ancak NUnit/MSTest için kolayca uyarlanabilir.

> Copilot Instruction ile birim testleri artık sıfırdan elle yazılmak zorunda değil ve kişisel tarzlara bağlı değil; hızlı üretim ile kurumsal standardın otomatik uygulandığı deterministik bir süreç hâline gelir.

## GitHub Copilot Custom Instructions Özelliğini Aktif Etme

GitHub Copilot'un repository bazlı özel talimatları kullanabilmesi için Visual Studio'da bu özelliğin aktif edilmesi gerekmektedir.

### Visual Studio'da Ayarların Yapılması

1. **Visual Studio**'yu açın (2022 veya daha yeni versiyonlar önerilir)
2. Menüden **Tools** > **Options** yolunu takip edin
3. Sol taraftaki menüden **GitHub** > **Copilot** sekmesini bulun
4. **Enable custom instructions** seçeneğini işaretleyin
5. İsteğe bağlı olarak **Use repository custom instructions** seçeneğini de aktif edin

![Visual Studio Copilot Custom Instructions Ayarları](/assets/img/copilot-custom-instructions-vs.svg)

> **Not:** Bu özellik Visual Studio 2022 17.8 ve sonraki versiyonlarda mevcuttur. Daha eski versiyonlarda bu seçeneği göremiyorsanız, Visual Studio'nuzu güncellemeniz gerekebilir.

### Repository Seviyesinde Talimat Dosyası Oluşturma

Ayarları aktif ettikten sonra, projenizin kök dizininde `.github/copilot-instructions.md` dosyası oluşturarak Copilot'a özel talimatlar verebilirsiniz. Bu dosya tüm ekip üyeleri için geçerli olacaktır.

---

## Neden Copilot Instruction ile Unit Test Yazımı?

Unit test yazımında karşılaşılan yaygın problemler:

- **Test yazımı zaman alır**: Mock kurulumu ve tekrarlı senaryolar geliştiriciyi yavaşlatır.
- **Testler farklı stillerde yazılır**: Her geliştirici kendi alışkanlıklarıyla test yazar; bu tutarsızlığa yol açar.
- **Coverage eksik kalır**: Özellikle edge case ve hata senaryoları gözden kaçabilir.
- **Kalite değişkendir**: Assertion kalitesi, naming standardı ve izolasyon kuralları kişiden kişiye farklılaşır.

Copilot Instruction sayesinde:
- Test yazımı **hızlanır**; Copilot tekrar eden yapıları otomatik üretir.
- Test formatı **tutarlı** olur; ekip genelinde aynı naming, yapı ve mock kuralları uygulanır.
- **Edge case ve hata senaryoları** otomatik olarak dahil edilir.
- Manual code review yükü azalır.

## Copilot Instruction: Unit Test Talimatları (Standart Set)

Aşağıdaki talimat seti, Copilot’un test üretirken izlemesi gereken kuralları tanımlar.  
Infrastructure → Copilot → Test oluşturma pipeline’ında rehber olur.

### ✔ 1. Test İsmi Kuralları
- Test framework için öneri: **xUnit** veya **xUnit-compatible** naming.  
- Genel pattern:  
  **`<MethodName>_<Scenario>_<ExpectedResult>`** veya **`Should_<Expected>_When_<Condition>`**.  
- Örnek:  
  `UpdateUser_WhenEmailIsInvalid_ShouldReturnError`  
  veya  
  `Should_ReturnError_When_EmailIsInvalid`

### ✔ 2. AAA (Arrange – Act – Assert) Zorunluluğu
Her test üç bölüme ayrılmalı:

```csharp
// Arrange
// Act
// Assert
```

Her blok **boş satırla ayrılmalı**. Arrange kısmında mümkünse test fixture factory veya helper kullanılmalı.

### ✔ 3. Mocking Kuralları
- Mock framework tercihi: **NSubstitute** (ekip politikası).  
- Mock'lar yalnızca SUT (system under test) dışındaki bağımlılıklar için oluşturulmalı.  
- Arg doğrulama için `Arg.Is<T>(...)` kullan; aşırı `Arg.Any` kullanımından kaçın.  
- Asenkron methodlar için `Returns(Task.FromResult(...))` veya `ReturnsAsync(...)` tercih et.

### ✔ 4. Test İzolasyonu & Determinizm
- Testler asla global state değiştirmemeli.  
- Tarih/zaman bağımlılıkları için ITimeProvider gibi interface mock’lanmalı.  
- Random/GUID gibi değerler sabitlenmeli veya factory üzerinden oluşturulmalı.  
- Paralel çalışmayı bozacak paylaşılan mutable static kullanımından kaçın.

### ✔ 5. Pozitif + Negatif + Edge Case Zorunluluğu
Her handler / service methodu için Copilot şu testleri üretmelidir:
- **Happy path** (başarı senaryosu) — en az 1.  
- **Guard / validation** testleri — null, invalid inputs — her bir guard için ayrı test.  
- **Business rule (invariant) ihlalleri** — her önemli iş kuralı için ayrı test.  
- **Concurrency / concurrency-related** senaryolar gerekiyorsa mock ile simüle edilip test edilmeli.

### ✔ 6. Exception ve Error Handling
- Eğer SUT exception fırlatabiliyorsa (`ArgumentNullException`, domain exception vs.), Copilot mutlaka `Assert.Throws` veya `Assert.ThrowsAsync` kullanmalı.  
- Hata mesajı doğrulaması gerekiyorsa `Assert.Contains(..., StringComparison.OrdinalIgnoreCase)` gibi case-insensitive kontroller tercih edilmeli.

### ✔ 7. Parametrik Testler (Theory / TestCase)
- Parametrik testler `[Theory]` + `[InlineData(...)]` veya `[TestCase]` ile yapılmalı yalnızca davranış farklıysa.  
- Aynı sonucu tekrarlayan varyasyonlar eklenmesin — test setini şişirmemeye dikkat et.

### ✔ 8. Naming & Test Class Structure
- Test sınıf adı: `<SUTClassName>Tests` (örn. `AddGoalPeriodCommandHandlerTests`).  
- Her test metodu kendi içinde tek bir assertion grubunu doğrular; birden fazla davranış tek methodta test edilmez.  
- Setup / Teardown + küçük factory method'ları test sınıfı içinde toplanmalı.

### ✔ 9. Coverage Beklentisi
- Kritikal iş kuralları, tüm if/else branch’leri, erken dönüşler, switch-case dalları test edilmeli.  
- Yeni eklenen iş kuralı veya branch için Copilot otomatik olarak test üretmeli.

### ✔ 10. Test Performansı ve Paralellik
- Uzun süren (integration-level) testler ayrı kategoriye alınmalı.  
- Unit testler hızlı (<100ms ideal) ve paralel çalışabilir olmalı.  
- Paylaşılan kaynakları resetleyen fixture'lar kullanılmalı.

### ✔ 11. Assertions / Verification
- Mock çağrı doğrulamalarında `Received()` / `DidNotReceive()` kullan.  
- Arg doğrulama için `Arg.Is<T>(p => p.Prop == val && ...)` kullan.  
- Hata mesajı veya liste içi kontrol gerekiyorsa `Assert.Contains(...)` ile fragment check yapılmalı.

### ✔ 12. Guard Tests (Ctor null checks vs.)
- Constructor guard testleri yazılmalı (örn. null dependency => `ArgumentNullException`).  
- Birim testi başına en az bir guard test (eğer class null-safe değilse) olmalı.

### ✔ 13. Test Metadata & Traits
- Kategori/tags eklemek için:  
  `[Trait("Category", "GoalManagement/AddGoalPeriod")]` veya NUnit’da `[Category("...")]`.  
- Turkçe mesaj içeren testler optional; tercih edilirse İngilizce hata mesajı standardı korunmalı.

### ✔ 14. Dokümantasyon & Inline Comments
- Copilot tarafından üretilen testlerde önemli kısımlar için kısa inline comment bırakılmalı.  
- Eğer Copilot bir varsayım yapıyorsa (`// Assumes repository returns null when not found`) bu açıkça belirtilmeli.

### ✔ 15. CI Pipeline Uyumluluğu
- Üretilen testler CI pipeline’da (dotnet test) kırılmamalı.  
- Gerektiğinde `[Collection("Sequential")]` veya paralelliği kontrol eden attribute kullanılmalı.

---

## Örnek: NSubstitute + xUnit Uyumlu Test Şablonu

```csharp
public class AddGoalPeriodCommandHandlerTests
{
    private readonly IRepository<GoalPeriod> _repo = Substitute.For<IRepository<GoalPeriod>>();
    private readonly AddGoalPeriodCommandHandler _sut;

    public AddGoalPeriodCommandHandlerTests()
    {
        _sut = new AddGoalPeriodCommandHandler(_repo);
    }

    [Fact]
    public async Task Handle_Returns_error_when_period_already_exists()
    {
        // Arrange
        _repo.AnyAsync(Arg.Any<GoalPeriodByTeamIdAndYearSpec>(), Arg.Any<CancellationToken>())
             .Returns(true);

        var cmd = new AddGoalPeriodCommand(TeamId: 10, UserId: 1, Year: 2025);

        // Act
        var result = await _sut.Handle(cmd, CancellationToken.None);

        // Assert
        Assert.False(result.IsSuccess);
        Assert.Contains(result.Errors, e => e.Contains("already exists", StringComparison.OrdinalIgnoreCase));
        await _repo.DidNotReceive().AddAsync(Arg.Any<GoalPeriod>(), Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task Handle_Returns_invalid_for_non_positive_year(int invalidYear)
    {
        // Arrange
        var cmd = new AddGoalPeriodCommand(TeamId: 1, UserId: 1, Year: invalidYear);

        // Act
        var result = await _sut.Handle(cmd, CancellationToken.None);

        // Assert
        Assert.False(result.IsSuccess);
        Assert.Contains(result.Errors, e => e.Contains("year", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Ctor_Throws_ArgumentNullException_when_repo_null()
    {
        // Arrange / Act & Assert
        Assert.Throws<ArgumentNullException>(() => new AddGoalPeriodCommandHandler(null!));
    }
}
```

---

## Copilot Instruction Örnek İçeriği (`.github/copilot-instructions.md` için)
Aşağıdaki metin, repository içine konulabilecek bir örnek `copilot-instructions.md` parçasıdır.

```
# Test Guidelines
- framework: xunit
- mock: nsubstitute
- naming: MethodName_WhenCondition_ShouldExpected
- arrange-act-assert: required
- guard-tests: required
- parametrized: use theory only when behavior differs
- arg-validation: prefer Arg.Is<T>(...) checks
- no-randomness: avoid Guid.NewGuid/DateTime.Now in tests
- test-coverage: cover branches for business rules
- single-assert-per-test: no multiple behavior checks in one test
```

---

## Özet ve Öneriler
- Copilot Instruction’ı repo root’unda yayınlayarak Copilot’un test üretimini yönlendir.  
- Talimatları açık, kısa ve deterministik tut.  
- Yeni handler/command eklenince Copilot’un otomatik test üretmesini sağlayacak CI adımı tasarla.  
- Kod review sırasında Copilot tarafından oluşturulan testlerin talimatlara uyduğunu doğrula (otomatik lint/validation eklentisi düşünülebilir).

---

## Sık Sorulan Sorular (FAQ)

**Copilot hangi seviyede müdahale eder?**  
Repo seviyesinde veya workspace seviyesinde. `.github/copilot-instructions.md` içeriği Copilot tarafından referans alınır.

**Parametrik testleri ne zaman kullanmalıyım?**  
Eğer farklı girdiler farklı branch’leri tetikliyorsa; aksi halde her varyasyon ayrı test olmalı.

**Nasıl deterministik test ürettiririm?**  
ITimeProvider, IIdFactory gibi abstractionlar kullan ve testlerde mock'la.

---

## Kaynaklar

- [Goal Management System — `.github/copilot-instructions.md`](https://github.com/DTVegaArchChapter/Architecture/blob/main/ddd/goal-management-system/.github/copilot-instructions.md)
- [DTVegaArchChapter/Architecture — Goal Management System](https://github.com/DTVegaArchChapter/Architecture/tree/main/ddd/goal-management-system)
