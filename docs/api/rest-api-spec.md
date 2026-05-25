# DGSN REST API Specification

## Overview

The DGSN REST API provides HTTP/JSON access to the Decentralized Ground Station Network. The API is auto-generated from protobuf definitions using grpc-gateway. All endpoints are also available via gRPC.

## Base URL

`https://api.dgsn.io/v1` (production)
`http://localhost:8080/v1` (development)

## Authentication

All API requests require authentication via:
- **API Key**: `Authorization: Bearer <api_key>` header
- **OAuth 2.0**: JWT tokens for user-based access

## Common Headers

| Header          | Description                    | Required |
|-----------------|--------------------------------|----------|
| Authorization   | Bearer token or API key        | Yes      |
| X-Request-ID    | Request tracing ID             | No       |
| Content-Type    | application/json               | Yes      |
| Accept          | application/json               | Yes      |

## Error Format

```json
{
  "error": {
    "code": "STATION_NOT_FOUND",
    "message": "Station with ID 'abc-123' not found",
    "details": {
      "station_id": "abc-123"
    }
  }
}
```

## Endpoints

### Stations

#### Register Station
`POST /v1/stations`

Register a new ground station.

**Request Body:**
```json
{
  "name": "MIT-1",
  "description": "MIT Haystack Observatory UHF Station",
  "location": {
    "latitude": 42.623,
    "longitude": -71.489,
    "altitude_meters": 132.0
  },
  "capabilities": {
    "supported_modulations": ["BPSK", "QPSK", "GMSK"],
    "supported_frequencies": [
      {"center_frequency_hz": 100000000, "bandwidth_hz": 1000000}
    ],
    "max_bitrate_bps": 10000000,
    "min_elevation_degrees": 5.0,
    "num_antennas": 2,
    "antenna_type": "Yagi"
  },
  "timezone": "America/New_York",
  "contact_email": "operator@mit.edu",
  "is_public": true,
  "tags": ["university", "uhf", "amateur"]
}
```

**Response:** `201 Created`
```json
{
  "station": {
    "id": "station-abc-123",
    "name": "MIT-1",
    "status": "online",
    "created_at": "2024-06-10T12:00:00Z"
  },
  "api_key": "dgsn_key_abc123"
}
```

#### Get Station
`GET /v1/stations/{station_id}`

#### List Stations
`GET /v1/stations`

**Query Parameters:**
| Parameter        | Type   | Description                          |
|------------------|--------|--------------------------------------|
| page_size        | int    | Items per page (default: 20)         |
| page_token       | string | Pagination cursor                    |
| status           | string | Filter by status (online, offline)   |
| near_lat         | float  | Filter by latitude proximity         |
| near_lng         | float  | Filter by longitude proximity        |
| max_distance_km  | float  | Maximum distance for proximity filter|

#### Update Station Status
`PATCH /v1/stations/{station_id}/status`

### Receipts

#### Create Receipt
`POST /v1/receipts`

Create a proof-of-reception receipt after a satellite pass.

#### Get Receipt
`GET /v1/receipts/{receipt_id}`

#### Verify Receipt
`POST /v1/receipts/{receipt_id}/verify`

#### List Receipts
`GET /v1/receipts`

### Schedule

#### Get Schedule
`GET /v1/schedule`

**Query Parameters:**
| Parameter    | Type   | Description                  |
|--------------|--------|------------------------------|
| from         | string | Start time (ISO 8601)        |
| to           | string | End time (ISO 8601)          |
| station_id   | string | Filter by station            |
| satellite_id | string | Filter by satellite          |

#### Optimize Schedule
`POST /v1/schedule/optimize`

Run quantum optimization to generate optimal schedule.

### Signals

#### Upload Capture
`POST /v1/signals/upload`

Upload IQ sample data for processing.

**Request:** multipart/form-data
- `capture`: JSON metadata
- `samples`: binary IQ data (cf32 format)

#### Process Signal
`POST /v1/signals/{capture_id}/process`

### Quantum

#### Submit Circuit
`POST /v1/quantum/circuits`

#### Get Circuit Result
`GET /v1/quantum/circuits/{circuit_id}/result`

## Rate Limiting

| Tier     | Rate Limit     | Burst |
|----------|----------------|-------|
| Free     | 100 req/min    | 200   |
| Pro      | 1000 req/min   | 2000  |
| Enterprise| 10000 req/min | 20000 |

## WebSocket Endpoints

### Schedule Updates
`ws://api.dgsn.io/v1/ws/schedule`

Stream real-time schedule changes.

### Signal Stream
`ws://api.dgsn.io/v1/ws/signal/{capture_id}`

Stream real-time signal processing results.
