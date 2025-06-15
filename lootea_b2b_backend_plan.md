
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

---

## 🚀 Další kroky

1️⃣ **Modely + migrace**
- Vytvořit Product model (name, description, price_cents, currency, available)
- Vytvořit Order model (user, total_cents, currency, status enum)
- Vytvořit OrderItem model (order, product, quantity, unit_price_cents)

2️⃣ **GraphQL typy / query / mutace**
- ProductType, OrderType, OrderItemType
- Query pro seznam produktů
- Mutation pro vytvoření objednávky
- Login mutace pro zákazníky a adminy

3️⃣ **Platby**
- Service objekt pro Comgate integraci
- Mutation `payOrder` → vrací URL pro redirect
- Webhook route pro Comgate callback → job zpracuje výsledek

4️⃣ **Background joby**
- ActiveJob na webhook zpracování
- Příprava na mailing (např. potvrzení objednávky)

5️⃣ **CI/CD + hosting**
- Deploy na Railway
- GitHub Actions pipeline
- Env proměnné pro JWT, DB apod.

---

## 🌟 Cíle
- Naučit se psát vše ručně, bez generovaných boilerplate repozitářů
- Mít čistý, bezpečný, moderní stack
- Postavit API, které frontend (Next.js) pohodlně konzumuje

---

## 📌 Pravidlo
👉 Každý krok řeším v samostatném chatu, aby byl přehledný a strukturovaný.

