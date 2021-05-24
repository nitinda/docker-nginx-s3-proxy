FROM ubuntu:bionic

ENV NGINX_VERSION=1.19.9
# ENV S3_BUCKET_NAME=aws-s3-bucket-name

# apt stuff...
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y install curl build-essential libpcre3 libpcre3-dev zlib1g-dev libssl-dev git libxml2 libxml2-dev libxslt1.1 \
    libxslt1-dev libgd-dev libgeoip-dev geoip-bin perl libperl-dev lua-socket \
    && apt-get -y install --no-install-recommends build-essential curl ca-certificates \
    && apt-get -q -y clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/?? /usr/share/man/??_*

# download & compile ngix...
RUN mkdir nginx-build \
    && cd nginx-build \
    && curl -LO http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && curl -L -o ngx_aws_auth.tar.gz https://github.com/anomalizer/ngx_aws_auth/archive/refs/tags/2.1.1.tar.gz \
    tar zxvf ngx_aws_auth.tar.gz \
    && tar zxvf nginx-${NGINX_VERSION}.tar.gz \
    && cd /nginx-build/nginx-${NGINX_VERSION} \
    && ./configure --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --build=Ubuntu \
    --builddir=nginx-1.19.9 \
    --with-select_module \
    --with-poll_module \
    --with-threads \
    --with-http_addition_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module \
    --with-http_mp4_module \
    --with-http_perl_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_sub_module \
    --with-http_xslt_module \
    --with-http_ssl_module \
    --with-pcre \
    --with-file-aio \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-mail \
    --with-mail_ssl_module \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --add-module=../ngx_aws_auth-2.1.1 \
    --with-ld-opt="-Wl,-rpath,/usr/local/lib" \
    --with-debug \
    && make -j2 \
    && make install \
    && rm -rf /nginx-build \
    && mkdir --parents /var/lib/nginx

# use envplate to configure buckets from env vars (https://github.com/kreuzwerker/envplate)
COPY nginx.conf /etc/nginx/nginx.conf
# COPY config/mime.types /etc/nginx/mime.types

RUN adduser --system --home /nonexistent --shell /bin/false --no-create-home --disabled-login --disabled-password --gecos "nginx user" --group nginx \
    && addgroup nginx tty \
    && mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/proxy_temp /var/cache/nginx/scgi_temp /var/cache/nginx/uwsgi_temp \
    && chmod 700 /var/cache/nginx/* \
    && chown nginx:root /var/cache/nginx/* \
    && rm /etc/nginx/*.default \
    && mkdir /etc/nginx/{conf.d,snippets,sites-available,sites-enabled} \
    && chmod 755 /usr/sbin/nginx \
    && /usr/sbin/nginx -t

# Define mountable directories.
VOLUME ["/etc/nginx/sites-enabled", "/etc/nginx/certs", "/etc/nginx/conf.d", "/var/log/nginx", "/var/www/html"]

WORKDIR /etc/nginx

EXPOSE 80 443
CMD [ "/usr/sbin/nginx", "-g", "daemon off;" ]