# 🚀 Setup Guide pro LooteA B2B Backend

> **Rychlý start pro nové vývojáře a contributors**

## 📋 Požadavky

- Ruby 3.2+
- PostgreSQL 12+
- Git
- Text editor (VS Code doporučeno)

## 🛠️ Instalace krok za krokem

### 1️⃣ Klonování projektu
```bash
git clone https://github.com/your-username/eshop-b2b-backend.git
cd eshop-b2b-backend
```

### 2️⃣ Automatická instalace
```bash
./bin/setup
```

**Co setup script udělá:**
- ✅ Nainstaluje Ruby gems
- ✅ Zkontroluje credentials
- ✅ Připraví databázi
- ✅ Vyčistí temp soubory

### 3️⃣ Konfigurace credentials (DŮLEŽITÉ!)

**Pokud setup hlásí chybějící credentials:**

```bash
# Zkopírujte example
cp config/credentials.example.yml temp_credentials.yml

# Upravte temp_credentials.yml podle potřeby, pak:
EDITOR=nano rails credentials:edit
# Zkopírujte obsah z temp_credentials.yml do editoru
# Uložte a zavřete editor

# Smažte temp soubor
rm temp_credentials.yml
```

**Minimální konfigurace pro start:**
```yaml
devise_jwt_secret_key: "your_jwt_secret_32_chars_minimum"
```

### 4️⃣ Spuštění serveru
```bash
bin/rails server
# Nebo zkrácený:
bin/rails s
```

Server poběží na: http://localhost:3000

## 🔧 Vývoj

### GraphQL Playground
- URL: http://localhost:3000/graphiql
- Test query:
```graphql
{
  products {
    id
    name
    priceDecimal
  }
}
```

### Databázové změny
```bash
# Vytvoření migrace
bin/rails generate migration AddColumnToTable column:type

# Spuštění migrací
bin/rails db:migrate

# Rollback poslední migrace
bin/rails db:rollback
```

### Testování
```bash
# RSpec testy (až budou implementovány)
bundle exec rspec

# Code quality
bundle exec rubocop
```

## 🔐 Bezpečnost

### Environment variables (alternative k credentials)
```bash
# Vytvořte .env soubor:
echo "JWT_SECRET_KEY=$(rails secret)" >> .env
echo "COMGATE_MERCHANT_ID=your_id" >> .env
echo "COMGATE_SECRET=your_secret" >> .env
```

### Produkční deployment
- Necommitujte credentials.yml.enc
- Používejte environment variables na produkci
- Testujte nejdřív v Comgate sandbox módu

## 🆘 Časté problémy

### "Master key is missing"
```bash
# Přegenerujte credentials:
rm config/credentials.yml.enc config/master.key
rails credentials:edit
```

### "Database does not exist"
```bash
bin/rails db:create
bin/rails db:migrate
```

### "Webpacker compilation failed"
```bash
# Reinstalace dependencies
bundle install
```

### "Permission denied"
```bash
chmod +x bin/setup
chmod +x bin/rails
```

## 📚 Další kroky

1. **Přečtěte si dokumentaci:**
   - `GRAPHQL_GUIDE.md` - GraphQL API
   - `GRAPHQL_SECURITY.md` - Bezpečnost
   - `DEVELOPMENT_LOG.md` - Change log

2. **Nastavte IDE:**
   - Install Ruby extension
   - Configure Rubocop linter
   - Add GraphQL syntax highlighting

3. **Připojte se ke komunitě:**
   - Vytvořte issue při problémech
   - Navrhněte vylepšení přes PR
   - Dodržujte coding standards

---

**🎯 Máte problém?** Vytvořte [nový issue](https://github.com/your-username/eshop-b2b-backend/issues/new) s detailním popisem.