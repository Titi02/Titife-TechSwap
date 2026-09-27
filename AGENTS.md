# AGENTS.md — Engineering Governance & AI Agent Guidelines

**Project:** Titife TechSwap — Secondhand Electronics Marketplace  
**Source of Truth:** [`PRD.md`](file:///c:/Users/USER/Desktop/Titife%20TechSwap/PRD.md)  
**Strictness Level:** MANDATORY (Zero Deviation Tolerated)  

---

## 1. Project Summary

**Titife TechSwap** is a peer-to-peer secondhand electronics marketplace in Nigeria built to facilitate secure buying and selling of pre-owned electronics (smartphones, laptops, audio, gaming, wearables).

- **Vertical:** Secondhand electronics marketplace
- **Currency:** NGN (Nigerian Naira — Minor units: Kobo, 1 NGN = 100 Kobo)
- **Stack:** TypeScript, Prisma, PostgreSQL
- **Deployment Target:** Vercel + managed PostgreSQL (e.g. Supabase / Neon)
- **Shipping Model:** Single-seller orders only
- **Review Model:** Buyer reviews completed order, 1 review per completed order
- **Role Model:** Unified user model (a single user account can both buy and sell)

---

## 2. Source of Truth Directive

> **`PRD.md` IS THE ABSOLUTE AND UNQUESTIONABLE SOURCE OF TRUTH.**

- Any code, schema, migration, script, or documentation that contradicts [`PRD.md`](file:///c:/Users/USER/Desktop/Titife%20TechSwap/PRD.md) is a **CRITICAL BUG**.
- No AI agent or developer may silently alter, add, or omit entities, fields, data types, constraints, state transitions, API endpoints, or indexes specified in [`PRD.md`](file:///c:/Users/USER/Desktop/Titife%20TechSwap/PRD.md).
- If a design change or refinement is required during Phase 2, **the PRD must be updated and re-approved FIRST** before modifying code or database schemas.

---

## 3. Non-Negotiable Rules

1. **Money Representation:**
   - Money MUST be stored as whole-number integer minor units (`priceAmount: Int` in Kobo) paired with an explicit ISO-4217 currency code (`currency: TEXT` default `'NGN'`, matching the deployed PostgreSQL column type). The `currency` column is unbounded `TEXT` and imposes no length limit at the database level; the requirement that an ISO-4217 code is exactly 3 characters (e.g. `NGN`) is a domain-level rule enforced at the application layer, not by the column type.
   - Using `Float`, `Double`, or `Decimal` types for currency or prices is **STRICTLY FORBIDDEN**.
2. **Identifiers:**
   - All table primary keys MUST use generated, non-sequential string identifiers (CUID2 format).
   - Auto-incrementing sequential integers (`1, 2, 3...`) or raw sequence IDs are forbidden in user-facing APIs and primary keys.
3. **Audit Timestamps:**
   - Every entity MUST include `createdAt` (`DateTime` default `now()`) and `updatedAt` (`DateTime` auto-update).
4. **Explicit Deletion Strategy:**
   - `User`, `Listing`, `Order`, and `Review` MUST use Soft Delete (`deletedAt: DateTime?`).
   - `ListingImage`, `ListingTag`, `Category`, and `Tag` MUST use Hard Delete (`ON DELETE CASCADE`).
5. **Controlled State Lifecycles:**
   - `Listing` and `Order` lifecycle transitions MUST be explicitly checked and enforced via PostgreSQL check constraints or PL/pgSQL database triggers (`trg_order_status_check`).
6. **Database Integrity & Constraints:**
   - Every constraint documented in [`PRD.md`](file:///c:/Users/USER/Desktop/Titife%20TechSwap/PRD.md) MUST be enforced directly within the PostgreSQL schema (Primary Keys, Foreign Keys, Unique Keys, Check Constraints, and Partial Unique Indexes).
7. **One-of-One Listing Inventory Invariant:**
   - A secondhand electronic listing with an active order (`PENDING_PAYMENT`, `PAID`, `SHIPPED`, `DELIVERED`, `COMPLETED`) MUST NOT be allowed to have a second active order or reservation under any concurrent condition.
   - Enforced via partial unique index `idx_unique_active_order_per_listing` on `Order(listingId)` and pessimistic row locking (`SELECT ... FOR UPDATE`).
8. **Concurrent Mutations:**
   - All purchase and checkout mutations MUST execute within serializable/repeatable-read database transactions with explicit pessimistic row locks (`FOR UPDATE`).
9. **N:M Relationships:**
   - Every N:M relationship MUST have an explicit join table entity (`ListingTag` connecting `Listing` and `Tag`).
10. **Targeted Indexing:**
    - Only construct indexes explicitly mapped to the 5 primary user actions (`ACT-1` to `ACT-5`). Do not create arbitrary or redundant indexes.
11. **URL Security:**
    - Internal database primary keys or auto-increments MUST NEVER be exposed in public API URLs.

---

## 4. Stack & Coding Conventions

- **Language & Runtime:** TypeScript (Strict mode enabled: `"strict": true` in `tsconfig.json`).
- **ORM & Database:** Prisma ORM connected to PostgreSQL.
- **API Architecture:** Versioned REST endpoints prefixed with `/api/v1/...`.
- **Naming Conventions:**
  - Database tables: PascalCase (`User`, `Listing`, `Order`, `Review`).
  - Database columns: camelCase (`priceAmount`, `buyerId`, `idempotencyKey`).
  - API paths: kebab-case (`/api/v1/orders/:id/fulfillment`).
  - JSON keys: camelCase (`priceAmount`, `shippingAddress`).
- **Error Response Structure:** Every endpoint MUST return errors wrapped in the standardized JSON envelope:
  ```json
  {
    "error": {
      "code": "ERROR_CODE_STRING",
      "message": "Human readable error description",
      "details": [],
      "timestamp": "ISO-8601-Timestamp",
      "requestId": "req_cuid2"
    }
  }
  ```

---

## 5. Required Tools & Verification Workflows

When implementing or executing Phase 2 database proofs, agents MUST execute and document these specific workflows:

1. **Prisma Schema & Migrations:**
   - Maintain schema in `prisma/schema.prisma`.
   - **Apply schema changes to any existing database with `npx prisma migrate deploy` ONLY.** It replays the committed migration SQL verbatim and therefore preserves every SQL-defined partial index.
   - **NEVER run `npx prisma migrate dev` or `npx prisma db push` against the existing database.** Both are unsafe here for the reason given in [§5.1](#51-prisma-schema-limitation--partial-indexes-are-sql-only).
   - Hand-author each new migration as `prisma/migrations/<timestamp>_<name>/migration.sql`, then apply it with `npx prisma migrate deploy`. Do not use `migrate dev --name` to generate it.
   - Verify applied state with `npx prisma migrate status` (expect `Database schema is up to date!`).
   - Ensure clean database reset via `npx prisma migrate reset --force`. This is safe for indexes — it replays the committed migration SQL from scratch, partial indexes included — but it **drops all data**, so never use it on a database whose evidence has been captured.
2. **Deterministic Seeding:**
   - Maintain a deterministic seed script in `prisma/seed.ts` populating known test users, categories, listings, orders, and reviews.
   - Execute seed via `npx prisma db seed`.
3. **Query Plan & Performance Capture (`EXPLAIN ANALYZE`):**
   - For the two heaviest queries (`ACT-2` search catalog & `ACT-3` checkout transaction), capture raw PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` execution plans.
   - Save output logs to the `evidence/` directory.
4. **Invalid Constraint Verification Tests:**
   - Execute test scripts attempting to violate database rules:
     - Duplicate active order on a reserved 1-of-1 listing (`idx_unique_active_order_per_listing`).
     - Out-of-bounds review rating (`chk_review_rating`).
     - Negative listing price (`chk_listing_price_positive`).
   - Capture expected PostgreSQL rejection error codes (`23505`, `23514`) and store proof logs in `evidence/`.
5. **Diagram Maintenance:**
   - Keep Mermaid ERD and state machine diagrams synchronized between `PRD.md` and codebase documentation.

### 5.1 Prisma Schema Limitation — Partial Indexes Are SQL-Only

**The Prisma schema language cannot represent PostgreSQL partial indexes.** There is no syntax for a `WHERE` predicate on `@@index` or `@@unique`; a Prisma index is always an unconditional B-tree over the whole table. (The same limitation applies to `CHECK` constraints, which is why `chk_listing_price_positive`, `chk_order_amounts`, `chk_order_no_self_buy`, and `chk_review_rating` are SQL-only too.)

Because of this, `prisma/schema.prisma` and the live database are **intentionally, permanently divergent** on indexes. This is not drift and must not be "fixed":

| Index | `prisma/schema.prisma` | Actual database index | Form |
| :--- | :--- | :--- | :--: |
| `idx_listing_seller_status` | `@@index`, no predicate | `WHERE "deletedAt" IS NULL` | Partial |
| `idx_listing_search_filter` | `@@index`, no predicate | `WHERE "status" = 'ACTIVE' AND "deletedAt" IS NULL` | Partial |
| `idx_order_seller_status` | `@@index`, no predicate | `WHERE "deletedAt" IS NULL` | Partial |
| `idx_review_seller_created` | `@@index`, no predicate | `WHERE "deletedAt" IS NULL` | Partial |
| `idx_unique_active_order_per_listing` | **not declared at all** | `WHERE "status" IN ('PENDING_PAYMENT','PAID','SHIPPED','DELIVERED','COMPLETED')` | Partial unique |

The four `@@index` declarations are retained in `schema.prisma` so the indexed columns and sort directions stay documented and Prisma Client generation stays accurate. The `WHERE` predicates exist **only** in the migration SQL and the deployed database. `idx_unique_active_order_per_listing` — which enforces the 1-of-1 invariant of [Rule 7](#3-non-negotiable-rules) — is SQL-only in full, because Prisma offers no way to express a unique index over a filtered row set.

**This divergence is exactly why `prisma migrate dev` is forbidden here.** `migrate dev` resolves the datamodel against a database built from the migrations, sees the missing predicates as a difference, and emits `CREATE INDEX` statements for names that already exist — failing with SQLSTATE `42P07` (relation already exists) — or, on the path where it does emit SQL, replaces each partial index with an unconditional one, **silently dropping the predicates and with them the 1-of-1 inventory invariant.** `prisma db push` carries the same risk by directly diffing the datamodel against the live database.

**Rules that follow:**
- The migration SQL is the single source of truth for index predicates, partial or otherwise. Edit partial index DDL there — never in `schema.prisma`.
- Any migration touching `Listing`, `Order`, or `Review` indexes MUST reproduce the existing `WHERE` clauses verbatim.
- Never add a `WHERE`-less placeholder for a partial index, and never delete the four `@@index` declarations in an attempt to "resync" the schema.
- After applying any migration, confirm every predicate survived:
  ```sql
  SELECT indexname, indexdef FROM pg_indexes
  WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
  ORDER BY indexname;
  ```
  All five indexes must still show a `WHERE` clause.
- When documents disagree on an index predicate, `migration.sql` wins over `prisma/schema.prisma`, which wins over prose documentation.

---

## 6. Definition of Done (Phase 2 Governance)

Phase 2 is considered **COMPLETE** if and only if all of the following empirical criteria are satisfied and verified:

- [ ] `prisma/schema.prisma` strictly mirrors all entities, fields, types, and constraints defined in `PRD.md`.
- [ ] Fresh database migration runs cleanly from scratch without warnings or errors.
- [ ] Deterministic seed script populates test data successfully.
- [ ] All database constraints, foreign keys, unique keys, and partial indexes exist and are active in PostgreSQL.
- [ ] SQL/Prisma proof scripts for the 5 primary user actions (`ACT-1` to `ACT-5`) execute successfully.
- [ ] `EXPLAIN ANALYZE` query plans for the two heaviest queries are captured and stored in `evidence/`.
- [ ] Three invalid database operations (including the 1-of-1 listing invariant violation) are executed and genuinely rejected by PostgreSQL kernel constraints with captured error logs in `evidence/`.
- [ ] All evidence files, query plans, and rejection logs are verified and committed.
- [ ] Zero discrepancies exist between `PRD.md`, `AGENTS.md`, and the database schema/scripts.

---

## 7. Absolute MUST NOT Directives

The agent / engineer MUST NOT:

- ❌ Invent new entities, fields, or relationship types without updating `PRD.md` first.
- ❌ Silently alter PRD technical decisions, types, or business rules.
- ❌ Omit realistic API error cases or fallback error envelopes.
- ❌ Use sequential auto-incrementing integer identifiers for primary keys.
- ❌ Use `Decimal` or `Float` data types for prices or monetary amounts.
- ❌ Build unrequested frontend UI components or unnecessary application features (this project is documentation + database proof only).
- ❌ Begin Phase 2 implementation before receiving explicit user approval for `PRD.md` and `AGENTS.md`.
