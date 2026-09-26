# Kervanya — Gri prototip (Kapı 1)

Godot 4.5 ile dikey mobil yol bulmacası. Bu depo üretim planındaki **"Hemen başlama planı: İlk 7 gün"** kapsamının 1-6. günlerini içerir.

## Durum

| Gün | Çıktı | Durum |
|---|---|---|
| 1 | Proje iskeleti, dikey ekran (1080×1920), sürüm kontrolü, Android export ayarı | ✅ |
| 2 | Izgara veri modeli (`BoardModel`) ve ölçeklenen tahta çizimi | ✅ |
| 3 | Düz ve köşe parça, 90° döndürme; bağlantılar veriden okunur (`TileDefs`) | ✅ |
| 4 | Tek parmak sürükle-bırak, geri alma; parça kaybı/çoğalması fuzz testiyle doğrulandı | ✅ |
| 5 | Rota doğrulayıcı (`RouteSolver`) ve otomatik kazanma kontrolü | ✅ |
| 6 | 3 öğretim bölümü + 7 bölüm daha (toplam 10), sonuç ekranı, yıldız, kayıt | ✅ |
| 7 | En az iki gerçek telefonda test ve hata listesi — [test kiti](docs/gun7-test-kiti.md) | ⏳ senin sıran |

## Oynanış kuralları (prototip)

- Tepsiden parçayı sürükle, boş kareye bırak → **1 hamle**. Parça komşularına bağlanacak yöne kendiliğinden döner.
- Yerleşik parçaya dokun → saat yönünde döner, **1 hamle**.
- Yerleşik parçayı başka kareye sürükle → **1 hamle**; tahta dışına/tepsiye sürükle → tepsiye döner, **0 hamle**.
- **Geri al** son işlemi ve hamlesini iade eder. Hamle biterse bölüm kaybedilir.
- Yeşil köy → kırmızı bayrak. Mavi pazar varsa o da rotada olmalı.
- Aynı bölümde 3 başarısızlıktan sonra soluk mavi çözüm yolu (gizli yardım) görünür.

## Test kaydı (analitik)

`AnalyticsService` üretim planı §10'daki olayları ortak alanlarıyla (`event_time`, `app_version`, `platform`,
`country`, `session_id`, `local_player_id`, `content_pack_version`, `experiment_group`) cihazda
`user://analytics/events.jsonl` dosyasına yazar. Ağ gönderimi yok; serbest metin ve kişisel veri reddedilir.
Gizli **Test raporu** ekranı: menüde başlığa 3 sn içinde 5 dokunuş (`kervanya/test_tools` ayarı açıkken).
Yayın sürümünde `project.godot` içinde `kervanya/test_tools=false` yapılacak.

## Klasör yapısı

```
scenes/            boot, level_select, puzzle_board, result_screen (.tscn)
scripts/core/      TileDefs, LevelData, BoardModel, RouteSolver  (saf mantık, test edilir)
scripts/autoload/  SaveManager, GameState, SceneRouter
scripts/scenes/    ekran scriptleri
scripts/ui/        PuzzleCanvas (çizim + giriş), UiKit, StarRow
levels/            level_001.json … level_010.json
localization/      strings.csv (tr / en)
tests/             run_tests.gd  (otomatik testler)
tools/             bake_levels.gd (solver ile hamle dengesi), screenshot_tour.gd
```

## Çalıştırma

1. Godot 4.5+ kur (https://godotengine.org/download).
2. Godot → **Import** → bu klasördeki `project.godot`.
3. **F5** ile çalıştır. Masaüstünde fare, telefonu taklit eder.

## Testler

```bash
godot --headless --path . --import          # ilk seferde
godot --headless --path . -s tests/run_tests.gd
```
11 test grubu / 259 kontrol: parça döndürme, bölüm şeması, çözülebilirlik, solver = oyun rotası,
reklamsız 3 yıldız, hamle ve geri alma kuralları, geçersiz bırakmalar, 1.500 adımlık rastgele fuzz
(parça kaybı/çoğalması yok), determinizm, hamle bitişi, kayıt + bozuk kayıttan kurtarma.

## Otomatik oyun testi

Oyunu gerçek dokunma olaylarıyla oynar ve ekran görüntüsü alır (sanal ekran gerekir):

```bash
godot --path . --resolution 540x960 -s tools/playtest.gd -- /tmp/kervanya-shots full     # 10 bölüm + kenar durumları
godot --path . --resolution 540x960 -s tools/playtest.gd -- /tmp/kervanya-shots persist  # kayıt korunuyor mu
godot --path . --resolution 540x1200 -s tools/playtest.gd -- /tmp/kervanya-shots layout  # ekran oranı
```

## Yeni bölüm ekleme

1. `levels/level_011.json` oluştur (var olan bir dosyayı kopyala). `move_slack`, `tile_pool`, hücreleri düzenle.
2. `godot --headless --path . -s tools/bake_levels.gd` → solver `minimum_solution_moves`, `move_limit`,
   `star_thresholds` ve `solution` alanlarını yazar. Çözümsüz bölümde hata verir.
3. Testleri çalıştır.

## Telefonda oynama: web sürümü

Her `main` push'unda GitHub Actions testleri çalıştırır, web sürümünü derler ve yayınlar:
**https://cagin-karatas.github.io/kervanya/** (iPhone Safari dahil her telefonda çalışır).

Tek seferlik ayar: GitHub'da repo → **Settings → Pages → Source: GitHub Actions**.
Yerelde denemek için: Project → Export → **Web** → `build/web/index.html`, sonra
`cd build/web && python3 -m http.server` ve tarayıcıda `localhost:8000`.

## Android'de deneme (Gün 7)

Hazır debug APK sohbette ek olarak paylaşıldı (git'e girmez). Kurulum ve test adımları: **[docs/gun7-test-kiti.md](docs/gun7-test-kiti.md)**.

Kendin derlemek istersen:


1. Godot → Editor → **Manage Export Templates** → indir.
2. Editor Settings → Export → Android: Java SDK ve Android SDK yolunu ver (Android Studio ile gelir).
3. Project → Export → **Android** (hazır ön ayar, `com.kervanya.game`) → debug APK üret veya
   telefon USB ile bağlıyken üstteki Android simgesiyle doğrudan çalıştır.
4. Paket adı taslaktır; marka kontrolünden sonra değişecek (planın 1-2. görevleri).

iOS için Xcode + Apple Developer hesabı gerekir; TestFlight yapısı planın 5. görevidir.

## Kapı 1 kontrol listesi (Gün 7)

- [ ] Beş testçiden en az dördü açıklama almadan 3. bölüme ulaşıyor
- [ ] Gerçek telefonda dokunma sorunu yok
- [ ] Geri alma parça çoğaltmıyor (otomatik test ✅, elle de dene)
- [ ] İlerleme uygulama kapatılıp açılınca korunuyor
