# 📚 Lootea B2B API Documentation

Kompletní dokumentace pro **Lootea B2B Backend** - Ruby on Rails API s GraphQL pro B2B e-commerce platformu specializovanou na bubble tea produkty.

## 🎯 Pro koho je tato dokumentace

- **Frontend vývojáři** - integrace s GraphQL API
- **Backend vývojáři** - rozšiřování a maintenance
- **Junior developeři** - učení se best practices
- **DevOps** - deployment a konfigurace

---

## 🚀 Quick Start

### 1. Základní setup
```bash
# Naklonuj projekt
git clone <repo-url>
cd eshop-b2b-backend

# Automatická instalace
./bin/setup

# Spusť server
bin/rails server
```

### 2. První kroky
1. **[Setup Guide](./docs/SETUP.md)** - detailní instalační návod
2. **[GraphQL Playground](http://localhost:3000/graphiql)** - testování API
3. **[Seed data](./db/seeds.rb)** - ukázková data pro vývoj

---

## 📖 Dokumentace

### 🔗 API Reference
Kompletní dokumentace GraphQL API a backend systémů:

- **[GraphQL API](./docs/api/graphql.md)** - queries, mutations, types s příklady
- **[Security Guide](./docs/api/security.md)** - JWT, rate limiting, query analysis
- **[Address System](./docs/api/addresses.md)** - správa adres s českými specifiky
- **[Inventory System](./docs/api/inventory.md)** - skladové hospodářství
- **[Bulk Pricing](./docs/api/bulk-pricing.md)** - množstevní slevy (1ks/1bal/10bal)
- **[Product Variants](./docs/api/variants.md)** - systém variant produktů

### 💻 Frontend Components
Průvodce pro frontend vývojáře:

- **[Authentication](./docs/components/auth.md)** - JWT autentizace, login/logout komponenty
- **[UI Components](./docs/components/ui.md)** - React komponenty pro e-shop
- **[Error Handling](./docs/components/errors.md)** - error handling patterns

### 📋 Development Guides
Návody pro vývojáře:

- **[Setup Guide](./docs/SETUP.md)** - instalace a konfigurace
- **[Development Log](./docs/DEVELOPMENT_LOG.md)** - historie vývoje projektu
- **[Frontend Guide](./docs/FRONTEND_GUIDE.md)** - kompletní frontend implementace

---

## 🏗️ Architektura systému

### 🛠️ Tech Stack
- **Backend:** Ruby on Rails 7.0 + GraphQL
- **Database:** PostgreSQL
- **Authentication:** JWT tokens
- **File Storage:** Active Storage
- **Payment:** Comgate gateway
- **Security:** Rack::Attack, query complexity analysis

### 📊 Klíčové systémy

#### ✅ Dokončené funkce
- **User Management** - registrace, přihlášení, role (admin/customer)
- **Product Catalog** - produkty s obrázky, specifikacemi
- **Inventory Management** - real-time skladové zásoby
- **Address System** - firemní adresy s IČO/DIČ validací
- **Bulk Pricing** - množstevní slevy pro B2B (1ks/1bal/10bal)
- **Product Variants** - příchutě, velikosti, barvy
- **Order Management** - objednávky s automatickou rezervací zásob
- **Payment Integration** - Comgate platební brána
- **File Uploads** - produktové obrázky, avatary, loga

#### 🔄 V plánu
- **Reporting & Analytics** - prodejní reporty
- **Multi-tenant Support** - více firem v jedné instanci
- **Advanced Search** - fulltextové vyhledávání
- **Email Notifications** - automatické emaily
- **Mobile API** - optimalizace pro mobilní aplikace

---

## 🎨 B2B Specifika

### České prostředí
- **IČO/DIČ validace** - kontrola formátu a kontrolních součtů
- **Firemní adresy** - fakturační, dodací, sídlo firmy
- **PSČ formátování** - automatické formátování "123 45"
- **Česká lokalizace** - chybové hlášky v češtině

### B2B funkce
- **Množstevní slevy** - standardní tiers 1ks/1bal/10bal
- **Firemní účty** - registrace s názvem firmy
- **Admin panel** - správa produktů, objednávek, uživatelů
- **Bulk operace** - hromadné úpravy zásob a cen

---

## 🔧 Development

### Spuštění pro vývoj
```bash
# Database setup
bin/rails db:create db:migrate db:seed

# Start server
bin/rails server

# GraphiQL playground
open http://localhost:3000/graphiql

# Run tests
bin/rspec
```

### Důležité příkazy
```bash
# Generování nových migrations
bin/rails generate migration AddFieldToModel field:type

# Console pro testování
bin/rails console

# RuboCop kontrola kódu
bin/rubocop

# Security audit
bin/brakeman
```

### Code Quality
- **RuboCop** - dodržování Ruby/Rails konvencí
- **Brakeman** - security audit
- **RSpec** - testování
- **GraphQL** - type safety
- **Concerns** - modulární architektura

---

## 📈 Statistiky projektu

### Aktuální stav
- **20+ modelů** - kompletní e-commerce funkcionalita
- **50+ GraphQL fields** - bohaté API
- **100% RuboCop compliance** - clean code
- **Senior-level architecture** - concerns, best practices
- **Production-ready** - Railway deployment

### Výkonnost
- **Query complexity analysis** - ochrana před drahými queries
- **Database indexy** - optimalizované vyhledávání
- **Eager loading** - prevence N+1 problémů
- **Caching** - Redis pro session a cache

---

## 🚢 Deployment

### Railway (Production)
```bash
# Automatický deployment při push na main
git push origin main

# Railway CLI
railway login
railway deploy
```

### Environment Variables
```env
DATABASE_URL=postgresql://...
RAILS_MASTER_KEY=...
COMGATE_MERCHANT_ID=...
COMGATE_SECRET=...
CORS_ORIGINS=https://yourdomain.com
```

---

## 🤝 Contributing

### Workflow
1. **Fork** repository
2. **Create feature branch** - `git checkout -b feature/amazing-feature`
3. **Follow code standards** - RuboCop, tests
4. **Commit changes** - conventional commits
5. **Push to branch** - `git push origin feature/amazing-feature`
6. **Open Pull Request**

### Code Standards
- **Ruby/Rails conventions** - follow RuboCop rules
- **GraphQL best practices** - proper types, descriptions
- **Test coverage** - RSpec for new features
- **Documentation** - update relevant .md files
- **Security** - never commit secrets

---

## 📞 Support

### Kontakt
- **GitHub Issues** - bug reports, feature requests
- **Documentation** - [docs/](./docs/) folder
- **GraphQL Playground** - http://localhost:3000/graphiql

### Užitečné odkazy
- **[Rails Guides](https://guides.rubyonrails.org/)**
- **[GraphQL Ruby](https://graphql-ruby.org/)**
- **[PostgreSQL Docs](https://www.postgresql.org/docs/)**
- **[Railway Docs](https://docs.railway.app/)**

---

## 📄 License

Tento projekt je licencován pod MIT License - viz [LICENSE](LICENSE) soubor pro detaily.

---

## 🎉 Acknowledgments

- **Ruby on Rails** - amazing framework
- **GraphQL Ruby** - excellent GraphQL implementation
- **Railway** - simple deployment platform
- **Czech B2B community** - inspiration for features

---

*Dokumentace aktualizována: 18.6.2025*

**Happy coding! 🚀**
