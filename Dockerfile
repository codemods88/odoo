FROM odoo:19.0

USER root

RUN mkdir -p /mnt/extra-addons

RUN echo "[options]\n\
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons\n\
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

USER odoo

EXPOSE 8069
