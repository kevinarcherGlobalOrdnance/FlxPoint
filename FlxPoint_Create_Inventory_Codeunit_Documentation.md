# FlxPoint Create Inventory Codeunit Documentation

**Codeunit ID:** 50713  
**Codeunit Name:** FlxPoint Create Inventory  
**Purpose:** Manages the creation and synchronization of inventory items from Business Central to FlxPoint e-commerce platform

---

## Table of Contents
1. [Overview](#overview)
2. [Public Procedures](#public-procedures)
3. [Local Procedures](#local-procedures)
4. [Data Flow](#data-flow)
5. [API Integration](#api-integration)
6. [Error Handling](#error-handling)
7. [Key Features](#key-features)

---

## Overview

This codeunit handles the complete lifecycle of creating inventory items in the FlxPoint e-commerce platform from Business Central data. It supports both batch processing of multiple items and individual item creation, with intelligent batching to optimize API calls.

### Key Capabilities
- **Batch Processing**: Processes multiple items in batches of 20 to optimize API performance
- **Item Filtering**: Only processes items marked as "FlxPoint Enabled"
- **Barcode Integration**: Uses Business Central Item References with barcode type
- **Price Integration**: Includes pricing from Price List Lines
- **UPC/SKU Mapping**: Maps item references to UPC and SKU in FlxPoint
- **Custom Fields**: Adds custom pricing field (GOPRICE) to FlxPoint items

### Prerequisites
- FlxPoint Setup record must exist with 'DEFAULT' key
- FlxPoint integration must be enabled in setup
- Items must have "FlxPoint Enabled" flag set to true
- Items must have Item References with "Bar Code" reference type

---

## Public Procedures

### ProcessFlxPointEnabledItems()
**Purpose:** Main entry point for batch processing all FlxPoint-enabled items

**Return Value:** `Boolean`
- `true`: All items processed successfully (or no items to process)
- `false`: Setup missing, integration disabled, or errors occurred

**Logic Flow:**
1. Validates FlxPoint Setup exists and is enabled
2. Filters items where "FlxPoint Enabled" = true
3. Counts total item references (excluding 'ROUNDS' UoM)
4. Processes items in batches of 20
5. Returns success status based on error count

**Key Variables:**
- `ProcessedCount`: Number of items successfully processed
- `ErrorCount`: Number of items that failed processing
- `BatchSize`: Fixed at 20 items per batch
- `TotalItems`: Total count of item references to process

**Example Usage:**
```al
if Codeunit50713."FlxPoint Create Inventory".ProcessFlxPointEnabledItems() then
    Message('All items processed successfully')
else
    Error('Some items failed to process');
```

---

### CreateInventoryItem(Item, ItemReference)
**Purpose:** Creates a single inventory item in FlxPoint

**Parameters:**
- `Item`: Record Item - The Business Central item record
- `ItemReference`: Record "Item Reference" - The barcode reference for the item

**Return Value:** `Boolean`
- `true`: Item created successfully in FlxPoint
- `false`: Setup missing, API request failed, or API returned error

**Logic Flow:**
1. Validates FlxPoint Setup exists
2. Builds JSON payload with item and variant data
3. Sends POST request to FlxPoint API
4. Parses response to extract created item ID
5. Returns success status

**API Endpoint:** `POST https://api.flxpoint.com/inventory/parents`

**JSON Structure Created:**
```json
[{
  "sku": "ITEM-REF-001",
  "title": "Item Description",
  "description": "Item Description 2",
  "upc": "ITEM-REF-001",
  "requiresFfl": false,
  "allowBackorders": false,
  "archived": false,
  "customFields": [{
    "name": "GOPRICE",
    "value": "19.99"
  }],
  "variants": [{
    "sku": "ITEM-REF-001",
    "title": "Item Description",
    "description": "Item Description 2",
    "upc": "ITEM-REF-001",
    "requiresFfl": false,
    "allowBackorders": false,
    "archived": false
  }]
}]
```

---

### CreateInventoryItemForItem(ItemNo)
**Purpose:** Creates inventory in FlxPoint for a specific item by item number

**Parameters:**
- `ItemNo`: Code[20] - The item number to process

**Return Value:** `Boolean`
- `true`: All references for the item processed successfully (or no references found)
- `false`: Item not found, not FlxPoint enabled, or errors occurred

**Logic Flow:**
1. Retrieves the item by item number
2. Validates item is FlxPoint enabled
3. Finds all barcode-type item references for the item
4. Processes each reference individually
5. Returns success status based on error count

**Example Usage:**
```al
if Codeunit50713."FlxPoint Create Inventory".CreateInventoryItemForItem('ITEM-001') then
    Message('Item created in FlxPoint')
else
    Error('Failed to create item in FlxPoint');
```

---

## Local Procedures

### ProcessAllItemsInBatches()
**Purpose:** Orchestrates batch processing of all FlxPoint-enabled items

**Parameters:**
- `Item`: Record Item (var) - Item record set filtered to FlxPoint enabled items
- `ItemReference`: Record "Item Reference" (var) - Item Reference record for iteration
- `BatchSize`: Integer - Number of items per batch (typically 20)
- `ProcessedCount`: Integer (var) - Accumulator for successfully processed items
- `ErrorCount`: Integer (var) - Accumulator for failed items
- `CurrentBatch`: Integer (var) - Current batch number being processed

**Return Value:** `Boolean` - Always returns true (errors tracked via ErrorCount parameter)

**Logic Flow:**
1. Iterates through all FlxPoint-enabled items
2. For each item, finds all barcode references (excluding 'ROUNDS' UoM)
3. Adds items to current batch until batch size reached
4. Sends batch to FlxPoint when full
5. Sends final batch if items remain
6. Updates ProcessedCount and ErrorCount

**Batch Management:**
- Items are added to `BatchJsonArray` until `ItemsInCurrentBatch >= BatchSize`
- When batch is full, it's sent via `SendBatchToFlxPoint()`
- Batch is cleared and counter reset for next batch
- Final batch is sent after all items are processed

---

### SendBatchToFlxPoint()
**Purpose:** Sends a batch of inventory items to FlxPoint API

**Parameters:**
- `BatchJsonArray`: JsonArray (var) - Array of inventory items to send
- `FlxPointSetup`: Record "FlxPoint Setup" - Setup record with API credentials
- `Client`: HttpClient (var) - HTTP client for API communication
- `RequestMessage`: HttpRequestMessage (var) - HTTP request object
- `ResponseMessage`: HttpResponseMessage (var) - HTTP response object
- `RequestHeaders`: HttpHeaders (var) - Request headers
- `ContentHeaders`: HttpHeaders (var) - Content headers
- `ResponseText`: Text (var) - Response text buffer
- `HttpContent`: HttpContent (var) - HTTP content object
- `JsonText`: Text (var) - JSON text buffer
- `BatchNumber`: Integer - Current batch number for tracking
- `ItemsInBatch`: Integer - Number of items in this batch

**Return Value:** `Boolean`
- `true`: Batch sent successfully
- `false`: HTTP request failed or API returned error

**Logic Flow:**
1. Converts JSON array to text
2. Configures HTTP POST request to FlxPoint API
3. Adds authentication header (X-Api-Token)
4. Sets content type to application/json
5. Sends request and validates response
6. Parses successful response to extract created item IDs

**API Request:**
- **Method:** POST
- **URL:** https://api.flxpoint.com/inventory/parents
- **Headers:**
  - Accept: application/json
  - X-Api-Token: [API Key from FlxPoint Setup]
  - Content-Type: application/json
- **Body:** JSON array of inventory items

**Response Handling:**
- Success (2xx): Parses response array and processes created item IDs
- Failure (4xx/5xx): Returns false, error details in ResponseText

---

### ProcessBatchResponse()
**Purpose:** Processes the response from a batch API call

**Parameters:**
- `JsonArray`: JsonArray - Response array from FlxPoint API
- `BatchNumber`: Integer - Batch number for reference

**Return Value:** None (void)

**Logic Flow:**
1. Iterates through each item in the response array
2. Extracts the 'id' field from each created item
3. Stores the created item ID (currently not persisted)

**Note:** Currently, the extracted IDs are not persisted to Business Central. This could be enhanced to store FlxPoint IDs in a custom table for future reference.

---

### ProcessItemReference()
**Purpose:** Wrapper procedure to create an inventory item from item reference

**Parameters:**
- `Item`: Record Item - The item record
- `ItemReference`: Record "Item Reference" - The item reference to process

**Return Value:** `Boolean` - Result from CreateInventoryItem()

**Purpose:** Acts as a simple wrapper to call CreateInventoryItem() for consistency in code structure.

---

### CheckItemExistsInFlxPoint()
**Purpose:** Checks if an item already exists in FlxPoint by SKU

**Parameters:**
- `ReferenceNo`: Text - The SKU/reference number to check

**Return Value:** `Boolean`
- `true`: Item exists in FlxPoint
- `false`: Item does not exist, setup missing, or API error

**Logic Flow:**
1. Validates FlxPoint Setup exists
2. Sends GET request to FlxPoint variants API
3. Parses response to check if data array contains items
4. Returns true if any variants found for the SKU

**API Request:**
- **Method:** GET
- **URL:** https://api.flxpoint.com/inventory/variants?skus=[ReferenceNo]
- **Headers:**
  - Accept: application/json
  - X-Api-Token: [API Key from FlxPoint Setup]

**Note:** This procedure is currently defined but not actively used in the main flow. It could be used to prevent duplicate creations or to check item status before processing.

---

### BuildInventoryItemJson()
**Purpose:** Constructs the JSON payload for a single inventory item

**Parameters:**
- `JsonArray`: JsonArray (var) - Array to add the inventory item JSON to
- `Item`: Record Item - Business Central item record
- `ItemReference`: Record "Item Reference" - Item reference with barcode

**Return Value:** None (void) - Modifies JsonArray parameter

**JSON Structure Built:**

**Main Inventory Item Object:**
- `sku`: Item Reference No. (from Item Reference)
- `title`: Item Description
- `description`: Item Description 2
- `upc`: Item Reference No. (same as SKU)
- `requiresFfl`: false (hardcoded)
- `allowBackorders`: false (hardcoded)
- `archived`: false (hardcoded)

**Custom Fields Array:**
- `name`: "GOPRICE"
- `value`: Unit Price from Price List Line (or "1.99" default)

**Variants Array:**
- Contains single variant with same structure as parent
- Same SKU, title, description, and UPC as parent
- Same hardcoded boolean flags

**Price Logic:**
1. Retrieves FlxPoint Setup to get Price List Code
2. Searches for Price List Line matching:
   - Price List Code from setup
   - Item Reference matching current reference
3. If found: Uses Unit Price from Price List Line
4. If not found: Uses default value "1.99"

**Field Mapping:**

| Business Central Field | FlxPoint Field | Source |
|------------------------|----------------|--------|
| Item Reference."Reference No." | sku | ItemReference |
| Item.Description | title | Item |
| Item."Description 2" | description | Item |
| Item Reference."Reference No." | upc | ItemReference |
| Price List Line."Unit Price" | customFields.GOPRICE | Price List |

---

### ProcessCreateResponse()
**Purpose:** Processes the response from a single item creation API call

**Parameters:**
- `JsonArray`: JsonArray - Response array from FlxPoint API
- `Item`: Record Item - Original item record
- `ItemReference`: Record "Item Reference" - Original item reference

**Return Value:** None (void)

**Logic Flow:**
1. Extracts first item from response array
2. Retrieves the 'id' field from the response object
3. Stores the created item ID (currently not persisted)

**Note:** Currently, the extracted ID is not persisted to Business Central. This could be enhanced to store FlxPoint IDs in a custom table for future reference and tracking.

---

## Data Flow

### Batch Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ProcessFlxPointEnabledItems()                            │
│    - Validates setup and enabled status                     │
│    - Filters FlxPoint-enabled items                         │
│    - Counts total item references                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. ProcessAllItemsInBatches()                               │
│    - Iterates through items                                 │
│    - Finds barcode references (excludes 'ROUNDS')           │
│    - Builds batches of 20 items                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. BuildInventoryItemJson()                                 │
│    - Creates JSON object for each item                      │
│    - Adds custom fields (GOPRICE)                           │
│    - Builds variants array                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. SendBatchToFlxPoint()                                    │
│    - Converts JSON array to text                            │
│    - Sends POST to FlxPoint API                             │
│    - Handles authentication                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. ProcessBatchResponse()                                   │
│    - Parses API response                                    │
│    - Extracts created item IDs                              │
└─────────────────────────────────────────────────────────────┘
```

### Single Item Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│ CreateInventoryItemForItem(ItemNo)                          │
│ - Retrieves item by number                                  │
│ - Validates FlxPoint enabled                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Find Item References (Bar Code type)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ For each Item Reference:                                    │
│   CreateInventoryItem()                                     │
│   - Builds JSON payload                                     │
│   - Sends to FlxPoint API                                   │
│   - Processes response                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## API Integration

### FlxPoint API Endpoints Used

#### 1. Create Inventory Parents
**Endpoint:** `POST https://api.flxpoint.com/inventory/parents`

**Purpose:** Creates parent inventory items with variants

**Authentication:** X-Api-Token header with API key from FlxPoint Setup

**Request Body:** JSON array of inventory items
```json
[
  {
    "sku": "string",
    "title": "string",
    "description": "string",
    "upc": "string",
    "requiresFfl": boolean,
    "allowBackorders": boolean,
    "archived": boolean,
    "customFields": [
      {
        "name": "string",
        "value": "string"
      }
    ],
    "variants": [
      {
        "sku": "string",
        "title": "string",
        "description": "string",
        "upc": "string",
        "requiresFfl": boolean,
        "allowBackorders": boolean,
        "archived": boolean
      }
    ]
  }
]
```

**Response:** JSON array of created items with IDs
```json
[
  {
    "id": "12345",
    "sku": "ITEM-001",
    ...
  }
]
```

#### 2. Get Inventory Variants
**Endpoint:** `GET https://api.flxpoint.com/inventory/variants?skus={sku}`

**Purpose:** Checks if item exists in FlxPoint

**Authentication:** X-Api-Token header with API key from FlxPoint Setup

**Query Parameters:**
- `skus`: Comma-separated list of SKUs to check

**Response:**
```json
{
  "data": [
    {
      "id": "12345",
      "sku": "ITEM-001",
      ...
    }
  ]
}
```

### HTTP Client Configuration

**Request Headers:**
- `Accept`: application/json
- `X-Api-Token`: [API Key from FlxPoint Setup]
- `Content-Type`: application/json (for POST requests)

**Response Handling:**
- Success: HTTP 2xx status codes
- Failure: HTTP 4xx/5xx status codes, error details in response body

---

## Error Handling

### Setup Validation
- **Missing Setup:** Returns false if FlxPoint Setup record not found
- **Integration Disabled:** Returns false if FlxPoint integration not enabled
- **No Enabled Items:** Returns true (success) if no items to process

### API Error Handling
- **HTTP Request Failure:** Returns false if request cannot be sent
- **API Error Response:** Returns false if API returns error status code
- **Response Parsing Failure:** Silently continues if response cannot be parsed

### Item Processing
- **Missing Item:** Returns false if item not found
- **Not FlxPoint Enabled:** Returns false if item not marked for FlxPoint
- **No Item References:** Returns true if no barcode references found

### Batch Processing
- **Batch Failure:** Increments ErrorCount, continues with next batch
- **Partial Success:** Tracks both ProcessedCount and ErrorCount
- **Final Status:** Returns true only if ErrorCount = 0

### Error Recovery
- Individual item failures don't stop batch processing
- Each batch is independent; one failure doesn't affect others
- Process continues even if some items fail

---

## Key Features

### 1. Batch Processing
- **Batch Size:** 20 items per batch (configurable via parameter)
- **Optimization:** Reduces API calls by sending multiple items in single request
- **Efficiency:** Processes hundreds of items with minimal API calls

### 2. Item Filtering
- **FlxPoint Enabled Flag:** Only processes items marked for FlxPoint
- **Reference Type Filter:** Only processes barcode-type item references
- **UoM Exclusion:** Excludes 'ROUNDS' unit of measure from processing

### 3. Price Integration
- **Price List Lookup:** Retrieves prices from configured Price List
- **Item Reference Matching:** Matches by Item Reference number
- **Default Price:** Uses "1.99" if no price found in Price List
- **Custom Field:** Stores price in GOPRICE custom field in FlxPoint

### 4. SKU/UPC Mapping
- **Single Source:** Uses Item Reference No. for both SKU and UPC
- **Consistency:** Ensures SKU and UPC match in FlxPoint
- **Flexibility:** Supports multiple references per item

### 5. Variant Structure
- **Single Variant:** Creates one variant per item reference
- **Parent-Child Relationship:** Parent and variant share same SKU
- **Consistent Data:** Variant inherits all parent properties

### 6. Custom Fields
- **GOPRICE Field:** Custom pricing field for Global Ordnance
- **Extensible:** Structure supports additional custom fields
- **Dynamic Values:** Price retrieved from Price List at runtime

### 7. Idempotency
- **No Duplicate Check:** Creates items regardless of existing status
- **Always Creates:** API handles duplicate detection on FlxPoint side
- **Consistent Behavior:** Same result whether item exists or not

---

## Business Logic Details

### Item Selection Criteria
1. Item must have "FlxPoint Enabled" = true
2. Item must have at least one Item Reference
3. Item Reference must have "Reference Type" = "Bar Code"
4. Item Reference must have "Unit of Measure" ≠ 'ROUNDS'

### Price Determination Logic
```al
IF Price List Line exists for:
    - Price List Code = FlxPoint Setup."Price List Code"
    - Item Reference = Current Item Reference
THEN
    Use Price List Line."Unit Price"
ELSE
    Use default value "1.99"
```

### Batch Size Optimization
- **Current Size:** 20 items per batch
- **Rationale:** Balances API performance with payload size
- **Considerations:**
  - Larger batches = fewer API calls but larger payloads
  - Smaller batches = more API calls but smaller payloads
  - 20 items provides good balance for most scenarios

### Response Processing
- **Current Behavior:** Extracts IDs but doesn't persist them
- **Potential Enhancement:** Store FlxPoint IDs in custom table for:
  - Tracking created items
  - Updating existing items
  - Synchronization status

---

## Integration Points

### Dependencies
- **FlxPoint Setup Table (Tab50700):** Provides API credentials and configuration
- **Item Table:** Source of item master data
- **Item Reference Table:** Provides SKU/UPC mapping
- **Price List Line Table:** Provides pricing information

### Callers
- **FlxPoint Role Center:** May call ProcessFlxPointEnabledItems()
- **Item Card Extension:** May call CreateInventoryItemForItem()
- **Job Queue:** May schedule ProcessFlxPointEnabledItems()

### Data Flow
```
Business Central              FlxPoint API
─────────────────            ──────────────
Item Master          ────>   Inventory Parents
Item References      ────>   SKU/UPC
Price List Lines     ────>   Custom Fields (GOPRICE)
FlxPoint Setup       ────>   API Authentication
```

---

## Usage Examples

### Example 1: Process All Enabled Items
```al
codeunit 50713 "FlxPoint Create Inventory"
var
    FlxPointCreateInventory: Codeunit "FlxPoint Create Inventory";
begin
    if FlxPointCreateInventory.ProcessFlxPointEnabledItems() then
        Message('All items processed successfully')
    else
        Error('Some items failed to process');
end;
```

### Example 2: Create Single Item
```al
codeunit 50713 "FlxPoint Create Inventory"
var
    FlxPointCreateInventory: Codeunit "FlxPoint Create Inventory";
begin
    if FlxPointCreateInventory.CreateInventoryItemForItem('ITEM-001') then
        Message('Item created in FlxPoint')
    else
        Error('Failed to create item');
end;
```

### Example 3: Check Item Exists
```al
codeunit 50713 "FlxPoint Create Inventory"
var
    FlxPointCreateInventory: Codeunit "FlxPoint Create Inventory";
begin
    if FlxPointCreateInventory.CheckItemExistsInFlxPoint('ITEM-001') then
        Message('Item already exists in FlxPoint')
    else
        Message('Item does not exist in FlxPoint');
end;
```

---

## Future Enhancements

### Potential Improvements

1. **ID Persistence**
   - Store FlxPoint IDs in custom table
   - Enable update operations for existing items
   - Track synchronization status

2. **Enhanced Error Handling**
   - Log detailed error messages
   - Retry failed items automatically
   - Provide error summary report

3. **Configuration Options**
   - Make batch size configurable
   - Add option to skip existing items
   - Support different custom fields

4. **Performance Optimization**
   - Parallel batch processing
   - Async processing via job queue
   - Progress tracking for large batches

5. **Data Validation**
   - Validate required fields before API call
   - Check data quality
   - Provide validation warnings

6. **Synchronization Tracking**
   - Track last sync timestamp
   - Identify items needing update
   - Support incremental sync

---

## Troubleshooting

### Common Issues

#### Issue: No items processed
**Possible Causes:**
- FlxPoint Setup not configured
- FlxPoint integration disabled
- No items marked as FlxPoint Enabled
- No barcode-type item references

**Solution:**
- Verify FlxPoint Setup record exists
- Check "Enabled" flag in FlxPoint Setup
- Mark items as FlxPoint Enabled
- Create item references with Bar Code type

#### Issue: API authentication fails
**Possible Causes:**
- Invalid API key in FlxPoint Setup
- API key expired
- Network connectivity issues

**Solution:**
- Verify API key in FlxPoint Setup
- Test API key in FlxPoint portal
- Check network connectivity
- Verify firewall rules

#### Issue: Items created but prices wrong
**Possible Causes:**
- Price List not configured in FlxPoint Setup
- No Price List Line for item reference
- Price List Line has wrong item reference

**Solution:**
- Configure Price List Code in FlxPoint Setup
- Create Price List Lines for item references
- Verify Item Reference matches in Price List Line

#### Issue: Batch processing fails
**Possible Causes:**
- API rate limiting
- Large payload size
- Network timeout

**Solution:**
- Reduce batch size
- Add retry logic
- Check API rate limits
- Monitor network performance

---

## Technical Specifications

### Performance Characteristics
- **Batch Processing:** ~20 items per API call
- **API Call Overhead:** Minimal with batching
- **Memory Usage:** Low - processes in batches
- **Processing Time:** Depends on item count and API response time

### Scalability
- **Small Batches (<100 items):** Processes quickly
- **Medium Batches (100-1000 items):** Processes in reasonable time
- **Large Batches (>1000 items):** Consider async processing via job queue

### API Rate Limits
- **Current Implementation:** No rate limit handling
- **Recommendation:** Monitor FlxPoint API rate limits
- **Enhancement:** Add rate limit detection and throttling

---

## Maintenance Notes

### Code Maintenance
- **Telemetry Removed:** All telemetry logging has been removed
- **Error Handling:** Basic error handling in place
- **Code Structure:** Well-organized with clear separation of concerns

### Testing Recommendations
1. Test with small batch (1-5 items)
2. Test with medium batch (20-50 items)
3. Test with large batch (100+ items)
4. Test error scenarios (invalid API key, network failure)
5. Test price retrieval from Price List
6. Test with items having no Price List entry

### Monitoring
- Monitor API response times
- Track success/failure rates
- Monitor batch processing performance
- Check for API errors in response

---

## Version History

**Version 1.0.0**
- Initial implementation
- Batch processing support
- Price integration
- Custom fields support
- Telemetry removed

---

## Contact and Support

For questions or issues related to this codeunit, contact the development team or refer to:
- FlxPoint API Documentation
- Business Central AL Development Guide
- FlxPoint Integration User Guide

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Author:** Development Team  
**Status:** Active

