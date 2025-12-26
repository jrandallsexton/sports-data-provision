# Azurite Local Storage Emulator

This directory contains the Docker configuration for running Azurite, the Azure Storage emulator.

## Quick Start

Build and run:
```powershell
docker build -t azurite-local .
docker run -p 10000:10000 -p 10001:10001 -p 10002:10002 -v azurite-data:/data azurite-local
```

Or use docker-compose:
```powershell
docker-compose up -d
```

## Connection String

Use this connection string in your local development:
```
DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;
```

## Ports

- **10000**: Blob service
- **10001**: Queue service
- **10002**: Table service

## Data Persistence

Data is persisted in the `azurite-data` Docker volume.

## Azure Storage Explorer

You can connect Azure Storage Explorer to Azurite using:
- Account name: `devstoreaccount1`
- Account key: `Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==`
