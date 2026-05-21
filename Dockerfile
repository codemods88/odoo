FROM odoo:19.0

USER root

RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /mnt/extra-addons

COPY entrypoint.sh /entrypoint-custom.sh
RUN chmod +x /entrypoint-custom.sh

USER odoo

ENTRYPOINT ["/entrypoint-custom.sh"]
CMD ["odoo"]
