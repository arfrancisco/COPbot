FROM ruby:3.4.5-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Create necessary directories
RUN mkdir -p tmp/pids tmp/cache log

# Expose port
EXPOSE 3000

# Start the server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

