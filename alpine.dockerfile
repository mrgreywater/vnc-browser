# Use a minimal base image
FROM alpine:edge

# Build arguments to set environment variables at build time
ARG DEF_VNC_SCREEN=0
ARG DEF_VNC_DISPLAY=0
ARG DEF_VNC_RESOLUTION=1280x720
ARG DEF_VNC_PASSWORD=money4band
ARG DEF_VNC_PORT=5900
ARG DEF_NOVNC_WEBSOCKIFY_PORT=6080
ARG DEF_STARTING_WEBSITE_URL=https://www.google.com
ARG DEF_LANG=en_US.UTF-8
ARG DEF_LC_ALL=C.UTF-8
ARG DEF_CUSTOMIZE=false
ARG DEF_CUSTOM_ENTRYPOINTS_DIR=/app/custom_entrypoints_scripts
ARG DEF_AUTO_START_BROWSER=true
ARG DEF_AUTO_START_XTERM=true
ARG DEF_AUTO_START_WM=true
ARG DEF_AUTO_START_TIGERVNC=true
ARG DEF_AUTO_START_NOVNC=true
ARG DEF_BROWSER_OPTIONS=
ARG DEF_TIGERVNC_OPTIONS=
ARG DEF_WM_OPTIONS=
ARG DEF_NOVNC_OPTIONS=
ARG DEF_XTERM_OPTIONS=
ARG DEF_BROWSER_IDLE_PAUSE_ENABLED=true

# Set environment variables with default values
ENV DISPLAY=:${DEF_VNC_DISPLAY}.${DEF_VNC_SCREEN} \
    VNC_SCREEN=${DEF_VNC_SCREEN} \
    VNC_DISPLAY=${DEF_VNC_DISPLAY} \
    VNC_RESOLUTION=${DEF_VNC_RESOLUTION} \
    VNC_PASSWORD=${DEF_VNC_PASSWORD} \
    VNC_PORT=${DEF_VNC_PORT} \
    NOVNC_WEBSOCKIFY_PORT=${DEF_NOVNC_WEBSOCKIFY_PORT} \
    STARTING_WEBSITE_URL=${DEF_STARTING_WEBSITE_URL} \
    LANG=${DEF_LANG} \
    LC_ALL=${DEF_LC_ALL} \
    CUSTOMIZE=${DEF_CUSTOMIZE} \
    CUSTOM_ENTRYPOINTS_DIR=${DEF_CUSTOM_ENTRYPOINTS_DIR} \
    BROWSER_IDLE_PAUSE_ENABLED=${DEF_BROWSER_IDLE_PAUSE_ENABLED} \
    AUTO_START_BROWSER=${DEF_AUTO_START_BROWSER} \
    AUTO_START_XTERM=${DEF_AUTO_START_XTERM} \
    AUTO_START_WM=${DEF_AUTO_START_WM} \
    AUTO_START_TIGERVNC=${DEF_AUTO_START_TIGERVNC} \
    AUTO_START_NOVNC=${DEF_AUTO_START_NOVNC} \
    BROWSER_OPTIONS=${DEF_BROWSER_OPTIONS} \
    TIGERVNC_OPTIONS=${DEF_TIGERVNC_OPTIONS} \
    WM_OPTIONS=${DEF_WM_OPTIONS} \
    NOVNC_OPTIONS=${DEF_NOVNC_OPTIONS} \
    XTERM_OPTIONS=${DEF_XTERM_OPTIONS}

# Install necessary packages and setup noVNC
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add --no-cache \
    tini \
    supervisor \
    bash \
    tigervnc \
    novnc \
    websockify \
    fluxbox \
    xterm \
    nano \
    font-freefont \
    firefox && \
    ln -s /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html 

# Create necessary directories for supervisor and custom entrypoints
RUN mkdir -p /etc/supervisor.d /app/conf.d ${DEF_CUSTOM_ENTRYPOINTS_DIR}
RUN mkdir -p /var/log/supervisor

# Copy configuration files
COPY supervisord.conf /etc/supervisor.d/supervisord.conf
COPY conf.d/ /app/conf.d/
COPY base_entrypoint.sh customizable_entrypoint.sh /usr/local/bin/
COPY idle-watchdog.sh /usr/local/bin/
COPY browser_conf/firefox.conf /app/conf.d/

# Make the entrypoint scripts executable
RUN chmod +x /usr/local/bin/base_entrypoint.sh /usr/local/bin/customizable_entrypoint.sh /usr/local/bin/idle-watchdog.sh

# Expose the standard VNC and noVNC ports
EXPOSE ${VNC_PORT} ${NOVNC_WEBSOCKIFY_PORT}

# Set tini as the entrypoint and the custom script as the command
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/customizable_entrypoint.sh"]
