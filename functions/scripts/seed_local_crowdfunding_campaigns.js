const admin = require('firebase-admin');

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  'bukidbayan-capstoners';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'Refusing to seed crowdfunding campaigns because FIRESTORE_EMULATOR_HOST is not set.',
  );
  console.error(
    'Set FIRESTORE_EMULATOR_HOST to your local emulator, for example 127.0.0.1:8080.',
  );
  process.exit(1);
}

admin.initializeApp({projectId});

const db = admin.firestore();

function isoDateFromNow(daysFromNow) {
  const value = new Date();
  value.setDate(value.getDate() + daysFromNow);
  return value.toISOString();
}

function isoDateFromPast(daysAgo) {
  return isoDateFromNow(-daysAgo);
}

function buildCampaigns() {
  return [
    {
      id: 'c1',
      title: 'Community Greenhouse for Urban Farmers',
      creatorName: 'BukidBayan Co-op',
      creatorEmail: 'coop-demo@bukidbayan.app',
      creatorUid: 'seed-coop-owner',
      shortBlurb:
        'A shared greenhouse so more families can grow food sustainably.',
      description:
        'We are building a small greenhouse with basic irrigation, seedlings, and training. Funds will cover materials, tools, and starter kits for community members.',
      isAssetImage: true,
      image: 'assets/images/farmBg.jpg',
      category: 'Irrigation',
      goalAmount: 50000,
      pledgedAmount: 18500,
      backersCount: 62,
      endDate: isoDateFromNow(18),
      createdAt: isoDateFromPast(5),
      rewards: [
        {
          id: 'r1',
          title: 'Thank you shoutout',
          minPledge: 200,
          discountType: 'percent',
          discountValue: 5,
          usageLimit: 1,
          validityDays: 30,
          notes: 'We will feature your name in our supporter list.',
        },
        {
          id: 'r2',
          title: 'Seedling starter pack',
          minPledge: 600,
          discountType: 'percent',
          discountValue: 10,
          usageLimit: 1,
          validityDays: 90,
          notes: 'A small pack of vegetable seedlings (pickup only).',
        },
        {
          id: 'r3',
          title: 'Harvest basket',
          minPledge: 1500,
          discountType: 'fixed',
          discountValue: 200,
          usageLimit: 4,
          validityDays: 365,
          notes: 'A seasonal basket of produce from the greenhouse.',
        },
      ],
      coverImages: [],
      equipmentType: 'Other',
      specs: {
        Materials: 'Aluminum frame, polycarbonate panels',
        Dimensions: '4m x 6m x 2.5m height',
        'Water System': 'Drip irrigation with timer',
      },
      includedItems: [
        '1 greenhouse structure',
        'Irrigation system',
        'Basic hand tools',
        'Seedlings starter pack',
      ],
      chosenVariant: null,
      variantNotes: null,
      productionTimeline:
        'Week 1-2: Material sourcing and site prep, Week 3-4: Construction and setup, Week 5: Installation and training',
      shippingCoverage: 'Local delivery',
      shippingCostHandling: 'included',
      shippingNotes: 'Delivered and assembled at co-op site',
      warranty:
        '1-year manufacturer warranty on all materials. Co-op provides ongoing maintenance support.',
      spareParts:
        'Replacement polycarbonate panels, drip lines, and valve parts stocked at co-op office.',
      risks:
        'Weather delays during construction. Alternative: Indoor seedling setup if greenhouse cannot be built.',
      safetyNotes:
        'PPE required during assembly. Training provided for irrigation system maintenance.',
      status: 'live',
      publishedAt: isoDateFromPast(5),
      lastEditedAt: null,
    },
    {
      id: 'c2',
      title: 'Solar-Powered Water Pump for a Small Farm',
      creatorName: 'Ka-Agri Team',
      creatorEmail: 'solar-demo@bukidbayan.app',
      creatorUid: 'seed-solar-owner',
      shortBlurb: 'Lower electricity costs and improve irrigation reliability.',
      description:
        'This project installs a solar-powered pump and a simple storage system. It reduces downtime during power interruptions and supports consistent watering.',
      isAssetImage: true,
      image: 'assets/images/bg1.png',
      category: 'Solar/Power',
      goalAmount: 120000,
      pledgedAmount: 42000,
      backersCount: 113,
      endDate: isoDateFromNow(30),
      createdAt: isoDateFromPast(12),
      rewards: [
        {
          id: 'r1',
          title: 'Digital thank you card',
          minPledge: 300,
          discountType: 'percent',
          discountValue: 5,
          usageLimit: 1,
          validityDays: 30,
          notes: 'A personalized card from our team.',
        },
        {
          id: 'r2',
          title: 'Farm tour slot',
          minPledge: 2000,
          discountType: 'percent',
          discountValue: 15,
          usageLimit: 1,
          validityDays: 60,
          notes: 'Join a guided tour and see the system in action.',
        },
      ],
      coverImages: [],
      equipmentType: 'Pump',
      specs: {
        'Solar Panel Capacity': '500W photovoltaic panels',
        'Pump Type': '1.5HP submersible centrifugal pump',
        Storage: '5000L tank with float valve',
      },
      includedItems: [
        'Solar panel array',
        'Submersible pump',
        'Storage tank',
        'Mounting hardware',
        'Installation guide',
      ],
      chosenVariant: null,
      variantNotes: null,
      productionTimeline:
        'Week 1: Procurement and site assessment, Week 2-3: Installation of panels and tank, Week 4: Pump setup and testing, Week 5: Training and handover',
      shippingCoverage: 'Nationwide delivery',
      shippingCostHandling: 'included',
      shippingNotes: 'Delivered to farm site. Professional installation included.',
      warranty:
        '5-year manufacturer warranty on solar panels. 2-year warranty on pump and components.',
      spareParts:
        'Replacement pump available from local agricultural suppliers. Panel repair kits stocked.',
      risks:
        'Weather delays in installation. Fallback: temporary generator rental during setup.',
      safetyNotes:
        'Electrical safety training provided. PPE required. High-voltage warning signs installed.',
      status: 'live',
      publishedAt: isoDateFromPast(12),
      lastEditedAt: null,
    },
    {
      id: 'c3',
      title: 'Local Food Hub: Buy Direct from Farmers',
      creatorName: 'Bayan Market',
      creatorEmail: 'market-demo@bukidbayan.app',
      creatorUid: 'seed-market-owner',
      shortBlurb:
        'A small online + pickup system for fresher produce and fairer prices.',
      description:
        'We want to set up a basic ordering site, pickup point signage, and onboarding materials so partner farmers can sell directly to consumers.',
      isAssetImage: true,
      image: 'assets/images/loopyBg.jpg',
      category: 'Other',
      goalAmount: 80000,
      pledgedAmount: 7600,
      backersCount: 21,
      endDate: isoDateFromNow(9),
      createdAt: isoDateFromPast(2),
      rewards: [
        {
          id: 'r1',
          title: 'Supporter badge',
          minPledge: 150,
          discountType: 'percent',
          discountValue: 5,
          usageLimit: 1,
          validityDays: 90,
          notes: 'A supporter badge displayed in your profile (demo).',
        },
        {
          id: 'r2',
          title: 'Discount voucher',
          minPledge: 500,
          discountType: 'fixed',
          discountValue: 100,
          usageLimit: 5,
          validityDays: 180,
          notes: 'A small voucher for your first pickup order.',
        },
      ],
      coverImages: [],
      equipmentType: 'Other',
      specs: {
        Platform:
          'Simple online ordering system compatible with mobile and desktop',
        Inventory: 'Real-time tracking of farmer inventory and pricing',
        Payment: 'Cash and digital payment options at pickup',
      },
      includedItems: [
        'Website and mobile app access',
        'Pickup point setup materials',
        'Farmer onboarding training',
        'Marketing materials',
      ],
      chosenVariant: null,
      variantNotes: null,
      productionTimeline:
        'Week 1: Platform development finalization, Week 2: Farmer recruitment and training, Week 3: Pickup point setup, Week 4: Soft launch and testing',
      shippingCoverage: 'Pickup',
      shippingCostHandling: 'included',
      shippingNotes:
        'Customers pick up at designated co-op location. Hub operates Saturdays 6am-10am.',
      warranty:
        'Platform support and maintenance included for first year. Dedicated support team available.',
      spareParts:
        'Signage and display materials can be reprinted as needed from local printers.',
      risks:
        'Low farmer adoption initially. Mitigation: Guaranteed market for first 50 farmers.',
      safetyNotes:
        'Food handling best practices training required for all handlers. Cold storage available.',
      status: 'live',
      publishedAt: isoDateFromPast(2),
      lastEditedAt: null,
    },
    {
      id: 'c4',
      title: 'Organic Seed Bank Initiative',
      creatorName: 'Farming Collective',
      creatorEmail: 'seedbank-demo@bukidbayan.app',
      creatorUid: 'seed-bank-owner',
      shortBlurb:
        'Preserve heirloom and native crop varieties through community seed banking.',
      description:
        'Our goal is to create a safe, climate-controlled seed storage facility and conduct workshops on seed saving techniques. This preserves biodiversity and helps farmers become more self-sufficient.',
      isAssetImage: true,
      image: 'assets/images/farmBg.jpg',
      category: 'Crop Care',
      goalAmount: 75000,
      pledgedAmount: 28400,
      backersCount: 89,
      endDate: isoDateFromNow(25),
      createdAt: isoDateFromPast(8),
      rewards: [
        {
          id: 'r1',
          title: 'Seed packet collection',
          minPledge: 400,
          discountType: 'percent',
          discountValue: 8,
          usageLimit: 1,
          validityDays: 60,
          notes: 'A curated collection of heirloom seeds to start your garden.',
        },
        {
          id: 'r2',
          title: 'Seed saving workshop',
          minPledge: 1000,
          discountType: 'fixed',
          discountValue: 150,
          usageLimit: 3,
          validityDays: 120,
          notes:
            'Hands-on training session on proper seed collection and storage.',
        },
        {
          id: 'r3',
          title: 'Annual seed membership',
          minPledge: 2500,
          discountType: 'percent',
          discountValue: 20,
          usageLimit: 2,
          validityDays: 365,
          notes:
            'Full year access to our seed bank library and monthly seed shares.',
        },
      ],
      coverImages: [],
      equipmentType: 'Other',
      specs: {
        Storage:
          'Temperature and humidity controlled seed vault (15-20C, 30-40% humidity)',
        Capacity: 'Storage for 10000+ seed varieties',
        'Testing Equipment':
          'Seed germination testing kits and documentation system',
      },
      includedItems: [
        'Climate-controlled storage unit',
        'Seed testing equipment',
        'Documentation system',
        'Preservation containers',
        'Workshop materials',
      ],
      chosenVariant: null,
      variantNotes: null,
      productionTimeline:
        'Week 1-2: Facility setup and equipment installation, Week 3: Collection drives with local farmers, Week 4: Cataloging and storage, Week 5: Launch first workshop',
      shippingCoverage: 'Local delivery',
      shippingCostHandling: 'included',
      shippingNotes:
        'Facility located at central co-op location. Seeds distributed via workshops.',
      warranty:
        'Equipment warranty through manufacturers. 2-year seed viability guarantee for stored seeds.',
      spareParts:
        'Replacement storage containers and preservation supplies available quarterly.',
      risks:
        'Seed sourcing delays possible. Mitigation: Partner with 5 regional seed savers.',
      safetyNotes:
        'Proper storage handling training required. PPE provided for seed collection activities.',
      status: 'live',
      publishedAt: isoDateFromPast(8),
      lastEditedAt: null,
    },
  ];
}

async function seedCampaigns() {
  const campaigns = buildCampaigns();
  const batch = db.batch();

  campaigns.forEach((campaign) => {
    const {id, ...data} = campaign;
    batch.set(db.collection('campaigns').doc(id), data, {merge: true});
  });

  await batch.commit();
  console.log(
    `Seeded ${campaigns.length} crowdfunding campaigns into Firestore emulator for project ${projectId}.`,
  );
}

seedCampaigns()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Failed to seed local crowdfunding campaigns.', error);
    process.exit(1);
  });
