# Azure Service Bus Emulator

This directory contains the Docker configuration for running the Azure Service Bus emulator.

## Quick Start

Run with docker-compose:
```powershell
docker-compose up -d
```

## Connection String

Use this connection string in your local development:
```
Endpoint=sb://localhost;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<any-key>;UseDevelopmentEmulator=true;
```

**Note**: The SharedAccessKey can be any value when using the emulator - it's not validated.

## Ports

- **5672**: AMQP protocol

## Features Supported

- Queues
- Topics and Subscriptions
- Sessions
- Dead-letter queues
- Message scheduling
- Batch operations

## Data Persistence

Data is persisted in the `servicebus-data` Docker volume.

## Azure Service Bus Explorer

You can use Service Bus Explorer or Azure SDK tools to connect to `localhost:5672`.
