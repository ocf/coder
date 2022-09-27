FROM codercom/enterprise-base:ubuntu

# Run everything as root
USER root

# Install a few packages so that the OCF apt key can be added and so that any
# pre-package installation commands work + support https mirrors
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates curl gnupg apt-transport-https

# use mirrors.ocf.berkeley.edu (https)
RUN sed -ri 's!http\:\/\/(httpredir|deb)\.ubuntu\.com!https\:\/\/mirrors.ocf.berkeley.edu!g; \
        s!http\:\/\/security\.ubuntu\.com!https\:\/\/mirrors.ocf.berkeley.edu!g' \
        /etc/apt/sources.list

# Install Node 16
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN DEBIAN_FRONTEND="noninteractive" apt-get update -y && \
    apt-get install -y nodejs

# Install Yarn
RUN corepack enable
RUN yarn set version stable

# Set back to coder user
USER coder
