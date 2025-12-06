# Heroku Deployment Guide

## ✅ Pre-Deployment Checklist

Your app is now configured for Heroku deployment with:
- ✅ Ruby 3.3.6 (Heroku-24 compatible)
- ✅ Procfile with web, bot, worker, and release processes
- ✅ app.json with all required addons (PostgreSQL, Redis, Scheduler)
- ✅ Database configuration with ENV['DATABASE_URL']
- ✅ JSONB embeddings (no pgvector extension needed)
- ✅ Production environment configuration

## 🚀 Deployment Steps

### 1. Install Heroku CLI
```bash
# If not already installed
curl https://cli-assets.heroku.com/install.sh | sh
heroku login
```

### 2. Create Heroku App
```bash
# Create new app
heroku create your-app-name

# Or if using app.json (recommended)
heroku create your-app-name --manifest
```

### 3. Add Required Addons
If not using `app.json`, manually add:
```bash
heroku addons:create heroku-postgresql:standard-0
heroku addons:create heroku-redis:mini
heroku addons:create scheduler:standard
```

### 4. Set Environment Variables
```bash
heroku config:set TELEGRAM_BOT_TOKEN="your-bot-token"
heroku config:set OPENAI_API_KEY="your-openai-key"
heroku config:set RAILS_ENV=production
heroku config:set RAILS_LOG_TO_STDOUT=true
heroku config:set RAILS_SERVE_STATIC_FILES=true
```

### 5. Deploy
```bash
git push heroku main
# Or if on a different branch:
git push heroku your-branch:main
```

### 6. Run Migrations
```bash
heroku run rake db:migrate
```

### 7. Scale Dynos
```bash
# Start the bot and worker
heroku ps:scale web=1 bot=1 worker=1
```

### 8. Check Logs
```bash
heroku logs --tail
heroku logs --source app --tail
heroku logs --ps bot --tail
```

## 📊 Monitor Your App

```bash
# Check dyno status
heroku ps

# Check addon status
heroku addons

# Open app in browser
heroku open

# Access Rails console
heroku run rails console
```

## 🔧 Troubleshooting

### Bot Not Responding
```bash
# Check bot logs
heroku logs --ps bot --tail

# Restart bot dyno
heroku ps:restart bot
```

### Background Jobs Not Running
```bash
# Check worker logs
heroku logs --ps worker --tail

# Check Redis connection
heroku redis:info

# Restart worker
heroku ps:restart worker
```

### Database Issues
```bash
# Check database connection
heroku pg:info

# Access database console
heroku pg:psql
```

## 💰 Cost Estimation

Based on your current configuration:
- **Hobby dynos** (if you downgrade): $0/month for web + ~$7/month for bot + ~$7/month for worker = **~$14/month**
- **Basic dynos**: ~$7/month each × 3 = **~$21/month**
- **PostgreSQL Standard-0**: **$50/month**
- **Redis Mini**: **$3/month**
- **Scheduler**: **$0/month** (free)

**Total**: ~$74-77/month

### To Reduce Costs:
```bash
# Use Hobby dynos instead of Basic
# Downgrade to Mini PostgreSQL
heroku addons:create heroku-postgresql:mini --app your-app-name
```

## 📝 Post-Deployment

1. **Set up Scheduler** for cleanup job:
   ```bash
   heroku addons:open scheduler
   ```
   Add job: `rake jobs:cleanup_old_messages` (daily at midnight)

2. **Test your bot** in Telegram

3. **Monitor resource usage**:
   ```bash
   heroku ps
   heroku logs --tail
   ```

## 🔄 Updating Your App

```bash
# Make changes locally
git add .
git commit -m "Your changes"
git push heroku main

# Watch deployment
heroku logs --tail
```

## 🆘 Support

- Heroku Docs: https://devcenter.heroku.com/
- Check status: https://status.heroku.com/
- Your logs: `heroku logs --tail`
