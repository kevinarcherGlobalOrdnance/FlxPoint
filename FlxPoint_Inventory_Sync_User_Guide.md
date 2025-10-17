# FlxPoint Inventory Sync - User Guide

## Overview

The FlxPoint Inventory Sync process provides automated, bidirectional synchronization of inventory data between your Business Central system and the FlxPoint marketplace platform. This ensures that your product availability, pricing, and costs are always up-to-date across all sales channels connected through FlxPoint.

### What Does This Process Do?

The sync performs two main operations:

1. **Inbound Sync (FlxPoint → Business Central)**
   - Retrieves all inventory variants from FlxPoint
   - Enriches them with Business Central inventory levels, pricing, and costs
   - Matches products using UPC barcodes
   - Integrates with BigCommerce for web pricing

2. **Outbound Sync (Business Central → FlxPoint)**
   - Sends updated inventory quantities and prices back to FlxPoint
   - Updates marketplace listings with current availability
   - Applies pricing changes to all connected sales channels

---

## How the Sync Process Works

### Step 1: Data Retrieval from FlxPoint

The system connects to the FlxPoint API and downloads all inventory variants in your account:

- **Retrieval Method**: Paginated API calls (100 variants per page)
- **Data Retrieved**: 
  - Product identifiers (SKU, UPC, MPN, EAN, ASIN)
  - FlxPoint quantities (available, committed, incoming)
  - Supplier pricing (cost, list price, MSRP, MAP)
  - Product dimensions and weights
  - Shipping costs and dropship fees
  - FFL requirements and backorder settings
  - Timestamps (last modified, quantity changes)

**Important**: Each sync run clears and rebuilds the FlxPoint Inventory table to ensure data accuracy.

### Step 2: Product Matching

The system matches FlxPoint variants to Business Central items using **UPC barcodes**:

- Searches for matching Item References with type "Bar Code"
- If a match is found, the variant is linked to the Business Central item
- If no match exists, the variant is stored but not enriched with BC data

### Step 3: Business Central Data Enrichment

For matched items, the system calculates and adds Business Central data:

#### Cost Calculation
- Retrieves the item's unit cost from Business Central
- Adjusts for the unit of measure (UOM) if different from base UOM
- Formula: `Unit Cost × UOM Qty per Base`

#### Price Calculation
- Looks up the selling price from the configured Price List
- Uses the UPC as the Item Reference to find the correct price
- **Critical Rule**: If no price is found, quantity is set to 0 (hides product)

#### Quantity on Hand (QOH) Calculation

The system uses different calculation methods based on item type:

**Assembly BOM Items**
- Calculates how many assemblies can be made from available components
- Adds any pre-assembled finished goods in stock
- Subtracts outstanding sales orders
- Formula: `(Able to Make) + (On Hand) - (Sales Orders)`

**Ammunition & Magazine Items**
- Aggregates inventory across all units of measure
- Calculates in base UOM (individual rounds/units)
- Converts final result to selling UOM (boxes, cases)
- Accounts for mixed storage (partial boxes + full cases)

**Firearms**
- **Only counts items with 'NEW' variant code**
- Filters out used, refurbished, or other conditions
- Calculates from MAIN and SHIPPING zones only

**Standard Items**
- Sums available quantity from MAIN and SHIPPING zones
- Subtracts sales orders not yet picked
- Returns net available inventory

**Universal Rules for All Items:**
- Only counts inventory in MAIN and SHIPPING zones
- Excludes quantity already allocated to picks
- Accounts for unpicked sales order demand
- If item has no price, QOH is forced to 0

#### MAP (Minimum Advertised Price)
- Retrieved directly from the Business Central item master
- Used to enforce pricing policies across sales channels

### Step 4: BigCommerce Price Integration

For items with UPCs, the system optionally retrieves pricing from BigCommerce:

- Calls BigCommerce API to find products by UPC
- Stores web pricing in the FlxPoint Inventory record
- Continues sync even if BigCommerce lookup fails
- Used for price comparison and analysis

### Step 5: Outbound Updates to FlxPoint

After enrichment, the system identifies variants that need updates and sends changes back to FlxPoint:

#### Change Detection

Updates are sent only when:
- Business Central QOH differs from FlxPoint quantity
- Business Central price differs from FlxPoint MSRP
- Business Central price differs from FlxPoint list price

#### FlxPoint Enabled Check

Before sending quantity:
- System checks if the item is FlxPoint enabled (from Item card)
- **If enabled**: Sends actual Business Central QOH
- **If disabled**: Sends quantity as 0 (hides from marketplace)

This allows you to temporarily hide items without removing them from FlxPoint.

#### Data Sent to FlxPoint

Each variant update includes:
- **Quantity**: Business Central QOH (or 0 if disabled)
- **Cost**: Business Central unit cost (if > 0)
- **Inventory List Price**: Business Central selling price
- **MSRP**: Business Central selling price (same as list price)
- **MAP**: Business Central MAP value
- **Allow Backorders**: Inherited from FlxPoint settings
- **Custom Field "GOPRICE"**: Business Central price for external systems

#### Batch Processing

- Updates are sent in batches of 50 variants (FlxPoint API limit)
- Multiple batches are sent automatically if needed
- All updates use a single PUT request per batch for efficiency

---

## Prerequisites and Setup

### Required Configuration

1. **FlxPoint Setup**
   - Navigate to FlxPoint Setup in Business Central
   - Enter your FlxPoint API Key
   - Configure Price List Code (for retrieving selling prices)
   - Setup must have Code = 'DEFAULT'

2. **Item References (UPC Barcodes)**
   - Each item must have an Item Reference with:
     - Reference Type = "Bar Code"
     - Reference No. = UPC code (must match FlxPoint UPC)
     - Unit of Measure = Selling UOM

3. **Price Lists**
   - Create a price list with your selling prices
   - Use Item References (UPCs) to identify products
   - Configure the Price List Code in FlxPoint Setup

4. **Item Master Data**
   - Unit Cost must be maintained
   - MAP field should be populated for items requiring minimum pricing
   - Item Category Codes must be correct (FIREARMS, AMMUNITION, MAGAZINES)
   - FlxPoint Enabled field on Item card controls visibility

5. **BigCommerce Setup** (Optional)
   - Configure BigCommerce API credentials if web pricing is needed
   - System continues sync even if BigCommerce is not configured

### Warehouse Setup Requirements

For accurate inventory calculations:
- Zone Codes 'MAIN' and 'SHIPPING' must exist
- Bin contents must be maintained accurately
- Pick documents should be created for sales orders
- For firearms: Use variant code 'NEW' for saleable items

---

## Running the Sync

### Manual Execution

1. Search for "FlxPoint Inventory Sync" in Business Central
2. Run the codeunit directly (ID: 50711)
3. Process runs synchronously - wait for completion

### Scheduled Execution

Recommended: Set up a Job Queue Entry for automated sync:

1. Create a new Job Queue Entry
2. Object Type to Run: Codeunit
3. Object ID to Run: 50711
4. Recommended frequency: Every 15-30 minutes during business hours
5. Set to run on appropriate days/times for your business

### Execution Time

- Typical sync duration: 5-15 minutes depending on variant count
- Inbound sync takes longer (API pagination)
- Outbound sync is faster (only changed items)

---

## Understanding the Results

### FlxPoint Inventory Table

After sync, review the FlxPoint Inventory table:

**Key Fields to Monitor:**
- **Last Sync Date**: Timestamp of last sync
- **Business Central Item No.**: Shows if item was matched
- **Business Central QOH**: Your calculated available inventory
- **Business Central Price**: Your selling price
- **Business Central Cost**: Your cost (for margin analysis)
- **Quantity**: FlxPoint's current quantity (before update)
- **FlxPoint Enabled**: Shows if item is visible in marketplace

**Unmatched Items:**
- Items with blank "Business Central Item No." have no UPC match
- These items store FlxPoint data but don't sync inventory/prices
- Action: Create Item References with matching UPCs

### Items with Zero Quantity

An item may show zero quantity for several reasons:

1. **No Business Central Price**
   - Item has no price in the configured price list
   - System automatically sets QOH to 0
   - Action: Add price to price list using UPC reference

2. **FlxPoint Disabled**
   - Item has "FlxPoint Enabled" = No on Item card
   - System sends 0 to hide from marketplace
   - Action: Enable FlxPoint on item if it should be visible

3. **Actually Out of Stock**
   - No inventory in MAIN/SHIPPING zones
   - All inventory allocated to picks/sales orders
   - Action: Receive inventory or check warehouse locations

4. **For Firearms Only**
   - No inventory with variant code 'NEW'
   - Only new condition items are synced
   - Action: Verify variant codes on bin contents

---

## Special Item Handling

### Firearms
- **Condition Filtering**: Only 'NEW' variant items are counted
- **Compliance**: Ensures only new, saleable firearms are advertised
- **FFL Flag**: Requires FFL field is synced from FlxPoint

### Ammunition & Magazines
- **Mixed UOM Support**: Aggregates across boxes, cases, rounds
- **Base Conversion**: Calculates in individual rounds, converts to selling UOM
- **Rounding**: Rounds to whole selling units (can't sell 2.3 boxes)
- **Bulk Handling**: Efficiently manages high-volume inventory

### Assembly/BOM Items
- **Component-Based**: Calculates based on available components
- **Make-to-Order**: Shows how many can be assembled from stock
- **Component Shortages**: Automatically limits based on constraining component
- **Pre-Built Stock**: Adds any already-assembled items to availability

### Standard Items
- **Zone-Based**: Only MAIN and SHIPPING zones counted
- **Allocation-Aware**: Subtracts unpicked sales order demand
- **UOM Flexible**: Handles different selling UOMs correctly

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    SYNC PROCESS OVERVIEW                     │
└─────────────────────────────────────────────────────────────┘

STEP 1: INBOUND SYNC (FlxPoint → Business Central)
┌──────────────┐
│  FlxPoint    │
│     API      │
│              │
│  Inventory   │
│  Variants    │
└──────┬───────┘
       │ GET /inventory/variants (paginated)
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│ Business Central - FlxPoint Inventory Table                  │
│                                                               │
│ • Clear all existing records                                 │
│ • Import all variants from FlxPoint                          │
│ • Parse product data (SKU, UPC, quantities, pricing)         │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│             PRODUCT MATCHING (UPC Barcode)                  │
│                                                             │
│  FlxPoint UPC  →  Item Reference  →  Business Central Item │
└────────────────────────────┬────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
        ┌──────────────┐          ┌─────────────┐
        │  MATCHED     │          │  UNMATCHED  │
        │  Items       │          │  Items      │
        └──────┬───────┘          └─────────────┘
               │                   (Stored, not enriched)
               ▼
┌──────────────────────────────────────────────────────────────┐
│              BUSINESS CENTRAL ENRICHMENT                      │
│                                                               │
│  Calculate:                                                   │
│  ✓ Unit Cost (with UOM adjustment)                          │
│  ✓ Selling Price (from Price List)                          │
│  ✓ Available Quantity (by item type):                       │
│    - Firearms: NEW variant only                             │
│    - Ammunition: Base UOM aggregation                       │
│    - Assembly: BOM tree calculation                         │
│    - Standard: Bin availability                             │
│  ✓ MAP (from Item master)                                   │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │  BigCommerce    │
                   │  Price Lookup   │ (Optional)
                   │  (by UPC)       │
                   └────────┬────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│           ENRICHED FLXPOINT INVENTORY RECORDS                 │
│                                                               │
│  • FlxPoint data + Business Central data combined            │
│  • Ready for comparison and outbound sync                    │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │
STEP 2: OUTBOUND SYNC (Business Central → FlxPoint)
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                   CHANGE DETECTION                            │
│                                                               │
│  Compare:                                                     │
│  • Business Central QOH  vs  FlxPoint Quantity               │
│  • Business Central Price  vs  FlxPoint MSRP                 │
│  • Business Central Price  vs  FlxPoint List Price           │
│                                                               │
│  Filter: Only variants with differences                      │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│              FLXPOINT ENABLED CHECK                           │
│                                                               │
│  IF Item.FlxPoint Enabled = TRUE                            │
│    → Send actual Business Central QOH                        │
│  ELSE                                                         │
│    → Send quantity = 0 (hide from marketplace)               │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  BUILD JSON PAYLOAD                           │
│                                                               │
│  For each changed variant:                                   │
│  {                                                            │
│    "inventoryVariantId": "xxx",                              │
│    "sku": "xxx",                                             │
│    "quantity": [BC QOH or 0],                                │
│    "cost": [BC Cost],                                        │
│    "inventoryListPrice": [BC Price],                         │
│    "msrp": [BC Price],                                       │
│    "map": [BC MAP],                                          │
│    "allowBackorders": [FlxPoint setting],                    │
│    "customFields": [{"name":"GOPRICE", "value":"[BC Price]"}]│
│  }                                                            │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    BATCH PROCESSING                           │
│                                                               │
│  • Group updates into batches of 50 variants                 │
│  • Send via PUT /inventory/variants                          │
│  • Process multiple batches if needed                        │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │  FlxPoint API   │
                   │                 │
                   │  Update Variant │
                   │  Inventory      │
                   └────────┬────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│              MARKETPLACE LISTINGS UPDATED                     │
│                                                               │
│  All connected sales channels now show:                      │
│  • Updated inventory quantities                              │
│  • Current pricing                                           │
│  • Latest MAP values                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Sync Fails to Complete

**Possible Causes:**
- FlxPoint API Key is invalid or expired
- Network connectivity issues
- FlxPoint API is down

**Actions:**
1. Verify API key in FlxPoint Setup
2. Check network connectivity
3. Test API access manually
4. Review error logs in Job Queue entries

### Items Not Syncing

**Scenario 1: Item has no Business Central data**
- Cause: No matching Item Reference with UPC
- Action: Create Item Reference with Reference Type = Bar Code

**Scenario 2: Item shows 0 quantity but you have stock**
- Cause: No price in price list
- Action: Add price to configured price list using UPC as reference
- Cause: FlxPoint Enabled = No
- Action: Enable FlxPoint on Item card
- Cause: Wrong zone or variant code
- Action: Check bin contents are in MAIN/SHIPPING zones
- For firearms: Verify variant code = 'NEW'

**Scenario 3: Quantity incorrect**
- Cause: Bin contents not updated
- Action: Refresh bin contents, post warehouse transactions
- Cause: Sales orders not creating picks
- Action: Create warehouse picks for sales orders

### Prices Not Updating

**Cause:** Price list not configured correctly
- Verify Price List Code in FlxPoint Setup
- Ensure price list uses Item References (UPCs), not item numbers
- Check that UPCs match exactly between BC and FlxPoint

**Cause:** Price list not active
- Verify price list status and date ranges
- Ensure price list is assigned to appropriate customers/channels

### BigCommerce Prices Missing

**Expected Behavior:**
- BigCommerce integration is optional
- Sync continues even if BigCommerce API fails
- Missing BigCommerce prices don't affect FlxPoint sync

**If needed:**
- Verify BigCommerce Setup configuration
- Check BigCommerce API credentials
- Ensure products exist in BigCommerce with matching UPCs

---

## Best Practices

### Data Maintenance

1. **Keep UPCs Accurate**
   - Verify UPC codes match between all systems
   - Use standard UPC-A format (12 digits)
   - Maintain Item References for all FlxPoint items

2. **Maintain Price Lists**
   - Regular price updates
   - Use Item References (UPCs) for pricing
   - Test prices before activating

3. **Monitor Inventory Accuracy**
   - Regular cycle counts
   - Keep bin contents current
   - Post warehouse transactions promptly
   - Create picks for sales orders

4. **Review Unmatched Items**
   - Regularly check FlxPoint Inventory for items without BC Item No.
   - Create Item References for legitimate products
   - Investigate and resolve discrepancies

### Sync Scheduling

**Recommended Schedule:**
- **During Business Hours**: Every 15-30 minutes
- **After Hours**: Every 1-2 hours
- **Heavy Traffic Periods**: More frequent (10-15 min)

**Avoid:**
- Syncing during month-end closing
- Running during inventory counts
- Overlapping sync jobs (ensure previous job completes)

### Monitoring

**Daily Checks:**
- Verify Last Sync Date is recent
- Review items with zero quantity
- Check for unmatched items
- Monitor job queue entry success/failure

**Weekly Reviews:**
- Analyze pricing accuracy
- Review cost margins
- Check for pricing conflicts
- Verify MAP compliance

**Monthly Audits:**
- Full inventory reconciliation
- Review all unmatched items
- Verify BigCommerce price accuracy
- Update documentation for new item types

---

## Integration Points

### Systems Integrated

1. **FlxPoint API**
   - Inventory variant data
   - Marketplace listings
   - Multi-channel distribution

2. **Business Central**
   - Item master data
   - Inventory availability
   - Price lists
   - Warehouse management

3. **BigCommerce** (Optional)
   - Web store pricing
   - Online product data
   - E-commerce integration

### Data Synchronization Scope

**Synchronized Fields:**
- Product quantities (available inventory)
- Pricing (list price, MSRP, MAP)
- Costs (for margin analysis)
- Product identifiers (SKU, UPC)
- Backorder settings

**Not Synchronized:**
- Product descriptions
- Images
- Categories
- Shipping rules (managed in FlxPoint)
- Customer-specific pricing

---

## Frequently Asked Questions

### How often should I run the sync?

Recommended frequency depends on your business:
- **High-volume sellers**: Every 10-15 minutes
- **Medium volume**: Every 30 minutes
- **Low volume**: Every 1-2 hours

### Will this sync historical data?

No. The sync only updates current inventory levels and pricing. Historical transactions remain unchanged.

### What happens if FlxPoint and BC both change at the same time?

Business Central is the source of truth for inventory and pricing. BC values always overwrite FlxPoint values during outbound sync.

### Can I prevent specific items from syncing?

Yes. Set "FlxPoint Enabled" = No on the Item card. This sends quantity 0 to FlxPoint, hiding the item from marketplace without deleting it.

### Why are some items showing zero quantity when I have stock?

Common reasons:
1. No price in the price list → Add price using UPC
2. FlxPoint Enabled = No → Enable on Item card
3. Inventory in wrong zone → Move to MAIN or SHIPPING
4. For firearms: Wrong variant code → Use 'NEW' variant

### Does this affect my other Business Central processes?

No. The sync is read-only from BC perspective (except for the FlxPoint Inventory table). It doesn't modify item cards, inventory, or sales orders.

### What if my internet connection fails during sync?

The sync will stop and incomplete batches won't be sent. Re-run the sync when connectivity is restored. FlxPoint Inventory table will rebuild from scratch.

### Can I customize which fields are synced?

Yes, but requires developer modification of the codeunit. Contact your Business Central partner for customizations.

---

## Support and Additional Resources

### Getting Help

1. **Check this documentation** for common scenarios
2. **Review Job Queue Entry logs** for error details
3. **Examine FlxPoint Inventory table** for data issues
4. **Contact your Business Central partner** for technical support
5. **Contact FlxPoint support** for API or marketplace issues

### Related Documentation

- FlxPoint_Create_Inventory_Documentation.md
- FlxPoint API Documentation (api.flxpoint.com)
- Business Central Warehouse Management documentation

---

## Appendix: Technical Details

### API Endpoints Used

**Inbound Sync:**
```
GET https://api.flxpoint.com/inventory/variants?page={page}&pageSize={pageSize}
```

**Outbound Sync:**
```
PUT https://api.flxpoint.com/inventory/variants
Content-Type: application/json
Body: [Array of variant update objects]
```

### Authentication

- Method: API Token in header
- Header: `X-Api-Token: {your-api-key}`
- Token configured in FlxPoint Setup

### Batch Limits

- Maximum variants per PUT request: 50
- Page size for GET requests: 100
- Automatic batching and pagination handled by system

### Error Handling

- API failures: Sync stops, can be retried
- Individual variant errors: Logged, sync continues
- Network errors: Sync exits, job queue can retry

---

## Document Version

- **Version**: 1.0
- **Date**: 2025-01-15
- **Applicable to**: FlxPoint Integration v1.0.0.42 and later

---

*For technical implementation details, see the inline code documentation in codeunit 50711 "FlxPoint Inventory Sync"*

