# 🚀 Lootea B2B Backend - Setup

Rychlá příručka pro spuštění projektu na **Windows PC**.

## 📋 Požadavky

### Nainstalujte:
1. **Git** - https://git-scm.com/download/win
2. **Docker Desktop** - https://www.docker.com/products/docker-desktop/
3. **Ruby 3.3.0** - https://rubyinstaller.org/ (WITH DevKit)
4. **VS Code** nebo **RubyMine**

---

## ⚡ Rychlý start (5 minut)

### 1️⃣ Clone repo
```bash
git clone <your-repo-url>
cd lootea-b2b-backend
```

### 2️⃣ Ruby dependencies
```bash
# Nainstaluj gems
bundle install

# Pokud bundle selže, zkus:
gem install bundler
bundle install
```

### 3️⃣ Database (Docker)
```bash
# Spusť PostgreSQL
docker-compose up -d postgres

# Počkej 10 sekund, pak vytvoř DB
rails db:create
rails db:migrate
rails db:seed
```

### 4️⃣ Start server
```bash
rails server
```

### 5️⃣ Test GraphQL
Otevři: http://localhost:3000/graphiql

---

## 🐛 Troubleshooting

### Ruby instalace problémy
```bash
# Pokud bundle install selže:
gem update --system
gem install bundler

# Pokud pg gem selže:
# Stáhni PostgreSQL binaries: https://www.postgresql.org/download/windows/
# Pak: gem install pg -- --with-pg-config="C:/Program Files/PostgreSQL/16/bin/pg_config.exe"
```

### Docker problémy
```bash
# Zkontroluj jestli běží:
docker ps

# Restart PostgreSQL:
docker-compose down
docker-compose up -d postgres
```

### Port konflikty
```bash
# Pokud port 3000 nebo 5432 je obsazený:
# Rails server na jiném portu:
rails server -p 4000

# PostgreSQL na jiném portu (změň docker-compose.yml):
ports:
  - "5433:5432"
```

---

## ✅ Ověření

### Test database
```bash
rails console
User.count  # => 0 (nebo kolik máš uživatelů)
Product.count
```

### Test GraphQL
V GraphiQL (http://localhost:3000/graphiql):
```graphql
query {
  products {
    id
    name
    priceDecimal
  }
}
```

---

## 🔧 Nástroje pro vývoj

### RuboCop (code formatting)
```bash
bundle exec rubocop
bundle exec rubocop -a  # autofix
```

### Git hooks (automatické)
```bash
# Pre-commit: RuboCop + whitespace cleanup
git commit -m "your message"
```

### Brakeman (security - je vypnutý pro rychlost)
```bash
bundle exec brakeman --config-file config/brakeman.yml
```

---

## 📚 Užitečné

### Rails příkazy
```bash
rails console          # Ruby konzole s aplikací
rails db:migrate        # Spusť migrace
rails db:seed          # Seed data
rails routes           # Seznam všech routes
```

### Docker příkazy
```bash
docker-compose up -d postgres     # Start DB
docker-compose down               # Stop vše
docker exec -it lootea_postgres psql -U postgres -d lootea_b2b_backend_development
```

---

## 🆘 Pomoc

- **Dokumentace:** `DEVELOPMENT_LOG.md`
- **GraphQL schema:** `app/graphql/`
- **Modely:** `app/models/`

**Pokud něco nefunguje, zkontroluj:**
1. Docker Desktop běží?
2. Ruby 3.3.0 nainstalováno?
3. Bundle install proběhl OK?
4. PostgreSQL kontainer běží? (`docker ps`)