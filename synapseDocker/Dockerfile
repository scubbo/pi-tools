FROM alpine:latest

ARG userPassword

WORKDIR /synapse

# Debug testing
RUN apk -U upgrade
RUN apk add --virtual .pynacl_deps build-base python3-dev libffi-dev openssl-dev gcc musl-dev cargo
RUN apk add py3-pip
# Prerequisites for Pillow
RUN apk add jpeg-dev libjpeg zlib tiff freetype libwebp tcl openjpeg
# DEBUG - explicitly instaling these for caching while trying to get this dockerfile to build,
# because they are _slooow_. In the real build, they will just get pulled in as dependencies
# of matrix-synapse
RUN pip3 install cryptography
RUN pip3 install pynacl
# TODO - this should be within line 12, but trying to build this Dockerfile progressively
RUN apk add zlib-dev
RUN pip3 install matrix-synapse
##
#
RUN python3 -m synapse.app.homeserver \
    --server-name matrix.scubbo.org \
    --config-path homeserver.yaml \
    --generate-config \
    --report-stats=yes
RUN sed -i "s/#enable_registration: false/enable_registration: true/" homeserver.yaml
RUN sed -i "s/bind_addresses: \['::1', /bind_addresses: \[/" homeserver.yaml
RUN sed -i "s/127.0.0.1/0.0.0.0/" homeserver.yaml
#
## This is near the bottom of the Dockerfile to minimize cache-busting
#RUN [ -z "$userPassword" ] && echo "userPassword is required" && exit 1 || true
#
#CMD synctl start; register_new_matrix_user -c homeserver.yaml -u scubbo -p "$userPassword" -a http://localhost:8008
# I tried using the version above, but setting the password with this gives an error "not a tty". Maybe just do it directly after startup?
CMD synctl start; tail -f /dev/null
# Then need to exec into a shell and create admin user
# Also run cloudflared tunnel