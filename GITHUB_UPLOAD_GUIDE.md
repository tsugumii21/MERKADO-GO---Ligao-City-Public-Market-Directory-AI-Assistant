# 🚀 How to Upload MERKADO GO to GitHub

## ✅ Security Check - Your Secrets are Protected!

Your `.gitignore` file already includes:
```
.env  # Line 47 - NEVER COMMIT THIS
```

This means your **real API keys** in `.env` will NOT be uploaded to GitHub! ✅

---

## 📋 **Quick Upload Steps**

### **Option 1: Using Git Command Line** (Recommended)

#### Step 1: Initialize Git Repository
```bash
cd r:\Code\MerkadoGo
git init
```

#### Step 2: Add All Files
```bash
git add .
```

This will add all files EXCEPT:
- ❌ `.env` (your real API keys - protected by .gitignore)
- ✅ `.env.example` (safe template - will be uploaded)
- ❌ `build/` folders (temporary files)
- ❌ `.dart_tool/` (generated files)

#### Step 3: Create First Commit
```bash
git commit -m "Initial commit: MERKADO GO - Ligao City Public Market App"
```

#### Step 4: Create GitHub Repository
1. Go to https://github.com/new
2. Repository name: **merkado-go** (or any name you want)
3. Description: "MERKADO GO - Ligao City Public Market Directory & AI Assistant"
4. Choose: **Private** (recommended) or Public
5. **DO NOT** initialize with README (you already have one)
6. Click "Create repository"

#### Step 5: Connect to GitHub
```bash
# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/merkado-go.git
git branch -M main
git push -u origin main
```

---

### **Option 2: Using GitHub Desktop** (Easier for Beginners)

#### Step 1: Download GitHub Desktop
- Go to: https://desktop.github.com/
- Install and sign in with your GitHub account

#### Step 2: Add Repository
1. Open GitHub Desktop
2. Click "File" → "Add Local Repository"
3. Choose: `r:\Code\MerkadoGo`
4. Click "Create a repository" if prompted

#### Step 3: Create First Commit
1. You'll see all files listed (`.env` should NOT be there! ✅)
2. Add commit message: "Initial commit: MERKADO GO setup"
3. Click "Commit to main"

#### Step 4: Publish to GitHub
1. Click "Publish repository" button
2. Name: **merkado-go**
3. Description: "MERKADO GO - Ligao City Public Market App"
4. Choose: **Private** or Public
5. **UNCHECK** "Keep this code private" if you want it public
6. Click "Publish repository"

---

## 🔐 **Security Checklist Before Uploading**

Run these commands to verify your secrets are protected:

```bash
# Check what will be uploaded (should NOT show .env)
git status

# Double-check .env is ignored
git check-ignore .env
# Should output: .env ✅

# View what will be committed
git diff --cached
```

**⚠️ IMPORTANT: If you see `.env` in `git status`, STOP and don't commit!**

---

## 📁 **What WILL Be Uploaded to GitHub**

✅ **Safe Files:**
- All source code (`lib/`, `android/`)
- `pubspec.yaml` (dependencies)
- `README.md` (documentation)
- `.env.example` (template with placeholders)
- `google-services.json` (Firebase config - safe, non-secret)
- Documentation files (SETUP.md, etc.)

❌ **Protected Files (Won't Upload):**
- `.env` (your real API keys)
- `build/` (temporary build files)
- `.dart_tool/` (generated files)
- `android/local.properties` (local SDK paths)

---

## 🎯 **Complete Command Sequence**

Copy and paste these commands one by one:

```bash
# 1. Navigate to project
cd r:\Code\MerkadoGo

# 2. Initialize Git
git init

# 3. Add all files (respects .gitignore)
git add .

# 4. Verify .env is NOT staged
git status | findstr ".env"
# Should show nothing or only ".env.example"

# 5. Create first commit
git commit -m "Initial commit: MERKADO GO - Part 1 Complete

- Flutter project setup (Android only)
- Firebase integration (Auth, Firestore, FCM)
- Cloudinary service for image uploads
- Google Maps integration
- Gemini AI chatbot setup
- Complete authentication foundation
- Environment variables template (.env.example)"

# 6. Create GitHub repo first (via web), then:
git remote add origin https://github.com/YOUR_USERNAME/merkado-go.git
git branch -M main
git push -u origin main
```

---

## 🔄 **For Future Updates**

After making changes:

```bash
# Check what changed
git status

# Add changes
git add .

# Commit with message
git commit -m "Description of what you changed"

# Push to GitHub
git push
```

---

## ⚠️ **CRITICAL: Never Commit These Files**

If you accidentally modified these, make sure they stay ignored:

```bash
# Force ignore these if needed
echo ".env" >> .gitignore
echo "android/local.properties" >> .gitignore
```

---

## 🆘 **Emergency: I Accidentally Committed .env!**

If you accidentally committed your API keys:

```bash
# Remove from Git history (but keep local file)
git rm --cached .env

# Commit the removal
git commit -m "Remove .env from Git"

# Push changes
git push

# IMPORTANT: Regenerate ALL your API keys!
# The old keys are now in Git history and should be considered compromised
```

Then immediately:
1. Go to Cloudinary, Google Cloud Console, and Google AI Studio
2. **Delete/regenerate ALL API keys**
3. Update your `.env` with new keys

---

## ✅ **Verify Upload Success**

After pushing to GitHub:

1. Go to your GitHub repository page
2. Click on files and verify:
   - ✅ `.env.example` is there (template)
   - ❌ `.env` is NOT there (your secrets)
   - ✅ `README.md` is visible
   - ✅ All code is uploaded

---

## 🎯 **Recommended Repository Settings**

### **Make it Private** if you want to:
- Keep your project confidential
- Control who can see the code
- Work on it before public release

### **Make it Public** if you want to:
- Share with the community
- Build a portfolio
- Get feedback from other developers

**Either way, your `.env` file with real API keys is protected!** ✅

---

## 📝 **Good Commit Message Examples**

```bash
# Feature addition
git commit -m "Add authentication screens with email verification"

# Bug fix
git commit -m "Fix Cloudinary upload compression issue"

# Configuration
git commit -m "Update Firebase configuration for production"

# Documentation
git commit -m "Update README with installation instructions"
```

---

## 🎉 **You're Ready to Upload!**

Your project is properly configured for GitHub. Choose Option 1 (Command Line) or Option 2 (GitHub Desktop) and follow the steps above.

**Remember: `.env` is protected by `.gitignore` - your secrets are safe!** 🔐
