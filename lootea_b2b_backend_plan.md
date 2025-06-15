
# 🚀 Lootea B2B Backend – Plán vývoje

Tento dokument definuje plán vývoje backendu pro projekt **Lootea B2B**, postavený na Ruby on Rails (API-only) + GraphQL + Devise JWT.

📝 **Poznámka:**
Vše budu psát **sám** s podporou AI, abych se vše naučil a pochopil do hloubky.

---

## ✅ Dosud hotovo
- Rails API-only projekt založen (`rails new`)
- Devise + devise-jwt nastaveno (autentizace, JWT signování)
- PostgreSQL napojeno
- GraphQL nainstalováno (`rails generate graphql:install`)
- Repo inicializováno (Git)
- **Modely + migrace** (User, Product, Order, OrderItem s validacemi a enums)
- **GraphQL typy/query/mutace** (všechny typy, login/register, produkty, objednávky)
- **Platby** (Comgate integrace, payOrder mutace, webhook zpracování)
- **Background joby** (ActiveJob pro webhooks, mailing příprava)
- **Centralizované služby** (JwtService pro token management)
- **Pokročilé GraphQL zabezpečení** (introspection blocking, query limits, monitoring)
- **Rate limiting** (Rack::Attack s SQL injection/XSS ochranou)
- **Modularizace kódu** (GraphQL concerns pro lepší organizaci)
- **Kompletní dokumentace** (GRAPHQL_SECURITY.md s Railway konfigurací)
- **Deploy na Railway** (automatický z main branch)

---

## 🚀 Co můžeme ještě udělat

1️⃣ **Testování**
- RSpec testy pro modely (validace, asociace, metody)
- GraphQL mutation/query testy
- Controller testy (webhooks, autentizace)
- Integration testy pro celé flow (registrace → objednávka → platba)
- Security testy (rate limiting, introspection blocking)

2️⃣ **CI/CD Pipeline**
- GitHub Actions pro automatické testování
- Linting (RuboCop) v pipeline
- Security scanning (Brakeman)
- Automatické deploy pouze při úspěšných testech

3️⃣ **Monitoring & Observability**
- Structured logging (JSON format)
- Application Performance Monitoring (APM)
- Error tracking (Sentry/Rollbar)
- Health check endpoints
- Metrics dashboard

4️⃣ **API Vylepšení**
- API versioning (v1, v2)
- GraphQL subscriptions (real-time updates)
- File upload handling
- Bulk operations (hromadné operace)
- Advanced filtering a sorting

5️⃣ **Security & Performance**
- Database indexy pro performance
- Query optimization
- Caching strategie (Redis)
- API dokumentace (GraphQL Playground)
- CORS konfigurace pro frontend

6️⃣ **Business Features**
- Email notifikace (ActionMailer + templates)
- Admin panel funkcionalita
- Inventory management
- Discount/coupon systém
- Multi-tenant support (pokud potřeba)

---

## 🌟 Cíle
- ✅ Naučit se psát vše ručně, bez generovaných boilerplate repozitářů
- ✅ Mít čistý, bezpečný, moderní stack
- ✅ Postavit API, které frontend (Next.js) pohodlně konzumuje
- 🔄 Přidat kompletní test coverage
- 🔄 Implementovat production-ready monitoring
- 🔄 Vytvořit robustní CI/CD pipeline

---

## 📌 Pravidlo
👉 Každý krok řeším v samostatném chatu, aby byl přehledný a strukturovaný.