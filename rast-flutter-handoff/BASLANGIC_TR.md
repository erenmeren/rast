# rast — tasarım ve Flutter/Dart devir paketi

Bu ZIP, beğendiğin güncel tasarımı ve başka bir AI ile Flutter/Dart uygulamasına dönüştürmek için gereken planı içerir. Dark mode, kalıcı bağlantı kaldırma, şikâyet, 2 dakikaya kadar konum hedefi, 1 güne kadar görünme gecikmesi ve karışık Discover sırası dâhildir.

## İlk olarak

ZIP'i diğer AI'a yükle ve şu mesajı gönder:

> Bu ZIP içindeki START_HERE.md ve AI_HANDOFF_PROMPT.md dosyalarını oku. Mevcut rast tasarımını ve ürün kurallarını koruyarak Flutter/Dart ile Android ve iOS uygulamasını geliştir. Önce planı ve belirsiz üretim kararlarını incele; sonra aşamalar halinde ilerle. Ekranları native Flutter widget'larıyla oluştur.

Daha ayrıntılı hazır yönerge `AI_HANDOFF_PROMPT.md` dosyasındadır. Teknik belgeler ve uygulama içi yazılar İngilizcedir.

## Hangi dosyalar önemli?

- `prototype/`: Çalışan tasarımın HTML, CSS, JavaScript kaynakları; fotoğraflar, yazı tipleri ve mevcut testler.
- `docs/01_PRODUCT_SPEC.md`: Uygulamanın özellikleri ve kesinleşmiş kurallar.
- `docs/02_SCREEN_MAP.md`: Ekranlar, alt menüler, durumlar ve Flutter karşılıkları.
- `docs/03_FLUTTER_IMPLEMENTATION_PLAN.md`: Aşamalı Flutter/Dart geliştirme planı.
- `docs/04_ARCHITECTURE_AND_DATA.md`: Mobil uygulama yapısı, veri modelleri ve backend/API taslağı.
- `docs/05_ACCEPTANCE_CRITERIA.md`: “Tamamlandı” demek için kontrol edilecek davranışlar.
- `docs/06_DESIGN_SYSTEM.md` ve `design/tokens.json`: Tasarım dili, renkler, boyutlar ve light/dark tema.
- `design/icons/`: Ayrı SVG dosyaları olarak 36 ikon.
- `design/flutter-assets/fonts/`: Flutter'a eklenebilecek Plus Jakarta Sans TTF dosyası, lisansı ve kullanım örneği.

## Tasarımı bilgisayarında açmak

Önce ZIP'i çıkart. Terminali çıkan `rast-flutter-handoff` klasöründe aç.

Mac/Linux:

```sh
python3 tools/preview.py
```

Windows:

```powershell
py tools/preview.py
```

Tarayıcıda `http://127.0.0.1:8020` açılır. Durdurmak için Ctrl+C kullan. Python 3 gereklidir; web tasarımı için npm kurulumu yoktur.

Doğrudan `index.html` dosyasına çift tıklamak yerine bu komutu kullan; tasarım JavaScript modülleri içerir. İnternet olmadan yerel görsellerle çalışabilir.

## Planın mantığı

Önce gerçek iPhone ve Android cihazlarda konum davranışı ölçülür. Ardından tema ve ortak bileşenler, giriş/kurulum, açıklama animasyonu, Discover/Likes You, eşleşme/sohbet ve güvenlik akışları Flutter'a taşınır. Sonraki aşamalarda gerçek backend, SMS doğrulama, konum işleme ve abonelik bağlanır.

20 metre, iki kullanıcının merkezleri arasındaki mesafedir. İki 20 metrelik dairenin sadece birbirine değmesi 40 metreye denk gelebilir; pakette seçilmiş kural bu değildir. Karşılıklı filtre ve iki kullanıcının daha uzun gecikme tercihi korunur. Bağlantı kaldırma, gerçek uygulamada sunucuda iki hesap arasında kalıcı olarak uygulanmalıdır.

## Paketin kapsamı

Bu paket **mevcut çalışan web tasarımı + Flutter/Dart uygulama planıdır**. Henüz Flutter projesi, APK/IPA veya gerçek backend değildir. Web prototipindeki SMS, konum, sohbet, rapor ve ödeme davranışları simülasyondur. Backend sağlayıcısı, gerçek cihaz konum eşikleri ve yayın öncesi bazı ürün kararları belgelerde ayrıca belirtilmiştir.

Tasarımın kaynak sürümü: 6. Hazırlama tarihi: 20 Ekim 2026.

