---
layout: post
title: "LangChain İle Model İşlemleri"
categories: [ai]
tags: [ai, langchain, llm, model]
lang: tr
author: TahaPek
excerpt: Langchain ile bir model nesnesi nasıl oluştururuz? Model nesnesinin parametreleri ne işe yarar? Hangi yöntemleri kullanmalıyız? Sorularına cevap arıyoruz. 
date: 2026-11-02
last_modified_at: 2026-11-02 20:52:00 +0300
---

<!-- markdownlint-disable MD033 -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "LangChain İle Model İşlemleri",
    "datePublished": "2026-11-02",
    "author": { "@type": "Person", "name": "TahaPek" }
}
</script>
<!-- markdownlint-enable MD033 -->


## LangChain'de Chat Model Oluşturma: `ChatOpenAI` ile Başlangıç

LangChain'de **model oluşturma**, kullanacağımız sohbet modelini (chat model) seçip uygulamamız için yapılandırmak demek. Bunu, uygulamamızın nasıl konuşacağını ve hangi yapay zekâ sağlayıcısıyla iletişim kuracağını belirlediğimiz ilk adımlardan biri olarak düşünebiliriz. Bir agent kullanıyorsak model aynı zamanda onun “beyni” gibi çalışır: hangi aracın çağrılacağına, araçlardan gelen sonuçların nasıl yorumlanacağına ve kullanıcıya ne zaman yanıt verileceğine karar verir.

Önce küçük bir başlangıç yapalım: `ChatOpenAI` ile bir model oluşturalım ve temel ayarların ne işe yaradığını konuşalım. Ardından `init_chat_model` ile sağlayıcıya özgü sınıfların farkına bakacak, modelden yanıt alacak ve onu basit bir agent'a bağlayacağız. Yazının sonunda da tool calling, yapılandırılmış çıktı ve Responses API gibi sık karşılaşacağınız birkaç özelliğe göz atacağız.

## Chat Modeli oluşturma nedir, neden yapılır?

Bir chat modeli, en basit haliyle, kendisine gönderdiğimiz mesajları yorumlayıp bir yanıt üreten yapay zekâ modelidir. LangChain'de bu modeli oluştururken yalnızca API anahtarını tanımlamış olmayız. Modelin **nasıl davranacağını** (örneğin yanıtlarının ne kadar değişken olacağını ya da ne kadar uzun olabileceğini) ve **hangi hizmete nasıl bağlanacağını** da belirleriz.

Bunu biraz mutfak benzetmesiyle düşünebiliriz: aynı tarifi iki farklı şef uyguladığında sonuçlar değişebilir. Seçtiğimiz model, kullandığımız malzemeler; model ayarlarıysa tarifin ayrıntıları gibidir. Uygun modeli ve ayarları seçmek, özellikle uygulamamızın bir agent üzerinden araçlarla çalıştığı durumlarda, sonuçların niteliğini doğrudan etkiler.

Model seçimi birkaç açıdan önem kazanır:
- Bir agent'ın güvenilirliği ve performansı, büyük ölçüde kullandığı modelin yeteneklerine bağlıdır.
- Her model aynı işte eşit derecede başarılı olmayabilir. Kimi karmaşık talimatları daha iyi izler, kimi yapılandırılmış çıktılarda ya da uzun bağlamlarla çalışırken öne çıkar.
- LangChain'in ortak arayüzü, sağlayıcı değişikliğini kolaylaştırır. Örneğin OpenAI'dan Anthropic'e geçerken uygulamanın tüm akışını baştan yazmamız gerekmez; yine de sağlayıcıya özel ayarları gözden geçirmemiz gerekir.

Yani model oluşturma adımını, uygulamanın geri kalanını şekillendiren küçük ama önemli bir başlangıç ayarı olarak görebiliriz.

## Model oluşturma adımları

1. **Gerekli paketi kurun** – OpenAI entegrasyonu için `pip install -U langchain-openai` komutunu çalıştırın.
2. **API anahtarını ayarlayın** – Anahtarı ortam değişkeninde tutmak, doğrudan kaynak koduna yazmaktan daha güvenli ve pratiktir. macOS/Linux için örnek: `export OPENAI_API_KEY="your-api-key"`.
3. **Modeli başlatın** – `ChatOpenAI` sınıfıyla hangi modeli kullanacağımızı belirtin.
4. **İhtiyacınıza göre ayarlayın** – `temperature`, `max_tokens`, `timeout` ve `max_retries` gibi parametrelerle davranışı ve bağlantıyı düzenleyin.
5. **Bir mesaj gönderin** – `invoke()` ile modeli çağırıp yanıtını alın.
6. **İsterseniz agent'a bağlayın** – `create_agent(model=..., tools=...)` ile modelin araçlarla birlikte çalışmasını sağlayın.

İlk denemede bu adımların hepsini aynı anda öğrenmek zorunda değilsiniz. Önce modeli başlatıp yanıt almak yeterli; diğer ayarları da ihtiyaç duydukça ekleyebiliriz.

## `ChatOpenAI` nedir ve nasıl kullanılır?

`ChatOpenAI`, LangChain'in OpenAI ile çalışmak için sunduğu chat model sınıfıdır. Model adını ve API anahtarını verdiğimizde, mesajlarımızı OpenAI API'sine uygun biçimde gönderip yanıtı LangChain'in kullanabileceği bir yapıya dönüştürür.

Burada küçük ama önemli bir ayrım var: Sınıfın adı `ChatOpenAI` olsa da bu, her OpenAI-uyumlu servisin tüm özelliklerinin otomatik olarak destekleneceği anlamına gelmiyor. Bu entegrasyon OpenAI'ın resmi API biçimini hedefler; OpenRouter, vLLM veya DeepSeek gibi bazı sağlayıcıların eklediği standart dışı yanıt alanlarını (örneğin `reasoning_content`) ayrıca çıkarıp korumaz. Böyle bir sağlayıcının özel özelliklerine ihtiyacınız varsa, mümkünse o sağlayıcıya özel LangChain paketini (`ChatDeepSeek`, `ChatOpenRouter` gibi) tercih edin.

En basit kullanımda bir model adı yeterli. API anahtarını da ortam değişkeninde tuttuğumuzda, sınıf bu anahtarı otomatik olarak bulabilir:

```python
import os
from langchain_openai import ChatOpenAI

os.environ["OPENAI_API_KEY"] = "sk-..."

model = ChatOpenAI(model="gpt-4o")
```

## `ChatOpenAI` parametreleri ve anlamları

`ChatOpenAI` oluştururken karşımıza çıkan parametreleri kabaca iki gruba ayırabiliriz. **Completion params**, modelin üreteceği yanıtı etkiler; **client params** ise isteğin hangi koşullarda ve hangi bağlantı bilgileriyle gönderileceğini düzenler. Bu ayrım, hangi ayarı nerede arayacağımızı anlamayı kolaylaştırır.

### Completion parametreleri (model davranışı)

| Parametre | Tip | Amaç |
|---|---|---|
| `model` | string (zorunlu) | Kullanılacak OpenAI modelinin adı, örn. `"gpt-4o"`, `"gpt-4o-mini"`. |
| `temperature` | float | Sampling sıcaklığı. Düşük değer (0) daha deterministik, yüksek değer daha yaratıcı yanıtlar üretir. |
| `max_tokens` | int veya None | Üretilecek maksimum token sayısı. `None` ise limit uygulanmaz. |
| `logprobs` | bool veya None | Her token için log-olasılık değerlerinin döndürülüp döndürülmeyeceğini belirler. Analiz ve debug için kullanışlıdır. |
| `stream_options` | dict | Streaming çıktılarını yapılandırır, örn. `{"include_usage": True}` ile akış sırasında token kullanımını da döndürür. |
| `use_responses_api` | bool veya None | OpenAI'ın yeni Responses API'sini kullanıp kullanmayacağını belirler. Bazı gelişmiş özellikler (reasoning, built-in tools, conversation state) için gereklidir. |

Örneğin `temperature` ile yanıtların çeşitliliğini, `max_tokens` ile yanıtın üst uzunluk sınırını ayarlayabiliriz. Her parametre her modelde aynı şekilde desteklenmeyebilir; özellikle sağlayıcıya veya modele bağlı özellikleri kullanmadan önce ilgili API desteğini kontrol etmek iyi bir alışkanlıktır. Başlangıçta varsayılan değerlerle ilerleyip yalnızca gerçekten ihtiyaç duyduğumuz ayarları değiştirmek de gayet makul.

### Client parametreleri (bağlantı)

| Parametre | Tip | Amaç |
|---|---|---|
| `timeout` | float, tuple veya None | İstek için beklenilecek maksimum süre (saniye). Bu süre aşılırsa istek iptal edilir. |
| `max_retries` | int veya None | Ağ zaman aşımı veya hız limiti gibi nedenlerle başarısız olan isteklerin yeniden deneme sayısı. |
| `api_key` | string veya None | OpenAI API anahtarı. Verilmezse `OPENAI_API_KEY` ortam değişkeninden okunur. |
| `base_url` | string veya None | API isteklerinin hedef URL'si. Proxy veya servis emülatörü kullanılıyorsa belirtilir; aksi halde `OPENAI_API_BASE` veya `OPENAI_BASE_URL` ortam değişkenlerinden okunur. |
| `organization` | string veya None | OpenAI organizasyon ID'si. Verilmezse `OPENAI_ORG_ID` ortam değişkeninden okunur. |

Bu gruptaki ayarlar yanıtın üslubundan çok, isteğin yolculuğuyla ilgilidir. Örneğin `timeout`, yanıtı beklerken ne kadar süre sonra vazgeçeceğimizi belirler; `max_retries` ise geçici bir ağ veya hız limiti hatasında yeniden deneme sayısını ayarlar. API anahtarını kodda açıkça vermek mümkün olsa da, çoğu projede ortam değişkeni kullanmak daha güvenli bir tercih olur.

### Diğer önemli parametreler

| Parametre | Amaç |
|---|---|
| `frequency_penalty` | Aynı kelimenin tekrarını cezalandırır. Pozitif değerler kelime tekrarını azaltır. |
| `presence_penalty` | Modelin yeni konulara yönelmesini teşvik eder. Pozitif değerler tekrarı azaltır. |
| `seed` | Deterministik çıktı için tohum (seed) değeri. Aynı seed ile aynı girdi her seferinde benzer çıktı üretir. |
| `stop` | Modelin üretmeyi durduracağı kelime veya kelime dizilerini belirtir. |
| `n` | Tek istekte kaç farklı yanıt seçeneği üretileceğini belirler. Varsayılan 1. |
| `service_tier` | `"flex"` gibi değerlerle daha ucuz ama daha yavaş işleme katmanı seçmenizi sağlar. Beta özelliktir ve yalnızca bazı modellerde mevcuttur. |
| `model_kwargs` | Standart OpenAI API parametrelerini istek gövdesine düz (top-level) eklemek için kullanılır, örn. `max_completion_tokens`, `stream_options`, `modalities`, `audio`. |
| `extra_body` | OpenAI ile uyumlu ama standart dışı sağlayıcı parametrelerini (vLLM, LM Studio, OpenRouter vb.) isteğin `extra_body` alanına eklemek için kullanılır. |

Bu parametrelerin hepsini ilk modelinizde kullanmanız gerekmiyor. Örneğin `frequency_penalty` ve `presence_penalty` metin üretiminin tekrar eğilimini etkilerken, `stop` belirli bir metinle karşılaşıldığında üretimi durdurabilir. `n` ise tek istekte birden fazla alternatif yanıt istemek için kullanılır. Kullanım alanınız netleştikçe bu seçeneklerden hangilerinin işinize yaradığını daha rahat seçebilirsiniz.

**Önemli ayrım – `model_kwargs` vs `extra_body`:** `model_kwargs` parametreleri isteğin en üst seviyesine birleştirir; `extra_body` ise parametreleri `extra_body` anahtarı altına yerleştirir. OpenAI ile uyumlu sağlayıcıların özel parametreleri için **her zaman `extra_body`** kullanılmalıdır; aksi halde API hatası alınır.

Kısaca: OpenAI API'sinin tanıdığı standart bir seçenek gönderiyorsak `model_kwargs` uygun olabilir; kullandığımız uyumlu servise özgü, standart dışı bir seçenek söz konusuysa `extra_body` doğru yerdir. Sunucu beklediği parametreleri farklı bir biçimde aldığında isteği reddedebilir, bu yüzden bu ayrımı baştan doğru yapmak hata ayıklamayı da kolaylaştırır.

**Korunan parametreler (Preserved params):** LangChain tarafından açıkça desteklenmeyen herhangi bir parametre, model her çağrıldığında doğrudan `openai.OpenAI.chat.completions.create(...)` fonksiyonuna iletilir. Örneğin:

```python
ChatOpenAI(..., frequency_penalty=0.2).invoke(...)

# Bu, altta yatan API çağrısına şunu ekler:
# openai.OpenAI(..).chat.completions.create(..., frequency_penalty=0.2)
```

Bu, `ChatOpenAI(...).invoke(..., frequency_penalty=0.2)` şeklinde de yazılabilir.

Bu parametrelere ek farklı parametreler de tabii ki mevcuttur. Onları hem OpenAI hem de LangChain resmi sitelerinde inceleyebilirsiniz.

## `init_chat_model` mı, `ChatOpenAI` mı?

Peki modele hangi kapıdan ulaşalım: `init_chat_model` mı, yoksa doğrudan `ChatOpenAI` mı? İkisi de bir chat modeli başlatmamızı sağlar. Aralarındaki temel fark, sağlayıcı değiştirme kolaylığı ile sağlayıcıya özgü ayrıntılara ne kadar doğrudan erişmek istediğimizdir.

### `init_chat_model` ne zaman kullanılır?

`init_chat_model`, birden fazla sağlayıcıyla çalışmayı kolaylaştıran genel bir başlangıç noktasıdır. Sağlayıcıyı ve model adını tek bir ifadede belirtebiliriz; örneğin aşağıdaki kullanımda `openai:` sağlayıcıyı, `gpt-4o` ise model adını gösterir.

```python
import os
from langchain.chat_models import init_chat_model

os.environ["OPENAI_API_KEY"] = "sk-..."

model = init_chat_model("openai:gpt-4o")
```

**Ne zaman işimize yarar?**
- Hızlıca bir prototip hazırlarken veya LangChain'e yeni başlarken.
- OpenAI, Anthropic, Gemini ya da Bedrock gibi farklı sağlayıcıları ortak bir yaklaşımla denemek istediğimizde.
- Sağlayıcı ve model adını tek bir yerde (`"openai:gpt-4o"` gibi) belirtmek istediğimizde.

### `ChatOpenAI` ne zaman kullanılmalı?

Uygulamamız OpenAI'a odaklıysa ve API'ye özgü seçenekleri daha görünür biçimde kullanmak istiyorsak `ChatOpenAI` daha doğrudan bir tercih olabilir. Sınıf, birçok OpenAI ayarını kendi parametreleri olarak sunar; bu da kodu okurken hangi ayarların kullanıldığını anlamayı kolaylaştırır.

```python
import os
from langchain_openai import ChatOpenAI

os.environ["OPENAI_API_KEY"] = "sk-..."

model = ChatOpenAI(model="gpt-4o")
```

**Ne zaman işimize yarar?**
- `use_responses_api`, `logprobs`, `seed` veya `service_tier` gibi OpenAI'a özgü seçeneklere ihtiyaç duyduğumuzda.
- IDE otomatik tamamlamasından ve parametre adlarının daha açık olmasından yararlanmak istediğimizde.
- Uygulamamız tek bir sağlayıcıya odaklanıyorsa ve bu sağlayıcının özelliklerini daha ayrıntılı kullanacaksak.

Özetle, birden fazla sağlayıcıyı kolayca değiştirebilmek önceliğimizse `init_chat_model`; OpenAI ayarlarını daha yakından kontrol etmek önceliğimizse `ChatOpenAI` ile başlayabiliriz. Bu iki seçenek birbirine rakip olmak zorunda değil: projenin ihtiyacı değiştikçe tercihimiz de değişebilir.

### Karşılaştırma tablosu

| Özellik | `init_chat_model` | `ChatOpenAI` |
|---|---|---|
| Kullanım kolaylığı | Yüksek (tek fonksiyon) | Orta (paket kurulumu gerekir) |
| Çoklu sağlayıcı desteği | Evet, tek arayüz | Hayır, sadece OpenAI |
| Sağlayıcıya özgü parametreler | `**kwargs` ile geçilir | Doğrudan sınıf parametresi olarak |
| Tip güvenliği | Daha az | Daha fazla |
| Önerilen kullanım | Prototip, çoklu sağlayıcı | Üretim, OpenAI odaklı |

## Modelden yanıt alalım: `invoke()`

Modelimizi hazırladığımıza göre artık ona bir mesaj gönderebiliriz. Bunun için en temel yöntem `invoke()`; verdiğimiz mesajları modele iletir ve yanıtın tamamı hazır olduğunda sonucu döndürür. Yani bu örnekte yanıtı parça parça izlemiyoruz, tek bir sonuç olarak alıyoruz.

Mesajları `system` ve `human` rollerini kullanarak iletiyoruz. `system` mesajı modelin nasıl davranmasını istediğimizi, `human` mesajı ise kullanıcının isteğini anlatıyor:

```python
messages = [
    ("system", "Sen yardımcı bir çevirmensin. Kullanıcının cümlesini Fransızcaya çevir."),
    ("human", "I love programming."),
]
response = model.invoke(messages)
```

Çağrının sonucu, yalnızca yanıt metninden ibaret değildir: LangChain bunu bir `AIMessage` nesnesi olarak döndürür. İhtiyacımız varsa nesnenin içinden asıl metni okuyabilir, ayrıca token kullanımı, yanıtı üreten model ve üretimin nasıl sona erdiği gibi bilgilere de ulaşabiliriz. Aşağıdaki örnek temsili bir yanıtın nasıl görünebileceğini gösteriyor; gerçek değerler kullandığınız modele ve isteğe göre değişir:

```python
AIMessage(
    content="J'adore la programmation.",
    response_metadata={
        "token_usage": {
            "completion_tokens": 5,
            "prompt_tokens": 31,
            "total_tokens": 36,
        },
        "model_name": "gpt-4.1-mini",
        "system_fingerprint": "fp_43dfabdef1",
        "finish_reason": "stop",
        "logprobs": None,
    },
    id="run-012cffe2-5d3d-424d-83b5-51c6d4a593d1-0",
    usage_metadata={
        "input_tokens": 31,
        "output_tokens": 5,
        "total_tokens": 36,
    },
)
```

### `AIMessage` içeriğini anlamak

İlk bakışta metadata alanları biraz kalabalık görünebilir; çoğu basit kullanımda bunların tamamına ihtiyacımız olmaz. Yine de bir uygulamanın maliyetini izlemek, yanıtın neden kesildiğini araştırmak ya da modelin ne döndürdüğünü incelemek istediğimizde bu alanlar oldukça yararlı olur:

- **`content`** – Modelin ürettiği asıl metin yanıt.
- **`response_metadata`** – OpenAI API'sinden gelen ham metadata:
  - `token_usage` – `completion_tokens` (üretilen), `prompt_tokens` (girdi) ve `total_tokens` (toplam) token sayıları.
  - `model_name` – Yanıtı üreten spesifik model.
  - `system_fingerprint` – Model sürümünü/konfigürasyonunu tanımlayan parmak izi.
  - `finish_reason` – Yanıtın neden bittiğini gösterir (`"stop"` normal bitiş, `"length"` token limiti, `"tool_calls"` araç çağrısı vb.).
  - `logprobs` – Eğer `logprobs=True` verilmişse token bazlı olasılık verileri.
- **`id`** – Bu çalıştırmanın benzersiz kimliği.
- **`usage_metadata`** – LangChain'in standartlaştırdığı token kullanım formatı: `input_tokens`, `output_tokens`, `total_tokens`.

Örneğin sadece token kullanımını görmek istiyorsak, tüm nesneyi incelemek yerine `usage_metadata` alanını yazdırabiliriz:

```python
ai_msg = model.invoke(messages)
print(ai_msg.usage_metadata)
```

**Beklenen mock çıktı:**
```python
{"input_tokens": 28, "output_tokens": 5, "total_tokens": 33}
```

## Modeli bir agent'a bağlayalım (temel seviye)

Buraya kadar modelle doğrudan konuşmayı gördük. Bir sonraki adımda modeli bir **agent** içinde kullanabiliriz. Agent, gerektiğinde bir aracı çağıran, araçtan gelen sonucu değerlendiren ve görevi tamamladığında kullanıcıya yanıt veren bir çalışma akışıdır. Model bu akışta hangi adımın atılacağına karar verir; araçlar ise dış dünyadan bilgi alma veya belirli bir işi yapma olanağı sağlar.

Aşağıdaki örnekte hava durumunu döndüren basit bir araç tanımlıyoruz. Buradaki sonuç örnek amaçlı sabit; gerçek bir uygulamada bu fonksiyon bir hava durumu servisine bağlanabilir.

```python
from langchain.agents import create_agent
from langchain.tools import tool

@tool
def get_weather(location: str) -> str:
    """Belirtilen konumdaki hava durumunu getirir."""
    return f"{location} için hava durumu: Güneşli, 22°C"

agent = create_agent(
    model=model,  # Yukarıda oluşturduğumuz ChatOpenAI örneği
    tools=[get_weather],
    system_prompt="Sen yardımcı bir asistansın. Kısa ve doğru cevap ver."
)
```

Bu örnekte `create_agent`, modeli ve kullanabileceği araçları bir araya getiriyor. Parametreleri şöyle düşünebiliriz:
- `model` – Agent'ın karar verirken kullanacağı, başlattığımız model örneği (`ChatOpenAI` gibi) ya da bir model tanımlayıcısı.
- `tools` – Agent'ın gerektiğinde çağırabileceği araçlar. Bunlar Python fonksiyonları, LangChain araçları veya uygun sözlük tanımları olabilir.
- `system_prompt` – Agent'a nasıl bir yaklaşım izlemesi gerektiğini söyleyen başlangıç talimatı. Örnekte kısa ve doğru yanıt vermesini istiyoruz.

### Agent'tan yanıt alma

Agent'ı çağırırken kullanıcı mesajını `messages` alanında iletiyoruz. Agent, sorunun yanıtlanması için araca ihtiyaç olup olmadığına karar verir; gerekiyorsa aracı çalıştırır ve sonuçla birlikte bir yanıt oluşturur. Son mesajı aşağıdaki gibi okuyabiliriz:

```python
result = agent.invoke(
    {"messages": [{"role": "user", "content": "Boston'da hava nasıl?"}]}
)
print(result["messages"][-1].text)
```

**Beklenen mock çıktı:**
```
Agent: Boston'da hava durumu şu anda güneşli ve 22°C.
```

> **Not:** Agent'lar kendi başlarına geniş bir konu. State yönetimi, checkpointer, structured output, streaming ve çoklu-agent sistemleri gibi başlıklara bu yazıda girmiyoruz; şimdilik modelin bir araca sahip agent'a nasıl bağlandığını gördük. Bu temel akışı oturttuktan sonra bu özellikleri ayrı ayrı ele almak çok daha kolay olacaktır.

## Biraz daha ilerisi: modelin ek özellikleri

Temel kullanımda modeli oluşturup `invoke()` etmek çoğu zaman yeterli. Ancak uygulama büyüdükçe modelden araç çağırmasını, belirli bir veri biçiminde yanıt vermesini veya kullanım bilgilerini raporlamasını isteyebiliriz. Aşağıdaki örnekler bu özelliklerin neye yaradığını tanıtıyor; hepsini aynı anda kullanmamız gerekmiyor. İhtiyacımıza uyanı seçip küçük denemelerle ilerleyebiliriz.

- **Tool calling (araç çağırma):** `ChatOpenAI`'ın `bind_tools()` metodu ile Pydantic modellerini veya fonksiyonları modele araç olarak tanıtabiliriz. Model, isteği yorumlayıp hangi araca hangi argümanlarla ihtiyaç duyduğunu belirtir; bu çağrı bilgileri `tool_calls` alanında yer alır. Önemli nokta şu: model araç çağrısını seçer ve tarif eder, aracın gerçekten çalıştırılması ise kullandığımız akışın sorumluluğundadır. Agent kullanırken bu döngü çoğunlukla agent tarafından yönetilir.

```python
from pydantic import BaseModel, Field

class GetWeather(BaseModel):
    '''Belirtilen konumdaki güncel hava durumunu getirir'''
    location: str = Field(..., description="Şehir ve eyalet, örn. San Francisco, CA")

model_with_tools = model.bind_tools([GetWeather])
ai_msg = model_with_tools.invoke("LA mı NY mı daha sıcak?")
print(ai_msg.tool_calls)
```

**Beklenen mock çıktı:**
```python
[
    {
        "name": "GetWeather",
        "args": {"location": "Los Angeles, CA"},
        "id": "call_6XswGD5Pqk8Tt5atYr7tfenU",
    },
    {
        "name": "GetWeather",
        "args": {"location": "New York, NY"},
        "id": "call_ZVL15vA8Y7kXqOy3dtmQgeCi",
    },
]
```

- **Paralel araç çağrıları:** Bazı sorularda modelin birden fazla araca ihtiyaç duyması mümkündür. `parallel_tool_calls` ayarı, bu araç çağrılarının paralel yürütülmesine izin verilip verilmeyeceğini etkiler. Aşağıdaki örnekte `False` vererek aynı istekte paralel çağrıları kapatıyoruz. Bu seçeneğin varsayılanı ve kullanılabilirliği, kullandığınız OpenAI SDK/API sürümüne göre değişebileceği için sürümünüzün dokümantasyonunu da kontrol edin:

```python
ai_msg = model_with_tools.invoke(
    "LA ve NY'de hava nasıl?",
    parallel_tool_calls=False
)
```

- **Structured output (yapılandırılmış çıktı):** Yanıtı sonradan kodla işleyeceksek, serbest biçimli metin yerine belirli alanlardan oluşan bir sonuç almak işimizi kolaylaştırır. `with_structured_output()` ile bir Pydantic şeması tanımlayıp modelden bu yapıya uygun çıktı isteyebiliriz. Böylece örneğin şaka metnini ve puanını ayrı alanlarda ele alabiliriz:

```python
from pydantic import BaseModel, Field

class Joke(BaseModel):
    '''Kullanıcıya anlatılacak şaka.'''
    setup: str = Field(description="Şakanın kurulum kısmı")
    punchline: str = Field(description="Şakanın punchline'ı")
    rating: int | None = Field(description="Şakanın ne kadar komik olduğu, 1-10")

structured_model = model.with_structured_output(Joke)
result = structured_model.invoke("Kediler hakkında bir şaka anlat")
```

**Beklenen mock çıktı:**
```python
Joke(
    setup="Kedi neden bilgisayarın üstünde oturuyordu?",
    punchline="Fareyi gözden kaçırmamak için!",
    rating=None,
)
```

- **JSON mode:** Bir başka seçenek de yanıtı JSON biçiminde istemektir. `bind(response_format={"type": "json_object"})` ile JSON nesnesi talep edebiliriz. JSON mode biçimi sınırlar; alanların tam olarak beklediğimiz şemaya uymasını garanti etmek gerekiyorsa yapılandırılmış çıktı yaklaşımını değerlendirmek daha uygun olabilir:

```python
json_model = model.bind(response_format={"type": "json_object"})
ai_msg = json_model.invoke(
    "'random_ints' anahtarı ve 0-99 arası 10 rastgele tam sayı değeri içeren bir JSON nesnesi döndür"
)
```

**Beklenen mock çıktı:**
```python
'{"random_ints": [23, 87, 45, 12, 78, 34, 56, 90, 11, 67]}'
```

- **Logprobs:** Modelin ürettiği token'lara ait olasılık bilgilerini incelemek istediğimizde `logprobs=True` seçeneğini kullanabiliriz. Bu bilgiler analiz ve hata ayıklamada yardımcı olabilir; ancak tek başına modelin neden belirli bir yanıtı verdiğini açıklayan bir gerekçe olarak düşünülmemelidir:

```python
logprobs_model = model.bind(logprobs=True)
ai_msg = logprobs_model.invoke(messages)
print(ai_msg.response_metadata["logprobs"])
```

**Beklenen mock çıktı (kısaltılmış):**
```python
{
    "content": [
        {
            "token": "J",
            "bytes": [74],
            "logprob": -4.9617593e-06,
            "top_logprobs": [],
        },
        {
            "token": "'adore",
            "bytes": [39, 97, 100, 111, 114, 101],
            "logprob": -0.25202933,
            "top_logprobs": [],
        },
        # ...
    ]
}
```

- **OpenAI ile uyumlu API'ler:** Yerel geliştirme ya da farklı servisleri deneme sırasında LM Studio, vLLM veya Ollama gibi OpenAI-uyumlu uç noktalarla çalışmak isteyebiliriz. `base_url` ile hedef adresi belirtebiliriz; sağlayıcıya özgü parametreler için de `extra_body` kullanılır. Burada uyumluluk, her servisin tüm özellikleri desteklediği anlamına gelmez; örneği kendi servisinizin ayarlarına göre uyarlamanız gerekir:

```python
model = ChatOpenAI(
    base_url="http://localhost:1234/v1",
    api_key="lm-studio",  # Herhangi bir string olabilir
    model="mlx-community/QwQ-32B-4bit",
    temperature=0,
    extra_body={
        "ttl": 300  # 5 dakika hareketsizlik sonrası modeli otomatik boşalt
    },
)
```

- **Prompt caching (istem önbellekleme):** Uzun ve tekrar eden istemlerle sık istek gönderiyorsak önbellekleme performans ve maliyet açısından fayda sağlayabilir. OpenAI uygun istemleri otomatik olarak önbelleğe alabilir; `prompt_cache_key` ise ilgili istekleri yönlendirme ve önbellek isabeti açısından düzenlemeye yardımcı olur. Etki, isteklerin yapısına ve sağlayıcının güncel davranışına bağlıdır:

```python
response = model.invoke(
    messages,
    prompt_cache_key="example-key-a",  # Aynı makineye yönlendirerek önbellek isabeti sağlar
)
```

Önbellekleme kullanımıyla ilgili ayrıntıları yanıtın `usage_metadata` alanında görebiliriz. Örneğin önbellekten okunan token bilgisi `input_token_details` altında yer alabilir. Dönen alanlar kullanılan API ve LangChain sürümüne bağlı olabileceğinden, uygulamanızda alanın mevcut olduğunu kontrol ederek okumak iyi olur.

- **Responses API ve konuşma durumu:** OpenAI'ın Responses API'sini kullanmak için `use_responses_api=True` ayarını açabiliriz. Önceki yanıtın kimliğini sonraki çağrıya `previous_response_id` olarak vererek konuşmayı sunucu tarafında sürdürebiliriz. Bu örnek, her çağrıda tüm konuşma geçmişini yeniden göndermek yerine önceki yanıta referans verme fikrini gösteriyor; kullandığınız modelin ve API ayarlarının bu akışı desteklediğinden emin olun:

```python
model = ChatOpenAI(
    model="...",
    use_responses_api=True,
    output_version="responses/v1",
)
response = model.invoke("Merhaba, benim adım Bob.")
second_response = model.invoke(
    "Adım neydi?",
    previous_response_id=response.response_metadata["id"],
)
print(second_response.text)
```

**Beklenen mock çıktı:**
```
"Adınız Bob. Bugün size nasıl yardımcı olabilirim, Bob?"
```

- **Reasoning özeti:** Responses API'yi destekleyen modellerde, modele ayrılan akıl yürütme çabasını ve sunulacak özet düzeyini yapılandırmak mümkün olabilir. Aşağıdaki ayarlar bu özelliğe örnek veriyor. Her model ve API yapılandırması aynı seçenekleri desteklemez; ayrıca burada görülen özet, modelin tüm iç sürecinin eksiksiz dökümü olarak değerlendirilmemelidir:

```python
reasoning = {
    "effort": "medium",  # 'low', 'medium', veya 'high'
    "summary": "auto",   # 'detailed', 'auto', veya None
}
model = ChatOpenAI(
    model="...", reasoning=reasoning, output_version="responses/v1"
)
response = model.invoke("3^3 kaçtır?")
```

**Beklenen mock çıktı:**
```
Output: 3³ = 27
Reasoning: Kullanıcı 3'ün 3. kuvvetini bilmek istiyor...
```

En iyisi, bu örneklerden küçük birini kendi projenizde deneyerek başlamak. Bir sonraki yazıda görüşmek dileğiyle.

## Kaynaklar

Burada kullandığımız parametrelerin ve özelliklerin sürümlere göre değişebileceğini unutmayın. Bir örneği kendi projenize taşırken, özellikle sağlayıcıya özgü seçenekleri resmi dokümantasyondan doğrulamak iyi bir son kontroldür.

- [LangChain Models Dokümantasyonu](https://docs.langchain.com/oss/python/langchain/models) – Model başlatma, parametreler, invocation yöntemleri, tool calling ve structured output
- [LangChain Agents Dokümantasyonu](https://docs.langchain.com/oss/python/langchain/agents) – `create_agent`, agent state, invocation ve streaming
- [ChatOpenAI Resmi Referansı](https://reference.langchain.com/python/langchain-openai/chat_models/base/ChatOpenAI) – `ChatOpenAI` sınıfının tam parametre listesi, `AIMessage` yapısı, tool calling, structured output, JSON mode, logprobs, prompt caching, Responses API ve OpenAI-uyumlu endpoint örnekleri