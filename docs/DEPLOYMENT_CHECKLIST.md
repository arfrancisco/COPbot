# Telegram AI Concierge Bot - Deployment Checklist

## Pre-Deployment Setup

### 1. Telegram Bot Setup
- [ ] Created bot via @BotFather
- [ ] Saved bot token securely
- [ ] Added bot to channels as administrator
- [ ] Tested bot responds to messages

### 2. OpenAI Setup
- [ ] Created OpenAI account
- [ ] Generated API key
- [ ] Added payment method
- [ ] Set up usage limits/alerts

### 3. Local Testing
- [ ] Application runs locally
- [ ] Database migrations successful
- [ ] Bot connects and receives messages
- [ ] Embeddings generated successfully
- [ ] Search functionality works
- [ ] All tests pass (`bundle exec rspec`)

## Heroku Deployment

### Initial Setup
- [ ] Heroku account created
- [ ] Heroku CLI installed
- [ ] Logged in to Heroku (`heroku login`)
- [ ] Created new Heroku app

### Database Configuration
- [ ] Added PostgreSQL addon (Standard-0 or higher)
- [ ] Enabled pgvector extension
- [ ] Verified extension: `heroku pg:psql -c "SELECT * FROM pg_extension WHERE extname = 'vector';"`

### Environment Variables
Set via `heroku config:set`:
- [ ] `TELEGRAM_BOT_TOKEN`
- [ ] `OPENAI_API_KEY`
- [ ] `RAILS_ENV=production`
- [ ] `RAILS_SERVE_STATIC_FILES=true`
- [ ] `RAILS_LOG_TO_STDOUT=true`

### Deployment
- [ ] Git repository initialized
- [ ] Code committed to git
- [ ] Pushed to Heroku: `git push heroku main`
- [ ] Migrations ran: `heroku run rake db:migrate`
- [ ] Verified deployment: `heroku logs --tail`

### Dyno Configuration
- [ ] Scaled web dyno: `heroku ps:scale web=1`
- [ ] Scaled bot dyno: `heroku ps:scale bot=1`
- [ ] Verified both running: `heroku ps`

### Scheduler Setup
- [ ] Added Scheduler addon
- [ ] Configured daily job: `rake jobs:delete_old_messages`
- [ ] Set appropriate time (off-peak hours)

### Post-Deployment Verification
- [ ] Web dyno responding (health check endpoint)
- [ ] Bot dyno running: `heroku logs --tail --ps bot`
- [ ] Bot responds to `/start` command
- [ ] Bot processes channel messages
- [ ] Bot responds to `/ask` queries
- [ ] Embeddings being generated
- [ ] Search returns relevant results

## Monitoring Setup

### Heroku
- [ ] Review dyno metrics
- [ ] Check database performance
- [ ] Monitor error rates
- [ ] Set up logging alerts

### OpenAI
- [ ] Check usage dashboard
- [ ] Verify rate limits
- [ ] Set up billing alerts
- [ ] Monitor token consumption

### Telegram
- [ ] Verify bot status
- [ ] Test in all target channels
- [ ] Monitor user interactions

## Security Checklist

- [ ] All API keys secured in environment variables
- [ ] `.env` file in `.gitignore`
- [ ] No secrets in git history
- [ ] Master key secured (if using encrypted credentials)
- [ ] Database backups configured
- [ ] Rate limiting considered
- [ ] Error messages don't expose sensitive data

## Maintenance

### Daily
- [ ] Check Heroku logs for errors
- [ ] Verify bot is responding
- [ ] Monitor OpenAI usage/costs

### Weekly
- [ ] Review database size
- [ ] Check dyno performance
- [ ] Verify scheduler job running

### Monthly
- [ ] Review OpenAI costs
- [ ] Check Heroku costs
- [ ] Update dependencies if needed
- [ ] Review and rotate API keys

## Rollback Plan

If deployment fails:
```bash
# Rollback to previous release
heroku rollback

# Or rollback specific release
heroku releases
heroku rollback v123
```

## Emergency Contacts

- Heroku Support: https://help.heroku.com/
- OpenAI Support: https://help.openai.com/
- Telegram Support: https://telegram.org/support

## Notes

- Initial indexing may take time depending on channel message history
- Monitor OpenAI costs closely in first week
- Consider upgrading dyno size if performance issues occur
- pgvector requires PostgreSQL Standard-0 or higher ($50/month minimum)

---

**Deployment Date**: _____________

**Deployed By**: _____________

**Production URL**: _____________

**Notes**: _____________

