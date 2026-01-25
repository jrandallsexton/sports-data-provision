# Azurite - Azure Storage Emulator
FROM mcr.microsoft.com/azure-storage/azurite:latest

# Expose default ports
# 10000: Blob service
# 10001: Queue service  
# 10002: Table service
EXPOSE 10000 10001 10002

# Create data directory for persistence
RUN mkdir -p /data

# Start Azurite with persistence
# --skipApiVersionCheck: Allow newer Azure SDK API versions that Azurite may not officially support yet
CMD ["azurite", "--blobHost", "0.0.0.0", "--queueHost", "0.0.0.0", "--tableHost", "0.0.0.0", "--location", "/data", "--debug", "/data/debug.log", "--skipApiVersionCheck"]
