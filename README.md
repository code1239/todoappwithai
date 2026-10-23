# 🗓️ Todo App with AI

Set your weekly goals and let AI handle the rest. 🤖

This project is a personal planner where you set weekly goals, let an AI assistant
build your schedule through natural conversation, and get end-of-day reviews with
suggestions to keep you on track. The backend is a **Django REST API** and the client
is a **Flutter** mobile app.

## ✨ Features

- **Today screen** – manage the day's tasks as timed blocks or free list items
- **Week screen** – weekly goals (count- or minutes-based) with progress tracking
- **AI chat** – say "I want to work out 3 times a week", and the assistant asks a few
  questions, drafts a weekly goal plus daily tasks, and applies them to your plan on approval
- **AI proposals** – request an end-of-day review or a plan reorganization suggestion,
  then apply it in one tap
- **User accounts** – JWT-based registration and login
- **Data encryption** – task/goal titles are stored with field-level Fernet encryption
  (AES-CBC-HMAC); long-running chat summaries are refreshed each session update

## 🧰 Tech Stack

| Layer    | Technology                                             |
| -------- | ------------------------------------------------------ |
| Backend  | Django 6, Django REST Framework, SimpleJWT              |
| Database | SQL Server (MSSQL) • `mssql-django` / `pyodbc`          |
| AI       | OpenAI API (structured JSON output for plan building)   |
| Client   | Flutter + Riverpod + Dio                                |
| Security | Fernet field encryption, secrets managed via `.env`     |

## 📁 Project Structure

```
├── backend/          # Django REST API
│   ├── accounts/     # Registration / user profiles
│   ├── planner/      # Tasks and weekly goals
│   ├── ai/           # AI chat and plan proposals
│   ├── config/       # Settings, Fernet encryption, URL routing
│   ├── scripts/      # DB setup / encryption helper scripts
│   └── Dockerfile
├── app/              # Flutter client (Android + Web)
└── .env.example      # Environment variable template
```

## 🚀 Getting Started

### 1) Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt

# Create the .env file to run the project
copy ..\.env.example .env     # then fill in the values
```

The `.env` file needs:

- `DJANGO_SECRET_KEY` – Django secret key
- `DB_*` – SQL Server connection details
- `ENC_KEY` – Fernet key
  (`python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`)
- `OPENAI_API_KEY` – your OpenAI API key

If you want to spin up MSSQL via Docker:

```bash
docker run -d --name todo-mssql -e "ACCEPT_EULA=Y" ^
  -e "MSSQL_SA_PASSWORD=<DB_PASSWORD>" -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```

Then create the database and start the server:

```bash
python scripts/create_db.py   # creates an empty DB on MSSQL
python manage.py migrate
python manage.py runserver
```

### 2) Flutter Client

```bash
cd app
flutter pub get
flutter run
```

You can set the API address inside the app:

- Default for the Android emulator: `http://10.0.2.2:8000/api`
- For a real device connected over USB: run `adb reverse tcp:8000 tcp:8000` and use
  `http://127.0.0.1:8000/api`

### 3) Backend with Docker

```bash
cd backend
docker build -t todoapi .
docker run --rm -p 8000:8000 --env-file ../.env todoapi
```

## 🔒 Security

- Real keys and passwords **never live in the repository**; everything is read from
  the `.env` file, which is excluded via `.gitignore`.
- Task and goal titles are stored encrypted (`config/encryption.py`).
- API endpoints are protected by JWT authentication (`IsAuthenticated` by default).

## 📄 License

A personal / learning project. Opensource and free to use or adapt.
