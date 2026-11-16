# game

Roblox oyunu. Kod bu depoda tutulur ve [Rojo](https://rojo.space) ile Roblox Studio'ya aktarılır.

## Klasör yapısı

| Klasör | Studio'daki yeri | Ne için |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | Sunucu kodu (oyun kuralları, veri kaydı) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | İstemci kodu (arayüz, girdi, kamera) |
| `src/shared` | `ReplicatedStorage.Shared` | İkisinin de kullandığı modüller (ayarlar vb.) |

Dosya adı kuralları: `*.server.luau` → Script, `*.client.luau` → LocalScript, `*.luau` → ModuleScript.

## Kurulum (bir kere)

1. [Roblox Studio](https://create.roblox.com)'yu kur.
2. Studio'da **Plugins → Manage Plugins** yerine Creator Store'dan **Rojo** eklentisini kur.
3. Bilgisayarına Rojo'yu kur: [Aftman](https://github.com/LPGhatguy/aftman) veya [Rokit](https://github.com/rojo-rbx/rokit) kuruluysa depo klasöründe `aftman install` (ya da `rokit install`). Alternatif: VS Code'a **Rojo** eklentisini kur, o da Rojo'yu kendisi indirir.
4. Depoyu klonla: `git clone https://github.com/hmcmete-cyber/game`

## Her çalışmada

1. Depo klasöründe en son kodu çek: `git pull`
2. Rojo sunucusunu başlat: `rojo serve`
3. Studio'da boş bir Baseplate aç → **Rojo** eklentisi → **Connect**.
4. **Play**'e bas. Output penceresinde `Sunucu hazır` yazısını ve skor tablosunda `Coins` görmelisin.

Kod değiştikçe Studio'ya otomatik yansır. Harita, model ve animasyonlar Studio'da yapılır ve `.rbxl` dosyası olarak kaydedilir (bu dosyalar depoya girmez).
