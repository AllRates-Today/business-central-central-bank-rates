# Central Bank Exchange Rates for Dynamics 365 Business Central — business-central-central-bank-rates

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Business Central](https://img.shields.io/badge/Business%20Central-23%2B-0078D4.svg)](app.json)
[![AL runtime](https://img.shields.io/badge/AL%20runtime-12.0-5C2D91.svg)](app.json)
[![dependencies](https://img.shields.io/badge/dependencies-0-brightgreen.svg)](app.json)
[![EUR/USD published by the ECB](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fallratestoday.com%2Fapi%2Fopen%2Fcentral-bank%2Fecb%3Fsource%3DEUR%26target%3DUSD&query=%24.rate&label=EUR%2FUSD%20published%20by%20ECB&color=0A7E8C&cacheSeconds=3600)](https://allratestoday.com/central-bank-rates-api/ecb/)
[![Powered by AllRatesToday](https://img.shields.io/badge/Powered%20by-AllRatesToday-orange.svg)](https://allratestoday.com/central-bank-rates-api/)

**An AL extension that imports the latest table published by a central bank or tax authority — the ECB, Bank of England, RBI, HMRC and 120 more — from the [AllRatesToday Central Bank Exchange Rate API](https://allratestoday.com/central-bank-rates-api/) into Business Central's *Currency Exchange Rates*, dated with the bank's own `rate_date`, in either quoting direction.**

> This is a code sample. It is written as conventional, careful AL for Business Central 23+ but has not been compiled or run against a sandbox in this repository. Review it, compile it with the AL Language extension, and test it in a sandbox before using it in production.

## 🚀 What it does

- 🏛️ **Official published rates** — one `GET /api/v1/central-bank/{bank}/latest` call per run, written to the *Currency Exchange Rate* table with `Starting Date = rate_date` (the publication date the bank states, not the run date).
- 🧭 **Both quoting directions** — each row is matched against *General Ledger Setup → LCY Code*, so ECB-style tables (foreign per 1 home) and RBI-style tables (home per 1 foreign) both land in the right fields.
- 🧮 **Only currencies you use** — rows whose currency is not in the *Currencies* list are skipped and counted, never auto-created.
- 🔁 **Scheduled or on demand** — codeunit `OnRun` is a Job Queue entry point; the setup page has *Import Rates Now* and *Create Job Queue Entry* actions.
- 🔐 **Key in Isolated Storage** — the API key is stored module-scoped (encrypted when encryption is enabled), not in a table field.
- 🧾 **Run diagnostics** — last run time, rate date, imported/skipped counts, the API's `stale` flag and the result message are kept on the setup record and logged to telemetry.
- 🧪 **Keyless evaluation** — leave the key empty and the extension reads the keyless copy at `https://allratestoday.com/api/open/central-bank/{bank}` (same table shape) so you can try it before signing up.

### Objects

| Object | ID | Name |
|---|---|---|
| Table | 50100 | `ART CB Rate Setup` |
| Page | 50100 | `ART CB Rate Setup Card` |
| Codeunit | 50100 | `ART CB Rate Import` |
| Permission set | 50100 | `ART CB Rates` |

## 🏁 Install

1. Clone this repository and open the folder in VS Code with the [AL Language extension](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al) installed.
2. Edit `.vscode/launch.json` so `environmentName` points at your sandbox, then run **AL: Download symbols**.
3. Press <kbd>F5</kbd> (**AL: Publish**) to compile and publish to the sandbox. `app.json` targets application `23.0.0.0`, runtime `12.0`, object range 50100–50149 with no dependencies beyond the base application.
4. Assign the **ART CB Rates** permission set (or SUPER) to the users and the Job Queue user who will run the import.

```bash
git clone https://github.com/AllRates-Today/business-central-central-bank-rates.git
code business-central-central-bank-rates
```

## ⚙️ Setup

1. Get a free API key at [allratestoday.com/register](https://allratestoday.com/register/). Latest tables are available on every plan; the Official Rates Business plan is on the [pricing page](https://allratestoday.com/pricing/#official).
2. Search for **Central Bank Rates Setup (AllRatesToday)**.
3. Enter the **Bank Code** — `ecb`, `boe`, `rbi`, `hmrc`, … — from the [coverage map](https://allratestoday.com/central-bank-rates-api/).
4. Paste the key into **API Key**. It is written to Isolated Storage and the field clears; **API Key Stored** turns on.
5. Optionally set **Rate Type Filter** (for example `reference`) when the publisher prints several types for one pair. Blank takes the first type published per currency.
6. Make sure every currency you want is in **Currencies**. Rows for other currencies are skipped and counted.
7. Choose **Import Rates Now**. The message shows the rate date and the imported/skipped counts; open **Currency Exchange Rates** to see one new line per currency dated with the bank's `rate_date`.

The call the extension makes, for reference (the key goes in the `Authorization: Bearer` header):

```http
GET https://allratestoday.com/api/v1/central-bank/ecb/latest
Authorization: Bearer art_live_your_key
Accept: application/json
```

```json
{
  "bank": "ecb",
  "name": "European Central Bank",
  "rate_date": "2026-10-09",
  "age_days": 2,
  "stale": false,
  "cadence": "daily",
  "rates": [
    { "base": "EUR", "quote": "USD", "type": "reference", "value": 1.1537 },
    { "base": "EUR", "quote": "GBP", "type": "reference", "value": 0.84763 }
  ],
  "disclaimer": "Official rates as published by the named central bank. On weekends/holidays the most recent published rate_date is returned."
}
```

`?format=xml`, `?format=csv` and `?format=xlsx` return the same table for importers that do not read JSON, and `?api_key=` on the URL replaces the header for tools that cannot set one. Add `?source=USD&target=EUR` for a single resolved pair (`rate`, `rate_type`, `derived`, `method`). This extension uses the JSON table only.

## 🧭 Reading the numbers

`value` is always **quote currency per 1 unit of base currency**. Business Central stores a rate as *Exchange Rate Amount* units of the foreign currency equal to *Relational Exch. Rate Amount* units of your local currency. The codeunit decides the mapping per row by checking which side equals *General Ledger Setup → LCY Code*:

| Published row | Bank quotes | Currency Code | Exchange Rate Amount | Relational Exch. Rate Amount |
|---|---|---|---|---|
| `base` = LCY (ECB: `EUR → USD 1.1537`, LCY `EUR`) | foreign per 1 home | `quote` (`USD`) | `value` (1.1537) | 1 |
| `quote` = LCY (RBI: `USD → INR 96.6149`, LCY `INR`) | home per 1 foreign | `base` (`USD`) | 1 | `value` (96.6149) |
| neither side = LCY | cross pair | — | skipped | skipped |

- The *Adjustment Exch. Rate Amount* fields are set to the same values, as the standard rate dialogs do.
- Rows are written as **one line per currency per `rate_date`**; a second run on the same table updates the same lines instead of adding duplicates.
- Choose a bank whose home currency is your LCY. A company whose LCY is `EUR` and bank is `rbi` gets only the single `EUR → INR` row (and only if `INR` is a set-up currency); everything else is a cross pair and is skipped. Every bank's direction and home currency are shown on its page under the coverage map.
- `stale: true` means the bank has not published for longer than its usual cadence. The flag is stored as **Last Table Stale** so you can review it; the table is still imported.
- Never divide a published rate yourself in a compliance workflow. If you need the pair the other way round, the API's `?source=&target=` form inverts or crosses it and flags the result `derived: true`.

## 🔁 Scheduling

**Create Job Queue Entry** on the setup page creates a recurring entry for codeunit 50100, Monday–Friday at 17:00 server time, 3 attempts with a 10-minute rerun delay, with status **On Hold**. Open the entry, set **Earliest Start Date/Time** to after the bank's publication time (the ECB publishes around 16:00 CET; each bank page on the [coverage map](https://allratestoday.com/central-bank-rates-api/) states its schedule), and set the status to **Ready**. Scheduled runs require **Enabled** on the setup page; manual runs do not.

Each run is one API call regardless of how many currencies the bank publishes — a daily bank is about 22 calls a month. For monthly publishers such as HMRC or the Swiss National Bank monthly averages, schedule one run a month after the publication date; `rate_date` is the first day the table applies.

## 🆚 Built-in Currency Exchange Rate Service vs this extension

Business Central ships with the **Currency Exchange Rate Service**, which fetches a URL on a schedule and maps XML nodes onto *Currency Exchange Rates*. It has been in the product since NAV 2015 and **needs no extension**. It works with this API as-is: it reads XML and cannot set headers, so point it at

```text
https://allratestoday.com/api/v1/central-bank/ecb/latest?format=xml&api_key=art_live_your_key
```

and map `rate` → parent node, `quote`/`base` → Currency Code, `rate_date` → Starting Date, `value` and a constant `1` → the two amount fields per the direction table above. The step-by-step procedure and the full field-mapping table are in the guide: **[Central Bank Exchange Rates in Dynamics 365 Business Central](https://allratestoday.com/docs/integrations/business-central/)**.

Use this extension instead when you want:

| | Built-in service | This extension |
|---|---|---|
| Install | none | AL extension |
| Key location | on the URL (`?api_key=`) | `Authorization: Bearer` header, Isolated Storage |
| Direction | chosen once in the mapping | resolved per row against LCY Code |
| Currencies not set up | mapping error / manual | skipped and counted |
| Rate type choice | filter in XPath or none | **Rate Type Filter** field |
| Run diagnostics | Job Queue log | setup page counters + telemetry |
| Try without a key | no | yes (`/api/open/`) |

If the built-in service covers your case, use it; it is the simpler path.

## 🏛️ Sources

The API covers **121 central banks and 3 tax authorities** (HMRC, the Swiss BAZG and the US Treasury). Each source is served under its own code from the bank's own publication, with the publisher's `rate_date`, `cadence` and `stale` flag on every response. Codes, home currencies, quoting directions and publication schedules are on the coverage map:

**[allratestoday.com/central-bank-rates-api](https://allratestoday.com/central-bank-rates-api/)**

Examples: `ecb` European Central Bank (EUR) · `boe` Bank of England (GBP) · `fed` US Federal Reserve H.10 (USD) · `rbi` Reserve Bank of India (INR) · `rba` Reserve Bank of Australia (AUD) · `boc` Bank of Canada (CAD) · `snb` Swiss National Bank (CHF) · `hmrc` HM Revenue & Customs (GBP).

## 🤖 AI agents

The same official tables are exposed through a hosted, keyless [Model Context Protocol](https://modelcontextprotocol.io) endpoint at **`https://allratestoday.com/api/mcp`** (Streamable HTTP). Point Claude Desktop, Cursor, or any MCP client at it to look up a bank's published rate, compare publishers or list the covered banks while you work on this extension — for example to check which direction a bank quotes before choosing it in Setup.

Agents that need keyed latest tables or crosses beyond the keyless endpoint can self-issue a trial key: `POST https://allratestoday.com/api/agent/keys` (send `Content-Type: application/json`) returns a 100-call key valid 7 days, no account needed (dated tables and history are paid-plan only, on free and trial keys alike); the MCP servers expose the same as `request_trial_key`.

## 🔗 Links

- [API Documentation](https://allratestoday.com/developers)
- [Register (Free)](https://allratestoday.com/register)
- [Dashboard](https://allratestoday.com/profile)
- [Status](https://allratestoday.com/status)
- [Postman collection](https://allratestoday.com/postman/)
- [GitHub](https://github.com/AllRates-Today/business-central-central-bank-rates)

## 📜 License

[MIT](LICENSE) © 2026 AllRatesToday.

---

*Official rates as published by the named central bank. On weekends/holidays the most recent published rate_date is returned.*
