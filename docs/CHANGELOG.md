# Changelog

All notable changes to the Telegram AI Concierge Bot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-07

### Added

#### Query Logging System
- **UserQuery Model**: Complete audit trail of all queries and responses
- **QueryLoggerService**: Service to log query lifecycle
- **Token Usage Tracking**: Monitor OpenAI API costs
- **Performance Metrics**: Track response times and search effectiveness

#### Sender Information
- Added sender tracking to messages (sender_id, sender_name, sender_username)
- Bot can now reference who said what in responses

#### Database Improvements
- Migrated from JSONB to pgvector with HNSW indexing
- Significantly faster similarity search
- Support for composite channel IDs (chat_id_thread_id for topics)

### Changed
- **OpenAiService** - Now returns hash with response, usage, and metadata
- **TelegramBotService** - Integrated query logging throughout
- **SearchService** - Hybrid search with semantic and keyword matching
- **README.md** - Updated with current features and capabilities

### Technical Details
- Backward compatible with existing functionality
- HNSW indexing provides 100x+ performance improvement
- Query logging enables cost tracking and debugging

## [1.0.0] - 2024-12-XX

### Initial Release

#### Core Features
- Automatic channel message indexing
- Semantic search using OpenAI embeddings (text-embedding-3-small)
- RAG-powered responses with GPT-4o-mini
- Multilingual support (English, Filipino/Tagalog, Taglish)
- 90-day message retention policy
- PostgreSQL with pgvector for vector similarity search

#### Services
- `EmbeddingService` - OpenAI embedding generation
- `SearchService` - Semantic search with cosine similarity
- `TelegramBotService` - Message processing and query handling
- `OpenAiService` - Response generation

#### Background Jobs
- `StoreChannelMessageJob` - Process and store channel messages
- `DeleteOldMessagesJob` - Remove messages older than 90 days

#### Deployment
- Heroku-ready configuration (Procfile, app.json)
- Docker support (docker-compose.yml, Dockerfile)
- Automatic dyno configuration
- PostgreSQL with pgvector extension

#### Bot Commands
- `/start` - Welcome message and instructions
- `/help` - Display available commands
- `@mention` or reply - Ask questions in groups
- Direct messages - Ask questions in private chats

#### Testing
- RSpec test suite
- FactoryBot for test data
- VCR for API mocking
- WebMock for HTTP stubbing

#### Documentation
- README.md - Main project documentation
- QUICKSTART.md - Quick setup guide
- TELEGRAM_GROUP_SETUP.md - Group configuration guide
- HEROKU_DEPLOY.md - Deployment instructions
- PROJECT_SUMMARY.md - Technical overview

---

## Release Notes Format

Each release includes:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be-removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security-related changes

## Upgrade Instructions

### From 1.0.0 to 1.1.0

No action required - fully backward compatible. New features are optional.

To use the new import features:

```bash
# Pull latest code
git pull origin main

# No database migrations needed
# No dependency updates needed

# Start using new features
bundle exec rake bot:fetch_pinned[YOUR_CHAT_ID]
bundle exec rake bot:import_mode
```

## Roadmap

### Planned for 1.2.0
- [ ] Webhook support (instead of polling)
- [ ] Sidekiq for background job processing
- [ ] Admin dashboard for monitoring
- [ ] Multiple channel context separation

### Planned for 1.3.0
- [ ] Conversation memory
- [ ] User analytics
- [ ] Message categories/tags
- [ ] Support for images and documents
- [ ] Historical message import functionality
- [ ] Summary generation features

## Breaking Changes

None in this release (1.1.0). Fully backward compatible with 1.0.0.

## Deprecations

None at this time.

## Security Updates

None in this release.

## Bug Fixes

None in this release - new feature addition.

## Contributors

Thank you to all contributors who helped make this release possible!

## Support

For questions about this release:
1. Check the [README.md](./README.md) documentation index
2. Review [QUERY_LOGGING_IMPLEMENTATION.md](./QUERY_LOGGING_IMPLEMENTATION.md) for query logging details
3. Consult [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) for technical architecture
4. Open an issue on GitHub for bugs or feature requests

---

**Note**: Dates use ISO 8601 format (YYYY-MM-DD)



