# Comgate Webhook Integration Guide

## Webhook Endpoint
- URL: `POST /webhooks/comgate`
- Content-Type: `application/json`

## Security
- HMAC-SHA256 signature verification
- Header: `X-Signature`
- Secret: použije se z Rails credentials

## Parameters
- transId: Payment transaction ID
- refId: Order reference ID
- status: PAID/CANCELLED/TIMEOUT/PENDING
- price: Amount
- curr: Currency
- test: true/false

## Status Mapping
- PAID → payment_completed
- CANCELLED → payment_cancelled
- TIMEOUT → payment_failed
- PENDING → payment_pending

## Response Codes
- 200: Success
- 401: Invalid signature
- 422: Processing error
- 500: Internal error
