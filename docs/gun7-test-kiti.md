# Gün 7 — Gerçek cihaz testi ve Kapı 1 kararı

Amaç: en az iki telefonda kritik dokunma, kayıt ve ekran taşması hatası kalmadığını görmek, ardından
beş testçiyle ilk karar kapısını ölçmek.

> **Karar kapısı:** Beş testçiden en az dördü açıklama almadan 3. bölüme ulaşamıyorsa yeni içerik
> üretme; kontrolü ve öğretimi düzelt.

---

## 1. Oyunu telefona aç

**iPhone veya herhangi bir telefon (önerilen):** Safari/Chrome'da
**https://cagin-karatas.github.io/kervanya/** aç. Paylaş → *Ana Ekrana Ekle* dersen tam ekran açılır.
Testçilere de bu linki gönderebilirsin. Her `git push` sonrası link birkaç dakikada güncellenir.
İlerleme tarayıcıda saklanır; gizli sekmede kaydedilmez.

Web sürümünde fark: telefonun geri tuşu/hareketi tarayıcıya aittir (madde 13 web'de geçersiz).

### Android (APK)

`kervanya-debug.apk` (debug imzalı, arm64, ~28 MB). Sohbette ek olarak duruyor; en kolayı telefonda Claude uygulamasını açıp oradan indirmek. Mac'e indirirsen `~/Documents/Kervanya/build/android/` içine koy (`build/` git'e girmez).

**Kablo ile (en hızlı):**
1. Telefonda Ayarlar → Telefon hakkında → *Yapı numarası*na 7 kez dokun → Geliştirici seçenekleri → **USB hata ayıklama** aç.
2. Mac'te: `brew install android-platform-tools`
3. `adb install -r ~/Documents/Kervanya/build/android/kervanya-debug.apk`

**Kablosuz:** APK'yı kendine e-postala / Drive'a koy, telefonda aç, "bilinmeyen kaynaklardan yüklemeye" izin ver.

Hata olursa log al: `adb logcat -s godot > kervanya-log.txt`

## 2. Cihaz kontrol listesi (her telefon için)

**Otomatik oyun testi (25 Eylül):** `tools/playtest.gd` oyunu açılıştan başlatıp telefondaki gibi dokunma
olayları gönderdi: 10 bölüm baştan sona oynandı (hepsi 3 yıldız), kenar durumları, hamle bitimi, ipucu,
Türkçe, yeniden açılışta kayıt ve 4 farklı ekran oranı (9:16, 20:9, 3:5, 3:4 tablet) — **62 kontrolün
tamamı geçti**. Aşağıda "oto ✅" olan maddeler otomatik doğrulandı; telefonda yine de kısaca bak, asıl
odak işaretsiz maddeler ve *hissiyat* olsun. Otomatik testin bulduğu hata: sürüklenen parçanın gölgesi
bırakılınca alacağı yönden farklı görünüyordu → düzeltildi.

Cihaz: ______________  Android sürümü: ____  Ekran: ______

| # | Kontrol | Sonuç |
|---|---|---|
| 1 | Uygulama açılıyor, dikey kalıyor, çentik/alt çubuk butonları kapatmıyor | ☐ |
| 2 | Tahta ve tepsi ekrana sığıyor, hiçbir şey taşmıyor | ☐ |
| 3 | Parçayı tepsiden sürükleyip bırakmak ilk denemede çalışıyor | oto ✅ ☐ |
| 4 | Sürüklerken parça parmağın üstünde görünüyor, hedef kare yeşil/kırmızı yanıyor | oto ✅ ☐ |
| 5 | Yerleşik parçaya dokununca dönüyor; hafif kaydırma yanlışlıkla taşımaya dönüşmüyor | oto ✅ ☐ |
| 6 | Parçayı tahta dışına sürükleyince tepsiye dönüyor, sayı doğru artıyor | oto ✅ ☐ |
| 7 | Hızlı art arda dokunuş / iki parmak ile parça kaybolmuyor veya çoğalmıyor | oto ✅ ☐ |
| 8 | Sürüklerken ana ekrana çıkıp geri dönünce parça kaybolmuyor | oto ✅ ☐ |
| 9 | Geri al ve Baştan doğru çalışıyor | oto ✅ ☐ |
| 10 | Hamle bitince "Hamle bitti" ekranı geliyor; Tekrar dene çalışıyor | oto ✅ ☐ |
| 11 | Bölüm bitince yıldızlar görünüyor, sonraki bölüm açılıyor | oto ✅ ☐ |
| 12 | Uygulamayı tamamen kapatıp açınca ilerleme ve yıldızlar korunuyor | oto ✅ ☐ |
| 13 | Telefonun geri tuşu menüye döndürüyor, menüde uygulamadan çıkıyor | oto ✅ ☐ |
| 14 | Telefon Türkçe ise metinler Türkçe (İ, ş, ğ düzgün) | ☐ |
| 15 | 3 kez kaybedince soluk mavi ipucu yolu görünüyor | oto ✅ ☐ |
| 16 | Takılma / yavaşlama yok; 10 bölüm boyunca çökme yok | ☐ |

## 3. Testçi gözlem formu (5 kişi)

### Oyun içi test raporu (otomatik kayıt)
Oyun her testçinin bölüm başlangıcını, süresini, hamlelerini, döndürmelerini, başarısızlıklarını ve
ipucunu **cihazda** kaydeder (hiçbir şey internete gitmez, kişisel veri tutulmaz).

1. İlk testçiden önce: menüde **KERVANYA** yazısına 3 saniye içinde **5 kez dokun** → *Test raporu*.
2. Her testçiden sonra rapora gir → **Yeni testçi** → **Emin misin?** İlerleme sıfırlanır, sıradaki
   testçi 1. bölümden başlar; önceki testçilerin kaydı silinmez.
3. Beş testçi bitince raporda en üstte **"3. bölüme ulaşan testçi: x / 5"** yazar. **Kopyala** ile
   metni bana yapıştırabilirsin (kopyalama çalışmazsa ekran görüntüsü al).

Rapor objektif kısmı verir (süre, deneme, ilk denemede bitirme). Aşağıdaki tabloya senin gözlemin
girer: *yardımsız* mı ulaştı, nerede takıldı, döndürmeyi kendi mi keşfetti.


Kurallar: telefonu ver, **hiçbir şey açıklama**, sadece izle ve not al. Takılırsa 60 saniye bekle.
En sonda tek soru sor: *"Yarın tekrar oynamak ister misin?"*

| Testçi | Yaş | 1. bölümü yardımsız bitirdi | 3. bölüme yardımsız ulaştı | İlk takıldığı yer | Döndürmeyi kendisi keşfetti | Ulaştığı bölüm | Tekrar oynar mı |
|---|---|---|---|---|---|---|---|
| 1 | | ☐ | ☐ | | ☐ | | ☐ |
| 2 | | ☐ | ☐ | | ☐ | | ☐ |
| 3 | | ☐ | ☐ | | ☐ | | ☐ |
| 4 | | ☐ | ☐ | | ☐ | | ☐ |
| 5 | | ☐ | ☐ | | ☐ | | ☐ |

Dikkat edilecek anlar:
- Parçayı tepsiden **sürüklemek** yerine dokunmaya mı çalışıyor?
- Parçanın **kendiliğinden dönmesi** kafa karıştırıyor mu, yoksa fark edilmiyor mu?
- Hamle sayacına bakıyor mu? Hamle bitince şaşırıyor mu?
- Mavi pazar (8. bölüm) ilk görüldüğünde anlaşılıyor mu?

## 4. Kapı 1 sonucu

| Ölçüt | Hedef | Sonuç |
|---|---|---|
| 3. bölüme yardımsız ulaşan testçi | ≥ 4 / 5 | __ / 5 |
| Tekrar oynamak isteyen testçi | ≥ 3 / 5 (Kapı 2 hedefi) | __ / 5 |
| Kritik dokunma / kayıt / taşma hatası | 0 | __ |
| Geri alma parça çoğaltıyor | Hayır | __ |

**Karar:** ☐ Geç → Hafta 2 (6×6 ızgara ayarı, bölüm 11-20)  ☐ Düzelt → kontrol/öğretim iterasyonu

## 5. Hata listesi

| # | Cihaz | Adımlar | Beklenen | Olan | Önem (Kritik/Yüksek/Düşük) |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
