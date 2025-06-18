# 📍 Address Management System

Kompletní systém pro správu adres v B2B e-commerce aplikaci s českými specifiky a validacemi.

## 📋 Obsah
- [🏗️ Architektura systému](#️-architektura-systému)
- [📊 Databázová struktura](#-databázová-struktura)
- [🎯 Business logika](#-business-logika)
- [🔧 GraphQL API](#-graphql-api)
- [💻 Frontend integrace](#-frontend-integrace)
- [🧪 Testování](#-testování)

---

## 🏗️ Architektura systému

### Účel systému
Address Management System poskytuje robustní správu adres pro B2B zákazníky s důrazem na:
- **České B2B specifika** - IČO, DIČ, firemní adresy
- **Flexibilní typy adres** - fakturační, dodací, sídlo firmy
- **Validace a formátování** - PSČ, telefony, IČO/DIČ
- **Default address management** - automatická správa výchozích adres

### Klíčové funkce
- ✅ **Vícenásobné adresy** - jeden uživatel může mít více adres
- ✅ **Typizované adresy** - billing, shipping, company_headquarters
- ✅ **Default address logic** - automatická správa výchozích adres
- ✅ **Czech validation** - PSČ, IČO, DIČ validace
- ✅ **Phone formatting** - automatické formátování telefonních čísel
- ✅ **GraphQL integration** - kompletní CRUD operace

---

## 📊 Databázová struktura

### Address Model
```sql
CREATE TABLE addresses (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),

  -- Address type and metadata
  address_type VARCHAR(50) NOT NULL DEFAULT 'billing',
  is_default BOOLEAN NOT NULL DEFAULT FALSE,

  -- Company information
  company_name VARCHAR(200),
  ico VARCHAR(20),              -- IČO (Identifikační číslo organizace)
  dic VARCHAR(20),              -- DIČ (Daňové identifikační číslo)

  -- Address details
  street VARCHAR(200) NOT NULL,
  city VARCHAR(100) NOT NULL,
  postal_code VARCHAR(20) NOT NULL,
  country VARCHAR(100) NOT NULL DEFAULT 'Česká republika',

  -- Contact information
  phone VARCHAR(50),
  email VARCHAR(255),

  -- Additional info
  note TEXT,

  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_user_type ON addresses(user_id, address_type);
CREATE INDEX idx_addresses_user_default ON addresses(user_id, is_default);
CREATE INDEX idx_addresses_ico ON addresses(ico) WHERE ico IS NOT NULL;
```

### Database Constraints
```sql
-- Address type validation
ALTER TABLE addresses ADD CONSTRAINT chk_address_type
CHECK (address_type IN ('billing', 'shipping', 'company_headquarters'));

-- Postal code format (Czech)
ALTER TABLE addresses ADD CONSTRAINT chk_postal_code_format
CHECK (postal_code ~ '^[0-9]{3}\s?[0-9]{2}$');

-- IČO format validation
ALTER TABLE addresses ADD CONSTRAINT chk_ico_format
CHECK (ico IS NULL OR ico ~ '^[0-9]{8}$');

-- DIČ format validation
ALTER TABLE addresses ADD CONSTRAINT chk_dic_format
CHECK (dic IS NULL OR dic ~ '^CZ[0-9]{8,10}$');

-- Only one default address per type per user
CREATE UNIQUE INDEX idx_unique_default_address
ON addresses(user_id, address_type)
WHERE is_default = TRUE;
```

### Business Logic
```ruby
# app/models/address.rb
class Address < ApplicationRecord
  belongs_to :user

  enum address_type: {
    billing: 'billing',
    shipping: 'shipping',
    company_headquarters: 'company_headquarters'
  }

  validates :street, presence: true, length: { maximum: 200 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :postal_code, presence: true, format: { with: /\A\d{3}\s?\d{2}\z/ }
  validates :ico, format: { with: /\A\d{8}\z/ }, allow_blank: true
  validates :dic, format: { with: /\ACZ\d{8,10}\z/ }, allow_blank: true

  def full_address
    [street, "#{postal_code} #{city}", country].compact.join(', ')
  end

  def make_default!
    transaction do
      user.addresses.where(address_type: address_type).update_all(is_default: false)
      update!(is_default: true)
    end
  end
end
```

---

## 🔧 GraphQL API

### AddressType
```graphql
type Address {
  id: ID!
  addressType: String!
  isDefault: Boolean!
  companyName: String
  ico: String
  dic: String
  street: String!
  city: String!
  postalCode: String!
  country: String!
  phone: String
  email: String
  fullAddress: String!
  createdAt: String!
  updatedAt: String!
}
```

### Mutations
```graphql
# Vytvoření adresy
mutation CreateAddress {
  createAddress(
    addressType: "billing"
    street: "Václavské náměstí 1"
    city: "Praha"
    postalCode: "110 00"
    companyName: "Firma s.r.o."
    ico: "12345678"
    dic: "CZ12345678"
    isDefault: true
  ) {
    address {
      id
      fullAddress
      isDefault
    }
    errors
  }
}

# Aktualizace adresy
mutation UpdateAddress {
  updateAddress(
    id: "1"
    street: "Nová ulice 123"
    isDefault: true
  ) {
    address {
      id
      fullAddress
    }
    errors
  }
}
```

---

## 💻 Frontend integrace

### React Address Form
```tsx
interface AddressFormProps {
  address?: Address;
  onSubmit: (address: AddressInput) => void;
}

export default function AddressForm({ address, onSubmit }: AddressFormProps) {
  const [formData, setFormData] = useState({
    addressType: address?.addressType || 'billing',
    street: address?.street || '',
    city: address?.city || '',
    postalCode: address?.postalCode || '',
    companyName: address?.companyName || '',
    ico: address?.ico || '',
    dic: address?.dic || '',
    isDefault: address?.isDefault || false
  });

  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit(formData); }}>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label>Typ adresy</label>
          <select
            value={formData.addressType}
            onChange={(e) => setFormData(prev => ({ ...prev, addressType: e.target.value }))}
          >
            <option value="billing">Fakturační</option>
            <option value="shipping">Dodací</option>
            <option value="company_headquarters">Sídlo firmy</option>
          </select>
        </div>

        <div>
          <label>Název firmy</label>
          <input
            type="text"
            value={formData.companyName}
            onChange={(e) => setFormData(prev => ({ ...prev, companyName: e.target.value }))}
            placeholder="Firma s.r.o."
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label>IČO</label>
          <input
            type="text"
            value={formData.ico}
            onChange={(e) => setFormData(prev => ({ ...prev, ico: e.target.value }))}
            placeholder="12345678"
            pattern="[0-9]{8}"
          />
        </div>

        <div>
          <label>DIČ</label>
          <input
            type="text"
            value={formData.dic}
            onChange={(e) => setFormData(prev => ({ ...prev, dic: e.target.value }))}
            placeholder="CZ12345678"
          />
        </div>
      </div>

      <div>
        <label>Ulice *</label>
        <input
          type="text"
          value={formData.street}
          onChange={(e) => setFormData(prev => ({ ...prev, street: e.target.value }))}
          placeholder="Václavské náměstí 1"
          required
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label>Město *</label>
          <input
            type="text"
            value={formData.city}
            onChange={(e) => setFormData(prev => ({ ...prev, city: e.target.value }))}
            placeholder="Praha"
            required
          />
        </div>

        <div>
          <label>PSČ *</label>
          <input
            type="text"
            value={formData.postalCode}
            onChange={(e) => setFormData(prev => ({ ...prev, postalCode: e.target.value }))}
            placeholder="110 00"
            pattern="[0-9]{3}\s?[0-9]{2}"
            required
          />
        </div>
      </div>

      <div>
        <label>
          <input
            type="checkbox"
            checked={formData.isDefault}
            onChange={(e) => setFormData(prev => ({ ...prev, isDefault: e.target.checked }))}
          />
          Nastavit jako výchozí adresu
        </label>
      </div>

      <button type="submit" className="btn-primary">
        {address ? 'Aktualizovat' : 'Vytvořit'} adresu
      </button>
    </form>
  );
}
```

---

## 🧪 Testování

### GraphQL Testing
```graphql
# Test vytvoření adresy
mutation TestCreateAddress {
  createAddress(
    addressType: "billing"
    street: "Testovací 123"
    city: "Praha"
    postalCode: "12345"
    companyName: "Test s.r.o."
    ico: "12345678"
  ) {
    address {
      id
      fullAddress
      isDefault
    }
    errors
  }
}

# Test získání adres
query TestGetAddresses {
  currentUser {
    addresses {
      id
      addressType
      fullAddress
      isDefault
    }
    defaultBillingAddress {
      id
      fullAddress
    }
  }
}
```

---

## 🔗 Related Documentation
- **[GraphQL API](./graphql.md)** - Complete API reference
- **[User Authentication](../components/auth.md)** - User management
- **[Frontend Components](../components/ui.md)** - UI components

---

*Dokumentace aktualizována: 18.6.2025*