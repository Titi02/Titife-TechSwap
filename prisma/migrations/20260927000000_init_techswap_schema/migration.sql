-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "ItemCondition" AS ENUM ('FOR_PARTS', 'FAIR', 'GOOD', 'VERY_GOOD', 'LIKE_NEW', 'REFURBISHED');

-- CreateEnum
CREATE TYPE "ListingStatus" AS ENUM ('DRAFT', 'ACTIVE', 'RESERVED', 'SOLD', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('PENDING_PAYMENT', 'PAID', 'SHIPPED', 'DELIVERED', 'COMPLETED', 'CANCELLED');

-- CreateTable "User"
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "verifiedSeller" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable "Category"
CREATE TABLE "Category" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateTable "Listing"
CREATE TABLE "Listing" (
    "id" TEXT NOT NULL,
    "sellerId" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "brand" TEXT NOT NULL,
    "modelName" TEXT NOT NULL,
    "condition" "ItemCondition" NOT NULL,
    "specs" JSONB NOT NULL,
    "priceAmount" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'NGN',
    "status" "ListingStatus" NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Listing_pkey" PRIMARY KEY ("id")
);

-- CreateTable "ListingImage"
CREATE TABLE "ListingImage" (
    "id" TEXT NOT NULL,
    "listingId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ListingImage_pkey" PRIMARY KEY ("id")
);

-- CreateTable "Tag"
CREATE TABLE "Tag" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Tag_pkey" PRIMARY KEY ("id")
);

-- CreateTable "ListingTag"
CREATE TABLE "ListingTag" (
    "listingId" TEXT NOT NULL,
    "tagId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ListingTag_pkey" PRIMARY KEY ("listingId","tagId")
);

-- CreateTable "Order"
CREATE TABLE "Order" (
    "id" TEXT NOT NULL,
    "orderNumber" TEXT NOT NULL,
    "buyerId" TEXT NOT NULL,
    "sellerId" TEXT NOT NULL,
    "listingId" TEXT NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "subtotalAmount" INTEGER NOT NULL,
    "shippingFeeAmount" INTEGER NOT NULL DEFAULT 0,
    "totalAmount" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'NGN',
    "shippingAddress" JSONB NOT NULL,
    "trackingNumber" TEXT,
    "carrier" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "paidAt" TIMESTAMP(3),
    "shippedAt" TIMESTAMP(3),
    "deliveredAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Order_pkey" PRIMARY KEY ("id")
);

-- CreateTable "Review"
CREATE TABLE "Review" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "buyerId" TEXT NOT NULL,
    "sellerId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "comment" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Review_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
CREATE UNIQUE INDEX "User_phoneNumber_key" ON "User"("phoneNumber");

-- CreateIndex
CREATE UNIQUE INDEX "Category_name_key" ON "Category"("name");
CREATE UNIQUE INDEX "Category_slug_key" ON "Category"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "Tag_name_key" ON "Tag"("name");
CREATE UNIQUE INDEX "Tag_slug_key" ON "Tag"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "Order_orderNumber_key" ON "Order"("orderNumber");
CREATE UNIQUE INDEX "Order_idempotencyKey_key" ON "Order"("idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "Review_orderId_key" ON "Review"("orderId");

-- Action Targeted Indexes
CREATE INDEX "idx_listing_seller_status" ON "Listing"("sellerId", "status", "createdAt" DESC) WHERE "deletedAt" IS NULL;
CREATE INDEX "idx_listing_search_filter" ON "Listing"("categoryId", "condition", "createdAt" DESC) WHERE "status" = 'ACTIVE' AND "deletedAt" IS NULL;
CREATE INDEX "idx_order_seller_status" ON "Order"("sellerId", "status", "createdAt" ASC) WHERE "deletedAt" IS NULL;
CREATE INDEX "idx_review_seller_created" ON "Review"("sellerId", "createdAt" DESC) WHERE "deletedAt" IS NULL;

-- 1-OF-1 LISTING INVENTORY INVARIANT PARTIAL UNIQUE INDEX
CREATE UNIQUE INDEX "idx_unique_active_order_per_listing" ON "Order"("listingId") 
WHERE status IN ('PENDING_PAYMENT', 'PAID', 'SHIPPED', 'DELIVERED', 'COMPLETED');

-- Check Constraints
ALTER TABLE "Listing" ADD CONSTRAINT "chk_listing_price_positive" CHECK ("priceAmount" > 0 AND "currency" = 'NGN');
ALTER TABLE "Order" ADD CONSTRAINT "chk_order_amounts" CHECK ("subtotalAmount" >= 0 AND "shippingFeeAmount" >= 0 AND "totalAmount" = "subtotalAmount" + "shippingFeeAmount");
ALTER TABLE "Order" ADD CONSTRAINT "chk_order_no_self_buy" CHECK ("buyerId" <> "sellerId");
ALTER TABLE "Review" ADD CONSTRAINT "chk_review_rating" CHECK ("rating" >= 1 AND "rating" <= 5);

-- Foreign Key Constraints
ALTER TABLE "Listing" ADD CONSTRAINT "Listing_sellerId_fkey" FOREIGN KEY ("sellerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Listing" ADD CONSTRAINT "Listing_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ListingImage" ADD CONSTRAINT "ListingImage_listingId_fkey" FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ListingTag" ADD CONSTRAINT "ListingTag_listingId_fkey" FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ListingTag" ADD CONSTRAINT "ListingTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Order" ADD CONSTRAINT "Order_buyerId_fkey" FOREIGN KEY ("buyerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Order" ADD CONSTRAINT "Order_sellerId_fkey" FOREIGN KEY ("sellerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Order" ADD CONSTRAINT "Order_listingId_fkey" FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Review" ADD CONSTRAINT "Review_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Review" ADD CONSTRAINT "Review_buyerId_fkey" FOREIGN KEY ("buyerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Review" ADD CONSTRAINT "Review_sellerId_fkey" FOREIGN KEY ("sellerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

----------------------------------------------------------------------------------------------------
-- LISTING STATUS TRANSITION TRIGGER FUNCTION & TRIGGER
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_listing_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    IF OLD.status IN ('SOLD', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Forbidden state transition: Listing status % is terminal.', OLD.status;
    END IF;
    IF OLD.status = 'DRAFT' AND NEW.status NOT IN ('ACTIVE', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Forbidden state transition for Listing: DRAFT cannot transition to %', NEW.status;
    END IF;
    IF OLD.status = 'ACTIVE' AND NEW.status NOT IN ('RESERVED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Forbidden state transition for Listing: ACTIVE cannot transition to %', NEW.status;
    END IF;
    IF OLD.status = 'RESERVED' AND NEW.status NOT IN ('ACTIVE', 'SOLD') THEN
        RAISE EXCEPTION 'Forbidden state transition for Listing: RESERVED cannot transition to %', NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_listing_status_check
BEFORE UPDATE OF status ON "Listing"
FOR EACH ROW EXECUTE FUNCTION enforce_listing_status_transition();

----------------------------------------------------------------------------------------------------
-- ORDER STATUS TRANSITION TRIGGER FUNCTION & TRIGGER
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_order_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    IF OLD.status IN ('COMPLETED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Forbidden state transition: Order status % is terminal.', OLD.status;
    END IF;
    IF OLD.status = 'PENDING_PAYMENT' AND NEW.status NOT IN ('PAID', 'CANCELLED') THEN
        RAISE EXCEPTION 'Forbidden state transition from PENDING_PAYMENT to %', NEW.status;
    END IF;
    IF OLD.status = 'PAID' AND NEW.status NOT IN ('SHIPPED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Forbidden state transition from PAID to %', NEW.status;
    END IF;
    IF OLD.status = 'SHIPPED' AND NEW.status != 'DELIVERED' THEN
        RAISE EXCEPTION 'Forbidden state transition from SHIPPED to %', NEW.status;
    END IF;
    IF OLD.status = 'DELIVERED' AND NEW.status != 'COMPLETED' THEN
        RAISE EXCEPTION 'Forbidden state transition from DELIVERED to %', NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_status_check
BEFORE UPDATE OF status ON "Order"
FOR EACH ROW EXECUTE FUNCTION enforce_order_status_transition();

----------------------------------------------------------------------------------------------------
-- REVIEW INTEGRITY TRIGGER FUNCTION & TRIGGER
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_review_integrity()
RETURNS TRIGGER AS $$
DECLARE
    target_order_status "OrderStatus";
    target_order_buyer_id TEXT;
    target_order_seller_id TEXT;
BEGIN
    SELECT status, "buyerId", "sellerId" 
    INTO target_order_status, target_order_buyer_id, target_order_seller_id 
    FROM "Order" 
    WHERE id = NEW."orderId";

    IF target_order_status IS NULL THEN
        RAISE EXCEPTION 'Referenced order % does not exist.', NEW."orderId";
    END IF;

    IF target_order_status != 'COMPLETED' THEN
        RAISE EXCEPTION 'Review submission forbidden: Order % is in status % (must be COMPLETED).', NEW."orderId", target_order_status;
    END IF;

    IF NEW."buyerId" != target_order_buyer_id THEN
        RAISE EXCEPTION 'Review buyerId (%) does not match Order buyerId (%).', NEW."buyerId", target_order_buyer_id;
    END IF;

    IF NEW."sellerId" != target_order_seller_id THEN
        RAISE EXCEPTION 'Review sellerId (%) does not match Order sellerId (%).', NEW."sellerId", target_order_seller_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_review_integrity_check
BEFORE INSERT OR UPDATE ON "Review"
FOR EACH ROW EXECUTE FUNCTION enforce_review_integrity();

----------------------------------------------------------------------------------------------------
-- ORDER SELLER MATCH INVARIANT TRIGGER FUNCTION & TRIGGER
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_order_seller_match()
RETURNS TRIGGER AS $$
DECLARE
    target_listing_seller_id TEXT;
BEGIN
    SELECT "sellerId" INTO target_listing_seller_id 
    FROM "Listing" 
    WHERE id = NEW."listingId";

    IF target_listing_seller_id IS NULL THEN
        RAISE EXCEPTION 'Referenced listing % does not exist.', NEW."listingId";
    END IF;

    IF NEW."sellerId" != target_listing_seller_id THEN
        RAISE EXCEPTION 'Order sellerId (%) does not match Listing sellerId (%).', NEW."sellerId", target_listing_seller_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_seller_match_check
BEFORE INSERT ON "Order"
FOR EACH ROW EXECUTE FUNCTION enforce_order_seller_match();
