# 🔐 Admin Panel Setup & Usage Guide

## Part 11 - Admin Panel Implementation

This guide explains how to set up and use the **Merkado Go Admin Panel** for managing stalls and reviewing user reports.

---

## 📋 Table of Contents

1. [Creating the First Admin Account](#creating-the-first-admin-account)
2. [Admin Features Overview](#admin-features-overview)
3. [Using the Admin Panel](#using-the-admin-panel)
4. [Cloudinary Configuration](#cloudinary-configuration)
5. [Testing Checklist](#testing-checklist)

---

## 🔧 Creating the First Admin Account

Since admin access is controlled via Firestore, you must manually create the first admin account:

### Step 1: Create a Regular User Account

1. **Run the app**
2. **Sign up** with a new account (or use an existing one)
3. **Note the user's email** you want to make admin

### Step 2: Set Admin Role in Firestore Console

1. **Open Firebase Console**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your Merkado Go project

2. **Navigate to Firestore**
   - Click **"Firestore Database"** in the left sidebar
   - Click on the **"users"** collection

3. **Find Your User Document**
   - Locate the document with your user's UID
   - Click on the document to open it

4. **Add the Admin Role**
   - Click **"Add field"** (or edit if "role" field exists)
   - **Field name:** `role`
   - **Field type:** string
   - **Field value:** `admin`
   - Click **"Update"** or **"Add"**

5. **Verify the Change**
   - You should see: `role: "admin"` in the user document

### Step 3: Test Admin Login

1. **In the app**, navigate to the admin login screen:
   - Go to `/admin/login` route
2. **Sign in** with the email and password you just set as admin
3. If the role is set correctly, you'll be redirected to the **Admin Dashboard**
4. If the role is NOT "admin", you'll see an **"Access denied. Admin only."** error

---

## 🎯 Admin Features Overview

The admin panel includes three main features:

### 1. **Admin Dashboard**

- **Summary Statistics:**
  - Total Stalls
  - Active Stalls
  - Pending Reports
  - Total Users
- **Quick Actions:**
  - Manage Stalls → Navigate to stall management
  - View Reports → Navigate to reports screen

### 2. **Stall Management (CRUD)**

- **View All Stalls:** See list of all stalls with thumbnails
- **Add New Stall:** Create stalls with photos, categories, and details
- **Edit Stall:** Update existing stall information
- **Delete Stall:** Remove stalls with confirmation dialog
- **Features:**
  - Multi-image upload to Cloudinary
  - Image compression before upload
  - Upload progress tracking
  - Category dropdown (fresh, frozen, dry, cooked, etc.)
  - Products (comma-separated tags)
  - Operating hours (open/close time pickers)
  - Days open (day checkboxes)
  - Geolocation (latitude/longitude)
  - Active/Inactive toggle

### 3. **Reports Review**

- **View All Reports:** See user-submitted stall reports
- **Status Tracking:**
  - 🟠 **Pending** - New reports
  - 🔵 **Reviewed** - Admin has seen the report
  - 🟢 **Resolved** - Issue has been fixed
- **Actions:**
  - View full report details
  - Mark as Reviewed
  - Mark as Resolved

---

## 🚀 Using the Admin Panel

### Logging In

1. Navigate to **Admin Login** screen (`/admin/login`)
2. Enter your admin email and password
3. Click **"Login"**
4. If authenticated and role is "admin", you'll see the **Dashboard**

### Adding a Stall

1. From **Dashboard**, click **"Manage Stalls"**
2. Click the **"+ Add Stall"** FAB (Floating Action Button)
3. Fill in all required fields:
   - **Stall Name** (required)
   - **Category** (dropdown)
   - **Products** (comma-separated, e.g., `tomatoes, onions, garlic`)
   - **Address** (required)
   - **Photos** (click "Add Photos" to select multiple images)
   - **Open Time** & **Close Time** (tap to select from time picker)
   - **Days Open** (select day chips)
   - **Latitude** & **Longitude** (decimal numbers, e.g., `14.599512, 120.984222`)
   - **Active** (toggle switch)
4. Click **"Create Stall"**
5. **Photos will upload to Cloudinary** with progress indicator
6. Once saved, the stall appears in the list and on the map

### Editing a Stall

1. In **Manage Stalls**, find the stall to edit
2. Click the **blue Edit icon** (pencil)
3. Modify any fields
4. Add or remove photos (existing photos are retained unless deleted)
5. Click **"Update Stall"**

### Deleting a Stall

1. In **Manage Stalls**, find the stall to delete
2. Click the **red Delete icon** (trash)
3. Confirm deletion in the dialog
4. Stall is removed from Firestore (photos remain in Cloudinary)

### Reviewing Reports

1. From **Dashboard**, click **"View Reports"**
2. See all reports ordered by newest first
3. **Tap a report card** to view full details
4. Click **"Mark as Reviewed"** to update status to `reviewed`
5. Click **"Mark as Resolved"** to update status to `resolved`

---

## ☁️ Cloudinary Configuration

### Current Setup

The app is already configured to use **Cloudinary** for photo uploads:

**File:** `lib/core/services/cloudinary_service.dart`

```dart
static const String _cloudName = 'diiuzmjnk';
static const String _uploadPreset = 'merkadogo';
```

### Upload Folder

All stall images are uploaded to: **`merkadogo/stalls`** folder in Cloudinary.

### Verifying Uploads

1. Go to [Cloudinary Console](https://cloudinary.com/console)
2. Navigate to **Media Library**
3. Open the **`merkadogo/stalls`** folder
4. You should see all uploaded stall photos

### Changing Cloudinary Account (Optional)

If you need to use a different Cloudinary account:

1. **Open:** `lib/core/services/cloudinary_service.dart`
2. **Update these constants:**
   ```dart
   static const String _cloudName = 'YOUR_CLOUD_NAME';
   static const String _uploadPreset = 'YOUR_UPLOAD_PRESET';
   ```
3. **Create an upload preset** in Cloudinary:
   - Go to **Settings** → **Upload** → **Upload presets**
   - Create an **unsigned** upload preset
   - Note the preset name and use it in the code

---

## ✅ Testing Checklist

Before moving to Part 12, complete these tests:

### Step 1: Admin Authentication

- [ ] Create first admin account in Firestore
- [ ] Log in as admin successfully
- [ ] Try logging in with a non-admin account (should show error)
- [ ] Verify redirect to Admin Dashboard after login

### Step 2: Dashboard Statistics

- [ ] View summary cards (Total Stalls, Active Stalls, etc.)
- [ ] Verify counts are accurate
- [ ] Click "Manage Stalls" button
- [ ] Click "View Reports" button

### Step 3: Add Stall with Photos

- [ ] Click "+ Add Stall" FAB
- [ ] Fill all form fields
- [ ] Select 2-3 photos from gallery
- [ ] Verify thumbnails appear
- [ ] Click "Create Stall"
- [ ] Watch upload progress indicator
- [ ] Confirm success message

### Step 4: Verify Cloudinary Upload

- [ ] Open Cloudinary Console
- [ ] Navigate to `merkadogo/stalls` folder
- [ ] Verify uploaded photos appear
- [ ] Note the image URLs

### Step 5: Verify Stall on Map

- [ ] Exit admin panel
- [ ] Go to main Map screen
- [ ] Verify new stall marker appears at correct location
- [ ] Tap marker to view stall details
- [ ] Verify photos appear in carousel

### Step 6: Edit Stall

- [ ] Go back to Manage Stalls
- [ ] Click Edit icon on a stall
- [ ] Modify some fields
- [ ] Add/remove photos
- [ ] Save changes
- [ ] Verify updates in Firestore and on map

### Step 7: Delete Stall

- [ ] Click Delete icon on a stall
- [ ] Confirm deletion
- [ ] Verify stall is removed from list
- [ ] Verify marker disappears from map

### Step 8: Review Report

- [ ] Create a test report as a regular user
- [ ] Go to Admin Reports screen
- [ ] Verify report appears
- [ ] Click report to view details
- [ ] Mark as "Reviewed"
- [ ] Mark as "Resolved"
- [ ] Verify status badge updates

---

## 🎉 Confirmation

Once all tests pass, **type "YES"** to proceed to **Part 12**!

---

## 🛠️ Troubleshooting

### Issue: "Access denied. Admin only." error

**Solution:** Verify the user's Firestore document has `role: "admin"` field.

### Issue: Photos not uploading

**Solution:**

- Check internet connection
- Verify Cloudinary credentials in `cloudinary_service.dart`
- Check Cloudinary upload preset is **unsigned** and active

### Issue: Stall not appearing on map

**Solution:**

- Verify latitude and longitude are correct
- Check if stall `isActive` is set to `true`
- Ensure Firestore security rules allow reading stalls

### Issue: Can't delete stall

**Solution:**

- Check Firestore security rules allow admin users to delete
- Verify user role is "admin" in Firestore

---

## 📝 Summary

You've successfully implemented:
✅ **Admin Login** with Firebase Auth + Firestore role checking  
✅ **Admin Dashboard** with real-time statistics  
✅ **Stall Management** with full CRUD operations  
✅ **Cloudinary Photo Uploads** with progress tracking  
✅ **Reports Review** with status management

**Next:** Part 12 (Coming soon...)
