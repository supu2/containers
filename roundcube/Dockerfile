FROM roundcube/roundcubemail:1.6.11-fpm AS builder

USER root

# Install git, node, npm so we can clone the Kolab plugin and build CSS at runtime
RUN apt-get update && apt-get install -y --no-install-recommends git nodejs npm
RUN npm install -g less less-plugin-clean-css

WORKDIR /usr/local/share
# clone the Kolab roundcube‑plugins repo
RUN git clone https://git.kolab.org/diffusion/RPK/roundcubemail-plugins-kolab.git

WORKDIR /usr/local/share/roundcubemail-plugins-kolab

# build the Elastic theme CSS
RUN ln -s /usr/src/roundcubemail/skins . \
 && ./less-build.sh \
 && cd plugins/libkolab/skins/elastic \
 && ln -s libkolab.min.css libkolab.css

# Drop back to www‑data (same as upstream)
USER www-data

FROM roundcube/roundcubemail:1.6.11-fpm

COPY --from=builder /usr/local/share/roundcubemail-plugins-kolab \
     /kolab-rpk

WORKDIR /usr/src/roundcubemail

# 1) Remove every existing 'repositories' section
RUN composer config --unset repositories

# 2) Add your local path repo first
RUN composer config repositories.kolab-path \
      '{"type":"path","url":"/kolab-rpk/plugins/*","options":{"symlink":false}}'

# 3) Then add the Roundcube plugin catalog (excluding kolab/*)
RUN composer config repositories.roundcube-composer \
      '{"type":"composer","url":"https://plugins.roundcube.net","exclude":["kolab/*"]}'

WORKDIR /var/www/html