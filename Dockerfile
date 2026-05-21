FROM python:3.12-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev libxml2-dev libxslt1-dev libldap2-dev \
    libsasl2-dev libssl-dev libjpeg-dev zlib1g-dev libffi-dev \
    curl node-less && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN pip install --no-cache-dir -e .

FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 libxml2 libxslt1.1 libldap-2.5-0 libsasl2-2 \
    libjpeg62-turbo zlib1g libffi8 curl node-less \
    fonts-dejavu-core fonts-noto-cjk fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

WORKDIR /app

ENV ODOO_RC=/etc/odoo/odoo.conf

RUN mkdir -p /etc/odoo /var/lib/odoo /mnt/extra-addons && \
    useradd -m -d /var/lib/odoo -s /bin/bash odoo

RUN echo "[options]\n\
addons_path = /app/addons\n\
data_dir = /var/lib/odoo\n\
admin_passwd = admin\n\
db_host = \$DB_HOST\n\
db_port = \$DB_PORT\n\
db_user = \$DB_USER\n\
db_password = \$DB_PASSWORD\n\
db_name = \$DB_NAME\n\
http_port = 8069\n\
logfile = None\n\
proxy_mode = True" > /etc/odoo/odoo.conf

EXPOSE 8069

USER odoo

CMD ["python3", "-m", "odoo", "--config=/etc/odoo/odoo.conf"]
