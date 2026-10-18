# E2E Test Infra: Quincena - Captura OCR y Transacciones Quincenales

## Test Philosophy
- Opaque-box, requirement-driven. Derived from `ORIGINAL_REQUEST.md` (RF-03/05, RF-04/06, RN-03, CA-03.2, CA-04.2, CA-05.2, CA-05.3, CA-06.2).
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.
- Progressive testability: Tests verify domain invariants using available entrypoints (API endpoints and Flutter component/widget flows).

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | OCR Storage Upload | RF-03/RF-05, Bucket 'receipts' | 5 | 5 | ✓ |
| 2 | OCR Field Extraction & Pre-Confirmation | CA-03.2, CA-05.2 | 5 | 5 | ✓ |
| 3 | Category & Account Auto-Suggestion | CA-05.2, RN-CAT-01 | 5 | 5 | ✓ |
| 4 | OCR Fallback to Manual Form | CA-03.4, CA-05.3 | 5 | 5 | ✓ |
| 5 | History Feed & Date Grouping | RF-04/RF-06, Stitch feed | 5 | 5 | ✓ |
| 6 | Feed Search & Filter Chips | RF-04/RF-06, Stitch filters | 5 | 5 | ✓ |
| 7 | Transaction Card & Tabular Numbers | RF-04/RF-06, tnum | 5 | 5 | ✓ |
| 8 | Manual Expense Form & Decimal Keyboard | RF-04/RF-06, CA-04.1 | 5 | 5 | ✓ |
| 9 | Duplicate Detection Interception (RN-03) | RN-03 (409 Conflict & force) | 5 | 5 | ✓ |
| 10 | Real-time Category Balance Deduction | CA-04.2, CA-06.2 (<100ms) | 5 | 5 | ✓ |
| 11 | Dashboard Metrics Live Synchronization | CA-04.2, CA-06.2 (<100ms) | 5 | 5 | ✓ |

## Test Architecture
- **Backend Runner**: Jest (`npm test` in `quincena-api`) verifying API contracts, bucket normalization, and transaction deduplication.
- **Mobile Runner**: `flutter test` in `quincena/` executing unit, model, widget, and integration test flows.
- **Test Locations**:
  - `quincena/test/features/transactions/`
  - `quincena/test/features/ocr/`
  - `quincena-api/src/modules/transactions/`
  - `quincena-api/src/modules/receipt-scans/`

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Scanned Supermarket Ticket Flow | OCR upload -> pre-confirmation sheet -> auto-suggest Supermercado & Debit card -> confirm -> verify category balance deducted & appears in feed | High |
| 2 | Blurry Receipt Fallback Flow | Low-confidence / unreadable ticket -> automatic fallback banner -> manual form prefilled -> save expense -> verify history | Medium |
| 3 | Manual Coffee Expense with Duplicate Warning | User enters $4.50 coffee -> saves -> attempts identical save within 24h -> 409 warning prompt -> user confirms force -> 2 transactions recorded | High |
| 4 | Contextual Category Creation from Form | In manual entry form, user opens + Nueva Categoría -> creates "Mascotas" -> returns to form -> saves expense under "Mascotas" -> verify feed & bento tile | High |
| 5 | Feed Filtering & Search Real-Time | Add 5 mixed transactions -> filter by category -> filter by account -> search by merchant keyword -> verify instant sub-16ms filtering | Medium |
| 6 | Transaction Deletion Balance Recovery | User deletes $50 transaction from history -> verify active cycle category allocation spent amount reverts and available funds increase | Medium |

## Coverage Thresholds
- Tier 1: ≥5 per feature (55 test cases)
- Tier 2: ≥5 per feature where boundaries exist (55 test cases)
- Tier 3: pairwise coverage of major feature interactions (≥11 test cases)
- Tier 4: ≥6 realistic application scenarios
