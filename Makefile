.PHONY: help setup install test start bot console db-setup db-reset docker-up docker-down clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Run initial setup
	./bin/setup.sh

install: ## Install dependencies
	bundle install

test: ## Run tests
	bundle exec rspec

start: ## Start the web server
	bundle exec puma -C config/puma.rb

bot: ## Start the bot listener
	bundle exec rake bot:listen

console: ## Start Rails console
	bundle exec rails console

db-setup: ## Create and migrate database
	bundle exec rake db:create db:migrate

db-reset: ## Reset database
	bundle exec rake db:drop db:create db:migrate

db-seed: ## Seed database
	bundle exec rake db:seed

docker-up: ## Start Docker containers
	docker-compose up -d

docker-down: ## Stop Docker containers
	docker-compose down

docker-build: ## Build Docker containers
	docker-compose build

docker-logs: ## Show Docker logs
	docker-compose logs -f

clean: ## Clean temporary files
	rm -rf tmp/* log/*
	bundle exec rake tmp:clear log:clear

heroku-deploy: ## Deploy to Heroku
	git push heroku main
	heroku run rake db:migrate
	heroku ps:scale web=1 bot=1

heroku-logs: ## Show Heroku logs
	heroku logs --tail --ps bot

.DEFAULT_GOAL := help

