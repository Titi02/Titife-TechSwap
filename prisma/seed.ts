import { PrismaClient, UserRole, ItemCondition, ListingStatus, OrderStatus } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is not set. Copy .env.example to .env and provide the connection string.');
}

const prisma = new PrismaClient();

async function main() {
  console.log('--- Starting Deterministic Database Seed (CUID2 Generated IDs) ---');

  // Clean existing data
  await prisma.review.deleteMany();
  await prisma.order.deleteMany();
  await prisma.listingTag.deleteMany();
  await prisma.listingImage.deleteMany();
  await prisma.listing.deleteMany();
  await prisma.tag.deleteMany();
  await prisma.category.deleteMany();
  await prisma.user.deleteMany();

  // Generate CUID2 Identifiers
  const sellerId = createId();
  const buyerId = createId();
  const catSmartphonesId = createId();
  const catLaptopsId = createId();
  const tag5GId = createId();
  const tagOLEDId = createId();
  const listing1Id = createId();
  const listing2Id = createId();
  const completedOrderId = createId();
  const reviewId = createId();

  // Seed Users
  const seller = await prisma.user.create({
    data: {
      id: sellerId,
      email: 'seller.chidubem@techswap.ng',
      passwordHash: '$2b$10$EpRvmqqK8vY.4p/5QZ.6qO9yE3qZ1vW8t8u7v6w5x4y3z2a1b0c',
      fullName: 'Chidubem Okafor',
      phoneNumber: '+2348030001122',
      role: UserRole.USER,
      verifiedSeller: true,
    },
  });

  const buyer = await prisma.user.create({
    data: {
      id: buyerId,
      email: 'buyer.amina@techswap.ng',
      passwordHash: '$2b$10$EpRvmqqK8vY.4p/5QZ.6qO9yE3qZ1vW8t8u7v6w5x4y3z2a1b0c',
      fullName: 'Amina Bello',
      phoneNumber: '+2348029993344',
      role: UserRole.USER,
      verifiedSeller: false,
    },
  });

  console.log(`Created test users (CUID2): Seller (${seller.id}), Buyer (${buyer.id})`);

  // Seed Categories
  const catSmartphones = await prisma.category.create({
    data: {
      id: catSmartphonesId,
      name: 'Smartphones & Tablets',
      slug: 'smartphones-tablets',
      description: 'Mobile smartphones and tablet devices',
    },
  });

  const catLaptops = await prisma.category.create({
    data: {
      id: catLaptopsId,
      name: 'Laptops & Computers',
      slug: 'laptops-computers',
      description: 'Pre-owned laptops and workstation hardware',
    },
  });

  console.log(`Created categories (CUID2): ${catSmartphones.name}, ${catLaptops.name}`);

  // Seed Tags
  const tag5G = await prisma.tag.create({
    data: { id: tag5GId, name: '5G Enabled', slug: '5g-enabled' },
  });

  const tagOLED = await prisma.tag.create({
    data: { id: tagOLEDId, name: 'OLED Screen', slug: 'oled-screen' },
  });

  // Seed Listing 1 (Active)
  const listing1 = await prisma.listing.create({
    data: {
      id: listing1Id,
      sellerId: seller.id,
      categoryId: catSmartphones.id,
      title: 'Apple iPhone 13 Pro Max - 256GB Sierra Blue',
      description: 'Mint condition, battery health 89%. Includes original box and fast charging cable.',
      brand: 'Apple',
      modelName: 'iPhone 13 Pro Max',
      condition: ItemCondition.VERY_GOOD,
      specs: {
        ram: '6GB',
        storage: '256GB',
        batteryHealth: 89,
        color: 'Sierra Blue',
        imeiMasked: '358912******419',
      },
      priceAmount: 65000000, // 650,000 NGN in Kobo
      currency: 'NGN',
      status: ListingStatus.ACTIVE,
      images: {
        create: [
          { id: createId(), url: 'https://cdn.titifetechswap.ng/images/iphone13_front.jpg', displayOrder: 0 },
          { id: createId(), url: 'https://cdn.titifetechswap.ng/images/iphone13_back.jpg', displayOrder: 1 },
        ],
      },
      tags: {
        create: [
          { tagId: tag5G.id },
          { tagId: tagOLED.id },
        ],
      },
    },
  });

  // Seed Listing 2 (Active)
  const listing2 = await prisma.listing.create({
    data: {
      id: listing2Id,
      sellerId: seller.id,
      categoryId: catLaptops.id,
      title: 'Apple MacBook Pro 14 M1 Pro - 16GB / 512GB Space Gray',
      description: 'Lightly used for software development. Cycle count 42.',
      brand: 'Apple',
      modelName: 'MacBook Pro 14 (2021)',
      condition: ItemCondition.LIKE_NEW,
      specs: {
        chip: 'Apple M1 Pro 8-Core',
        ram: '16GB',
        storage: '512GB SSD',
        cycleCount: 42,
      },
      priceAmount: 120000000, // 1,200,000 NGN in Kobo
      currency: 'NGN',
      status: ListingStatus.ACTIVE,
      images: {
        create: [
          { id: createId(), url: 'https://cdn.titifetechswap.ng/images/macbook_open.jpg', displayOrder: 0 },
        ],
      },
    },
  });

  console.log(`Created listings (CUID2): ${listing1.title}, ${listing2.title}`);

  // -------------------------------------------------------------------------
  // Seed a representative ACTIVE catalog.
  // Catalog search plans are only meaningful at a realistic catalog size AND a
  // realistic selectivity. A handful of rows in a single heap page always yields a
  // sequential scan (correctly - reading one page beats 20 random index fetches),
  // and a filter matching half the table never justifies an index. The mix below
  // gives each category a large, multi-page catalog in which the ACT-2 predicate
  // (category + VERY_GOOD + ACTIVE) selects a small fraction of rows, so
  // idx_listing_search_filter wins on the planner's own cost model.
  // The planner is never forced: scripts/run-proofs.ts asserts the resulting plan
  // and fails the run if the index was not chosen.
  // Volume is added to every category so the proofs behave identically regardless
  // of which category the deterministic category lookup resolves to.
  // -------------------------------------------------------------------------
  type CatalogVolumeRow = {
    id: string;
    sellerId: string;
    categoryId: string;
    title: string;
    description: string;
    brand: string;
    modelName: string;
    condition: ItemCondition;
    specs: Record<string, string>;
    priceAmount: number;
    currency: string;
    status: ListingStatus;
  };

  const catalogFill: { categoryId: string; label: string }[] = [
    { categoryId: catSmartphones.id, label: 'Smartphone' },
    { categoryId: catLaptops.id, label: 'Laptop' },
  ];
  const OTHER_CONDITIONS: ItemCondition[] = [
    ItemCondition.FAIR,
    ItemCondition.GOOD,
    ItemCondition.LIKE_NEW,
    ItemCondition.REFURBISHED,
  ];
  const MATCHING_PER_CATEGORY = 20;
  const OTHER_ACTIVE_PER_CATEGORY = 300;
  const SOLD_PER_CATEGORY = 80;
  const VOLUME_DESCRIPTION =
    'Deterministic catalog-volume row. Exists so that search query plans reflect a realistic catalog size and selectivity.';

  let filled = 0;
  for (const group of catalogFill) {
    const rows: CatalogVolumeRow[] = [];

    for (let i = 0; i < MATCHING_PER_CATEGORY; i++) {
      rows.push({
        id: createId(),
        sellerId: seller.id,
        categoryId: group.categoryId,
        title: `Catalog Volume ${group.label} Match ${i + 1}`,
        description: VOLUME_DESCRIPTION,
        brand: 'VolumeBrand',
        modelName: `MatchModel ${i + 1}`,
        condition: ItemCondition.VERY_GOOD,
        specs: { ram: '8GB', storage: '256GB' },
        priceAmount: 5000000 + i * 1000,
        currency: 'NGN',
        status: ListingStatus.ACTIVE,
      });
    }

    for (let i = 0; i < OTHER_ACTIVE_PER_CATEGORY; i++) {
      rows.push({
        id: createId(),
        sellerId: seller.id,
        categoryId: group.categoryId,
        title: `Catalog Volume ${group.label} Other ${i + 1}`,
        description: VOLUME_DESCRIPTION,
        brand: 'VolumeBrand',
        modelName: `OtherModel ${i + 1}`,
        condition: OTHER_CONDITIONS[i % OTHER_CONDITIONS.length],
        specs: { ram: '4GB', storage: '128GB' },
        priceAmount: 3000000 + i * 1000,
        currency: 'NGN',
        status: ListingStatus.ACTIVE,
      });
    }

    for (let i = 0; i < SOLD_PER_CATEGORY; i++) {
      rows.push({
        id: createId(),
        sellerId: seller.id,
        categoryId: group.categoryId,
        title: `Catalog Volume ${group.label} Sold ${i + 1}`,
        description: VOLUME_DESCRIPTION,
        brand: 'VolumeBrand',
        modelName: `SoldModel ${i + 1}`,
        condition: ItemCondition.VERY_GOOD,
        specs: { ram: '8GB', storage: '256GB' },
        priceAmount: 4000000 + i * 1000,
        currency: 'NGN',
        status: ListingStatus.SOLD,
      });
    }

    for (let i = 0; i < rows.length; i += 200) {
      await prisma.listing.createMany({ data: rows.slice(i, i + 200) });
    }
    filled += rows.length;
  }
  console.log(
    `Seeded ${filled} catalog-volume listings across ${catalogFill.length} categories ` +
      `(${MATCHING_PER_CATEGORY} matching VERY_GOOD+ACTIVE per category)`
  );

  // Seed Historical Completed Order & Review
  // Update listing2 status to RESERVED then SOLD to satisfy trigger
  await prisma.listing.update({
    where: { id: listing2.id },
    data: { status: ListingStatus.RESERVED },
  });

  const completedOrder = await prisma.order.create({
    data: {
      id: completedOrderId,
      orderNumber: 'ORD-20260901-0001',
      buyerId: buyer.id,
      sellerId: seller.id,
      listingId: listing2.id,
      status: OrderStatus.PENDING_PAYMENT,
      subtotalAmount: 120000000,
      shippingFeeAmount: 500000,
      totalAmount: 120500000,
      currency: 'NGN',
      shippingAddress: {
        street: '14 Commercial Avenue, Yaba',
        city: 'Lagos',
        state: 'Lagos State',
        phone: '+2348029993344',
      },
      trackingNumber: 'GIG-NG-771120',
      carrier: 'GIG Logistics',
      idempotencyKey: createId(),
      paidAt: new Date('2026-09-01T10:00:00Z'),
    },
  });

  // Hops: PENDING_PAYMENT -> PAID -> SHIPPED -> DELIVERED -> COMPLETED
  await prisma.order.update({
    where: { id: completedOrder.id },
    data: { status: OrderStatus.PAID },
  });

  await prisma.order.update({
    where: { id: completedOrder.id },
    data: { status: OrderStatus.SHIPPED, shippedAt: new Date('2026-09-01T14:00:00Z') },
  });

  await prisma.order.update({
    where: { id: completedOrder.id },
    data: { status: OrderStatus.DELIVERED, deliveredAt: new Date('2026-09-02T11:00:00Z') },
  });

  await prisma.order.update({
    where: { id: completedOrder.id },
    data: { status: OrderStatus.COMPLETED, completedAt: new Date('2026-09-02T12:00:00Z') },
  });

  await prisma.listing.update({
    where: { id: listing2.id },
    data: { status: ListingStatus.SOLD },
  });

  const review = await prisma.review.create({
    data: {
      id: reviewId,
      orderId: completedOrder.id,
      buyerId: buyer.id,
      sellerId: seller.id,
      rating: 5,
      title: 'Flawless MacBook Pro!',
      comment: 'Laptop arrived in mint condition. Fast delivery by GIG. Excellent seller!',
    },
  });

  console.log(`Created historical completed order (${completedOrder.orderNumber}) & review rating (${review.rating}/5)`);
  console.log('--- Database Seed Completed Successfully ---');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
