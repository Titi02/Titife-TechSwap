-- Bring ListingTag into compliance with AGENTS.md Rule 3 (Audit Timestamps):
-- every entity must carry both `createdAt` and `updatedAt`.
--
-- ListingTag previously carried `createdAt` only. This migration adds `updatedAt`
-- using the identical convention already used by User, Category, Listing,
-- ListingImage, Tag, Order and Review:
--
--   * type      TIMESTAMP(3)  (PostgreSQL's Prisma mapping for DateTime)
--   * nullable  NOT NULL      (no DEFAULT — Prisma's @updatedAt is client-side,
--                              exactly as for every other entity in this schema)
--
-- The three-step form below is required because "ListingTag" is a populated table
-- and the new column is NOT NULL with no default: a single
-- `ADD COLUMN ... NOT NULL` would fail on the existing rows.
--
-- Step 1 is a metadata-only operation on PostgreSQL 11+ (no table rewrite).
-- Step 2 backfills from `createdAt`: a junction row is only ever inserted and then
-- cascade-deleted, so its creation instant is the correct initial `updatedAt`.
-- Step 3 applies the NOT NULL constraint.
--
-- This migration touches no index, constraint, or trigger. In particular it does
-- not create, drop or alter any of the partial indexes, and it does not attempt to
-- represent their WHERE predicates in Prisma.

-- AlterTable
ALTER TABLE "ListingTag" ADD COLUMN "updatedAt" TIMESTAMP(3);

-- Backfill
UPDATE "ListingTag" SET "updatedAt" = "createdAt";

-- AlterTable
ALTER TABLE "ListingTag" ALTER COLUMN "updatedAt" SET NOT NULL;
