# Lisans ve varlık envanteri (plan §11 "Telif/lisans kaydı", §17 "Lisans envanteri")

| Varlık | Kaynak | Lisans / hak |
|---|---|---|
| Kod (`scripts/`, `tests/`, `tools/`) | Proje içinde yazıldı | Proje sahibinin |
| Görseller (tahta, parçalar, binalar, kervan) | Kodla çizilir (`_draw`), dosya yok | Proje sahibinin |
| Ses efektleri `assets/audio/sfx/*.wav` (21) | `tools/gen_audio.py` ile sentezlendi; örnek/kayıt kullanılmadı | Proje sahibinin |
| Müzik `assets/audio/music/*.ogg` (3 döngü) | `tools/gen_audio.py` ile sentezlendi (Hicaz, D majör pentatonik) | Proje sahibinin |
| Yazı tipi | Godot varsayılan yazı tipi | Godot ile birlikte (MIT / OFL), mağaza beyanında belirt |
| Godot Engine 4.7 | godotengine.org | MIT — "Godot Engine" lisans metni oyunda/ mağaza sayfasında anılmalı |

Ses paketi yeniden üretimi: `python3 tools/gen_audio.py` (ffmpeg gerekir). Aynı komut aynı dosyaları üretir.
Gerçek ses tasarımcısı / sanatçı varlıkları geldiğinde bu tabloya kaynak ve lisans satırı eklenmeli.
