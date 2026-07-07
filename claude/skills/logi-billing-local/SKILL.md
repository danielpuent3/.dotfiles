# logi-billing-local

Hit local logi-billing endpoints with auth. Use when asked to call a local logi-billing API endpoint (calculate, commit, etc.).

## Auth flow

1. `POST http://localhost:8080/test/logi-x-auth?company_code=TEST` — returns a JWT as plain text; use it as the `LOGI-X-AUTH` header on subsequent requests.
2. Fetch the token and make the target request in a single shell pipeline so the token doesn't expire between steps.

## Example: calculate with persist

```bash
AUTH_TOKEN=$(curl -s -X POST "http://localhost:8080/test/logi-x-auth?company_code=TEST" -H "Content-Type: application/json")
TODAY=$(date +%Y-%m-%d)

curl -s -X POST "http://localhost:8080/billing/tax/calculate" \
  -H "Content-Type: application/json" \
  -H "LOGI-X-AUTH: $AUTH_TOKEN" \
  -d "{
    \"date\": \"$TODAY\",
    \"persist\": true,
    \"reference_code\": \"TEST_8_REFERENCE987654321\",
    \"currency_code\": \"USD\",
    \"billing_address\": {
      \"line1\": \"123 Elm Street\",
      \"line2\": \"Suite 456\",
      \"line3\": \"\",
      \"city\": \"Springfield\",
      \"region\": \"IL\",
      \"country_code\": \"US\",
      \"postal_code\": \"62701\"
    },
    \"line_items\": [
      {
        \"sku\": \"994-000250\",
        \"quantity\": 1,
        \"total_amount\": 19.00,
        \"tax_included\": true,
        \"description\": \"Widget B\"
      }
    ]
  }"
```

The persisted Avalara document ID is returned as `tax_engine_code` in the response.

## Example: commit

Pass the `tax_engine_code` from calculate as `"code"` — this commits the saved SalesInvoice to the Avalara ledger without recalculating.

```bash
AUTH_TOKEN=$(curl -s -X POST "http://localhost:8080/test/logi-x-auth?company_code=TEST" -H "Content-Type: application/json")
TODAY=$(date +%Y-%m-%d)

curl -s -X POST "http://localhost:8080/billing/tax/commit" \
  -H "Content-Type: application/json" \
  -H "LOGI-X-AUTH: $AUTH_TOKEN" \
  -d "{
    \"date\": \"$TODAY\",
    \"reference_code\": \"TEST_8_REFERENCE987654321\",
    \"code\": \"<tax_engine_code from calculate>\",
    \"currency_code\": \"USD\",
    \"billing_address\": {
      \"line1\": \"123 Elm Street\",
      \"line2\": \"Suite 456\",
      \"line3\": \"\",
      \"city\": \"Springfield\",
      \"region\": \"IL\",
      \"country_code\": \"US\",
      \"postal_code\": \"62701\"
    },
    \"line_items\": [
      {
        \"sku\": \"994-000250\",
        \"quantity\": 1,
        \"total_amount\": 19.00,
        \"tax_included\": true,
        \"description\": \"Widget B\"
      }
    ]
  }"
```

The response `tax_engine_code` will match the one from calculate, confirming the existing transaction was committed.

## Base URL

`http://localhost:8080`

## Key endpoints

- `POST /test/logi-x-auth?company_code=TEST` — auth token (no body)
- `POST /billing/tax/calculate` — calculate tax; `"persist": true` in body saves a SalesInvoice in Avalara and returns `tax_engine_code`
- `POST /billing/tax/commit` — commit a saved transaction; pass `"code": "<tax_engine_code>"` to commit without recalculating
- `GET  /billing/tax/{id}` — fetch a transaction by ID

## Notes

- Always use `company_code=TEST` — never change this for local dev
- Always use today's date (`date +%Y-%m-%d`) in the payload, never a hardcoded date
- Always fetch a fresh token immediately before the target request in the same shell command — the JWT has a short TTL
- The `LOGI-X-AUTH` header value is the raw JWT string (no `Bearer ` prefix)
