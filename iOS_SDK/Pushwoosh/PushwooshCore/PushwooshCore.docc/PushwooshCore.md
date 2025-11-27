# ``PushwooshCore``

Core foundation module for Pushwoosh SDK.

## Overview

PushwooshCore provides the foundational components and infrastructure for the Pushwoosh SDK ecosystem. This module contains shared types, configuration interfaces, logging utilities, and messaging primitives used across all Pushwoosh frameworks.

Key capabilities:
- SDK configuration and initialization
- Device registration management
- User identification and tagging
- Push notification handling
- Logging and debugging utilities
- Message payload parsing

## Topics

### Configuration

- ``PushwooshConfig``

  Main configuration interface for SDK setup and management.

- ``PWConfiguration``

  Protocol defining SDK configuration methods.

### Message Handling

- ``PWMessage``

  Encapsulates push notification payload data including title, body, custom data, and deep links.

### Type Definitions

- ``PushwooshRegistrationHandler``

  Completion handler for push notification registration.

- ``PushwooshGetTagsHandler``

  Completion handler for retrieving device tags.

- ``PushwooshErrorHandler``

  Completion handler for error responses.

### Logging

- ``PushwooshLog``

  Logging interface for SDK debugging.

- ``PWDebug``

  Protocol for debug configuration.

- ``PUSHWOOSH_LOG_LEVEL``

  Enumeration of available log levels.

### Utilities

- ``PWCoreUtils``

  Core utility methods for the SDK.

- ``PUSHWOOSH_VERSION``

  Current SDK version constant.

### Core Manager

- ``PushwooshCoreManager``

  Internal manager for core SDK operations.

