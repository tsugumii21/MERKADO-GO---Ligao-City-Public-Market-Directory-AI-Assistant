/**
 * MerkadoGo â€” Standalone Firebase Firestore Migration Script
 * 
 * Usage:
 * 1. Download your service account private key from Firebase Console:
 *    Project Settings -> Service accounts -> Generate new private key
 * 2. Save the JSON file as `scripts/serviceAccountKey.json`
 * 3. Run:
 *    npm install firebase-admin
 *    node scripts/seed_firestore.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
const vendorNotesPath = path.join(__dirname, '..', 'MerkadoGO- map and stall insturctions', 'Map Logic & Data Set', 'vendor_notes.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('âŒ Error: serviceAccountKey.json not found in scripts/ folder.');
  console.error('Please download your service account key from Firebase Console and place it at:');
  console.error(serviceAccountPath);
  process.exit(1);
}

if (!fs.existsSync(vendorNotesPath)) {
  console.error('âŒ Error: vendor_notes.json not found at:', vendorNotesPath);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
const vendors = JSON.parse(fs.readFileSync(vendorNotesPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function purgeAndSeed() {
  console.log('ðŸš€ Connecting to Firestore (Project:', serviceAccount.project_id, ')...');
  const stallsCollection = db.collection('stalls');

  // 1. Purge existing stalls
  console.log('ðŸ” Fetching existing stalls in collection "stalls"...');
  const existingSnapshot = await stallsCollection.get();

  if (!existingSnapshot.empty) {
    console.log(`ðŸ—‘ï¸  Purging ${existingSnapshot.size} existing stall documents...`);
    const batchSize = 400;
    const docs = existingSnapshot.docs;
    
    for (let i = 0; i < docs.length; i += batchSize) {
      const batch = db.batch();
      const chunk = docs.slice(i, i + batchSize);
      chunk.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
    console.log('âœ… Purge complete.');
  } else {
    console.log('â„¹ï¸  No existing stalls found to purge.');
  }

  // 2. Seed 134 new vendor stalls
  console.log(`ðŸ“¦ Seeding ${vendors.length} vendor stalls from vendor_notes.json...`);
  const batchSize = 400;
  let seededCount = 0;

  for (let i = 0; i < vendors.length; i += batchSize) {
    const batch = db.batch();
    const chunk = vendors.slice(i, i + batchSize);

    chunk.forEach((vendor) => {
      const stallId = String(vendor.stall_id);
      const docRef = stallsCollection.doc(stallId);

      batch.set(docRef, {
        id: String(vendor.id),
        stallId: stallId,
        stall_id: stallId,
        name: vendor.business_name || '',
        category: vendor.primary_category || '',
        categories: Array.isArray(vendor.search_categories) ? vendor.search_categories : [vendor.primary_category],
        section: vendor.building_or_section || '',
        stallNumber: vendor.stall_number || '',
        stall_number: vendor.stall_number || '',
        address: vendor.address || '',
        products: [],
        photoUrls: [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
        latitude: 13.2419233,
        longitude: 123.5385460,
        isActive: true,
        isOpen: true,
        status: 'open',
        tags: [],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      seededCount++;
    });

    await batch.commit();
    console.log(`   Saved ${seededCount} / ${vendors.length} stalls...`);
  }

  console.log(`ðŸŽ‰ Successfully seeded ${seededCount} vendor stalls into Firestore!`);
  process.exit(0);
}

purgeAndSeed().catch((err) => {
  console.error('âŒ Migration failed:', err);
  process.exit(1);
});
