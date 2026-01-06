# Focus Logger Web Deployment Guide

This guide covers how to deploy, update, and manage the Focus Logger web app.

## Live URL

🌐 **https://focus-logger.netlify.app**

---

## Quick Reference

| Action | Command |
|--------|---------|
| Build | `flutter build web --release --base-href "/"` |
| Deploy | `netlify deploy --dir=build/web --prod` |
| Preview (draft) | `netlify deploy --dir=build/web` |
| View logs | `netlify open --admin` |

---

## Prerequisites

1. **Flutter SDK** (3.0.0+)
   ```bash
   flutter --version
   ```

2. **Node.js & npm** (for Netlify CLI)
   ```bash
   node --version
   npm --version
   ```

3. **Netlify CLI**
   ```bash
   npm install -g netlify-cli
   netlify login  # First-time only
   ```

---

## First-Time Deployment

If you're setting up deployment on a new machine or haven't deployed before:

```bash
# 1. Install Netlify CLI
npm install -g netlify-cli

# 2. Login to Netlify
netlify login

# 3. Build the Flutter web app
flutter build web --release --base-href "/"

# 4. Deploy (creates new site if not linked)
netlify deploy --dir=build/web --prod
```

---

## How to Update the App

When you make code changes and want to deploy them:

```bash
# 1. Build the latest version
flutter build web --release --base-href "/"

# 2. Deploy to production
netlify deploy --dir=build/web --prod
```

**Optional: Preview before going live**

```bash
# Deploy to a preview URL (not production)
netlify deploy --dir=build/web

# This gives you a temporary URL to test
# If everything looks good, add --prod to deploy to production
```

---

## Configuration Files

### `web/_redirects`
Handles SPA routing - ensures all routes load the Flutter app:
```
/*    /index.html   200
```

### `netlify.toml`
Contains build settings and caching headers:
- **Security headers**: X-Frame-Options, X-Content-Type-Options
- **Asset caching**: 1 year cache for JS, WASM, icons, fonts
- **HTML caching**: No-cache for index.html (always serve latest)

---

## Supabase Integration

The Supabase configuration in `lib/main.dart` works identically on:
- Localhost development
- Production deployment

**No changes needed!** The anon key is designed to be publicly accessible. Row Level Security (RLS) on the Supabase side handles data protection.

---

## Switching Hosting Providers

### To Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Build Flutter web
flutter build web --release --base-href "/"

# Deploy
cd build/web
vercel --prod
```

Create `vercel.json` in project root for SPA routing:
```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

### To Cloudflare Pages

```bash
# Install Wrangler CLI
npm install -g wrangler

# Build Flutter web
flutter build web --release --base-href "/"

# Deploy
wrangler pages deploy build/web --project-name=focus-logger
```

Create `build/web/_routes.json` for SPA routing:
```json
{
  "version": 1,
  "include": ["/*"],
  "exclude": []
}
```

### To Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize (first time only)
firebase init hosting
# Select: build/web as public directory
# Configure as SPA: Yes

# Build and deploy
flutter build web --release --base-href "/"
firebase deploy --only hosting
```

---

## Troubleshooting

### Page shows 404 on refresh
- Ensure `web/_redirects` file exists
- Rebuild: the `_redirects` file must be in `build/web/`

### Old version still showing
- Hard refresh: `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)
- Clear browser cache
- Check Netlify dashboard for deploy status

### Supabase not working
- Check browser console for CORS errors
- Verify Supabase URL and anon key in `lib/main.dart`
- Ensure Supabase RLS policies are configured

### Build fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --base-href "/"
```

---

## Useful Netlify Commands

```bash
# Check login status
netlify status

# Open Netlify dashboard
netlify open --admin

# View deploy logs
netlify deploy:list

# Rollback to previous deploy
netlify deploy --restore <deploy-id>

# Unlink project
netlify unlink
```

---

## Continuous Deployment (Optional)

For automatic deployments on git push, connect your GitHub repo to Netlify:

1. Go to https://app.netlify.com
2. Select your site → Site settings → Build & deploy
3. Connect to GitHub
4. Set build command: `flutter build web --release --base-href "/"`
5. Set publish directory: `build/web`

> ⚠️ Note: This requires Flutter to be available in Netlify's build environment. You may need a custom build image or use the [flutter-action](https://github.com/subosito/flutter-action) in a GitHub Actions workflow instead.
