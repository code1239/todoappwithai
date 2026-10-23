# 🗓️ Todo App with AI

Haftalık hedeflerini belirlersin, gerisi yapay zekâya kalsın. 🤖

Bu proje; haftalık hedef koyup gününü planlamanı, yapay zekâ asistanıyla sohbet ederek
planını senin yerine kurgulatan, yapamadıklarını gün sonunda değerlendirip toparlayan
kişisel planlayıcıdır. Backend **Django REST API**, istemci ise **Flutter** mobil
uygulamasıdır.

## ✨ Özellikler

- **Günüm ekranı** – o günkü görevlerini saatli bloklar veya serbest liste olarak yönet
- **Haftam ekranı** – haftalık hedefler (adet veya dakika bazlı) ve ilerleme takibi
- **AI sohbet** – "haftada 3 kere spor yapmak istiyorum" de, asistan sorular sorup
  senin için hedef + günlük görev taslağı hazırlar; onaylarsan planına işler
- **AI önerileri** – gün sonu değerlendirmesi veya planı yeniden düzenleme önerisi
  al, uygulanmayı bekle
- **Kullanıcı hesapları** – JWT tabanlı kayıt/giriş
- **Veri şifreleme** – görev/hedef başlıkları Fernet ile alan bazlı (AES-CBC-HMAC)
  şifrelenerek saklanır, kalıcı sohbet özetleri her seans güncellemesinde yenilenir

## 🧰 Teknoloji Yığını

| Katman     | Teknoloji                                            |
| ---------- | ---------------------------------------------------- |
| Backend    | Django 6, Django REST Framework, SimpleJWT            |
| Veritabanı | SQL Server (MSSQL) • `mssql-django` / `pyodbc`        |
| Yapay Zekâ | OpenAI API (Function-style JSON çıktı ile plan kurma) |
| İstemci    | Flutter + Riverpod + Dio                             |
| Güvenlik   | Fernet alan şifreleme, .env ile gizli bilgi yönetimi |

## 📁 Proje Yapısı

```
├── backend/          # Django REST API
│   ├── accounts/     # Kayıt / kullanıcı profili
│   ├── planner/      # Görevler ve haftalık hedefler
│   ├── ai/           # AI sohbet ve plan önerileri
│   ├── config/       # Ayarlar, Fernet şifreleme, URL yönlendirme
│   ├── scripts/      # DB kurulum/şifreleme yardımcı betikleri
│   └── Dockerfile
├── app/              # Flutter istemcisi (Android + Web)
└── .env.example      # Ortam değişkeni şablonu
```

## 🚀 Kurulum

### 1) Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt

# Projeyi çalıştırmak için .env oluştur
copy ..\.env.example .env     # sonra değerleri doldur
```

`.env` içinde şunların olması gerek:

- `DJANGO_SECRET_KEY` – Django gizli anahtarı
- `DB_*` – SQL Server bağlısantı bilgileri
- `ENC_KEY` – Fernet anahtarı
  (`python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`)
- `OPENAI_API_KEY` – OpenAI anahtarı

MSSQL'i Docker ile başlatmak isterseniz:

```bash
docker run -d --name todo-mssql -e "ACCEPT_EULA=Y" ^
  -e "MSSQL_SA_PASSWORD=<DB_PASSWORD>" -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```

Sonra veritabanını oluştur ve sunucuyu çalıştır:

```bash
python scripts/create_db.py   # MSSQL üstünde boş DB yaratır
python manage.py migrate
python manage.py runserver
```

### 2) Flutter İstemcisi

```bash
cd app
flutter pub get
flutter run
```

Uygulama içinden API adresini ayarlayabilirsin:

- Android emülatörü için varsayılan: `http://10.0.2.2:8000/api`
- USB ile bağlı gerçek cihazda: `adb reverse tcp:8000 tcp:8000` sonrası
  `http://127.0.0.1:8000/api`

### 3) Docker ile Backend

```bash
cd backend
docker build -t todoapi .
docker run --rm -p 8000:8000 --env-file ../.env todoapi
```

## 🔒 Güvenlik

- Gerçek anahtar ve şifreler **repoda yer almaz**; hepsi `.env` dosyasından okunur ve
  `.env` `.gitignore` ile dışarıda tutulur.
- Görev ve hedef başlıkları veritabanında şifreli saklanır (`config/encryption.py`).
- API uçları varsayılan olarak `IsAuthenticated` (JWT) ile korunur.

## 📄 Lisans

Kişisel/öğrenme amaçlı projedir. Kullanılması ve uyarlanması serbesttir.
