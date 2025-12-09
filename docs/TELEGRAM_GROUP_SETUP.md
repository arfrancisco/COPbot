# Telegram Group Setup Guide

This guide explains how to set up your bot in a new Telegram group so it can:
- Capture and store all group messages
- Respond to `/ask` queries based on stored messages
- Work with channels, groups, and supergroups

## Prerequisites

- Bot is running via Docker: `docker-compose up -d`
- `TELEGRAM_BOT_TOKEN` is set in your environment

## Step 1: Disable Privacy Mode (One-Time Setup)

Privacy mode prevents bots from seeing all messages in groups by default. You need to disable it once per bot.

1. Open Telegram and find **@BotFather**
2. Send: `/mybots`
3. Select your bot from the list
4. Click **Bot Settings**
5. Click **Group Privacy**
6. Click **Turn off** (disable)

You should see: *"Privacy mode is disabled for [YourBot]. It will have access to all messages in groups."*

⚠️ **Important**: This only needs to be done once. The setting applies to all future group additions.

## Step 2: Add Bot to Your Group

1. Open your Telegram group
2. Click on the group name (top) → **Add Members**
3. Search for your bot by username (e.g., `@YourBotName`)
4. Add the bot to the group

## Step 3: Make Bot an Administrator

The bot **must be an admin** to receive all messages, even with privacy mode disabled.

1. Open your Telegram group
2. Go to **Group Info** → **Administrators**
3. Click **Add Administrator**
4. Select your bot
5. Grant the following permissions (minimum required):
   - ✅ **No specific permissions needed** - just being in the admin list is enough
   - You can uncheck all permissions if you want

6. Click **Save** or **Done**

## Step 4: Verify Bot is Working

### Check Docker Logs

```bash
docker-compose logs -f bot
```

You should see:
```
Starting Telegram bot listener...
Bot connected successfully!
```

### Send a Test Message

1. Send any message in the group (e.g., "Hello bot!")
2. Check the logs - you should see:

```
================================================================================
Received message:
  Chat type: supergroup
  Chat ID: -100123456789
  Chat title: Your Group Name
  From: YourUsername
  Text: Hello bot!
================================================================================
✓ Storing message from supergroup
Enqueued channel message for processing: Hello bot!...
```

### Test Commands

Send these commands in the group:

```
/start
```
The bot should respond with a welcome message.

```
/help
```
The bot should show available commands.

```
@YourBotName What did we discuss earlier?
```
Mention the bot with your question. The bot should search stored messages and respond (if messages exist).

## Step 5: Verify Message Processing

Check that messages are being processed:

```bash
# View bot logs
docker-compose logs -f bot

# Check Rails console
docker-compose exec web rails console

# In console, check message count:
Message.count

# View recent messages:
Message.order(message_timestamp: :desc).limit(5)
```

## Architecture Overview

```
Telegram Group Message
  ↓
Bot (listens for messages)
  ↓
StoreChannelMessageJob (processes immediately)
  ↓
Generates embedding (OpenAI)
  ↓
Stores in PostgreSQL with pgvector
```

## Troubleshooting

### Bot doesn't see messages

- ✅ Check privacy mode is disabled in @BotFather
- ✅ Verify bot is an **administrator** in the group
- ✅ Remove and re-add the bot after changing privacy mode
- ✅ Restart bot: `docker-compose restart bot`

### "Conflict: terminated by other getUpdates" error

Only one bot instance can run at a time:

```bash
# Stop all instances
docker-compose down

# Kill any local processes
pkill -f "rake bot:listen"

# Start fresh
docker-compose up -d
```

### Messages aren't being stored

Check logs for errors:

```bash
docker-compose logs -f bot
```

Verify database connection:

```bash
docker-compose ps
```

### Bot doesn't respond to commands

- ✅ Commands must start with `/` (e.g., `/start`, not `start`)
- ✅ In groups, you must mention the bot: `@YourBotName question`
- ✅ Check bot logs for errors: `docker-compose logs -f bot`
- ✅ Make sure there are stored messages in the database

## Multiple Groups

You can add the same bot to multiple groups. Each message will be stored with its `channel_id` (group ID), allowing you to:
- Track which group each message came from
- Query messages across all groups
- Filter by specific groups (future enhancement)

## Channel Setup (Alternative to Groups)

For Telegram Channels (broadcast-only):

1. Create a Telegram Channel
2. Add your bot as an **Administrator**
3. Grant **"Post Messages"** permission (if you want the bot to post)
4. All channel posts will be automatically captured

Channels vs Groups:
- **Channels**: One-way broadcast, bot must be admin
- **Groups/Supergroups**: Two-way conversation, bot can respond to commands

## Monitoring

### Check stored messages

```bash
# Access Rails console
docker-compose exec web rails console

# Count messages
Message.count

# View recent messages
Message.order(created_at: :desc).limit(5).pluck(:text, :channel_id)
```

### Monitor jobs

Visit the Rails console to check message processing:

```bash
docker-compose exec web rails console

# Count messages
Message.count

# View recent messages
Message.order(created_at: :desc).limit(5).pluck(:text, :channel_id)

# Check query logs
UserQuery.recent.limit(10)
```

## Cleanup

To remove the bot:

1. Remove bot from the group (Group Info → Members → Remove)
2. Optionally delete stored messages from that group:

```bash
docker-compose exec web rails console
Message.where(channel_id: YOUR_GROUP_ID).delete_all
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `/start` | Show welcome message |
| `/help` | Show help and available commands |
| `@BotName question` | Ask a question in groups (mention bot) |
| Direct message | Ask questions in private chat |

## Next Steps

- Add more groups to capture messages from multiple sources
- Use the bot to query across all stored conversations
- Monitor query logs via Rails console
- Set up the scheduled job to delete old messages (90 days) - see [../README.md](../README.md)
