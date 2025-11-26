FROM php:8.3-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libbrotli-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Swoole
RUN pecl install swoole \
    && docker-php-ext-enable swoole

# Copy application files
COPY . /app
WORKDIR /app

# Expose port
EXPOSE 2000

# Run server
CMD ["php", "server.php"]
