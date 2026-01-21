FROM hshar/webapp:latest

# Copy website files to Apache document root
COPY . /var/www/html/

# Ensure correct permissions (Apache needs read access)
RUN chown -R www-data:www-data /var/www/html/ \
    && chmod -R 755 /var/www/html/

# Apache already serves /var/www/html/ by default
# No CMD override needed
EXPOSE 80

# Ensure Apache starts cleanly
CMD ["/bin/bash", "-c", "pkill -f apache || true && apache2ctl -D FOREGROUND"]
