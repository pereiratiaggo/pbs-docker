FROM fdrake/proxmox-backup-client:latest

ENV DEBIAN_FRONTEND=noninteractive

# Ensure bash is available for the entrypoint
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD []
