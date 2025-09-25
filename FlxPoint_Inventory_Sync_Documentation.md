# FlxPoint Inventory Sync - Technical Documentation

## Overview

The FlxPoint Inventory Sync codeunit (`Cod50711`) is responsible for synchronizing inventory data between Business Central and the FlxPoint inventory management system. It performs a two-way sync: pulling inventory data from FlxPoint and pushing Business Central inventory levels and pricing back to FlxPoint.

## Key Features

- **Bidirectional Sync**: Pulls data from FlxPoint and pushes Business Central data back
- **Pagination Support**: Handles large datasets with paginated API requests
- **Batch Processing**: Updates FlxPoint in batches of 50 variants
- **BigCommerce Integration**: Retrieves pricing from BigCommerce API
- **Complex Inventory Calculations**: Handles different item types (firearms, ammunition, assemblies)
- **Comprehensive Logging**: Detailed telemetry and error tracking

## Architecture

### Main Procedures

#### `OnRun()`
**Purpose**: Main entry point triggered when codeunit runs

**Process Flow**:
1. Logs sync process start
2. Calls `SyncInventory()` to pull data from FlxPoint
3. Calls `UpdateFlxPointInventory()` to push data to FlxPoint
4. Logs sync process completion

#### `SyncInventory()`
**Purpose**: Pulls inventory data from FlxPoint API

**Process Flow**:
1. Validates FlxPoint setup configuration
2. Implements pagination (100 variants per page)
3. Retrieves inventory variants from `/inventory/variants` endpoint
4. Processes each variant through `ProcessInventoryVariant()`
5. Continues until all pages are processed

**API Endpoint**: `GET https://api.flxpoint.com/inventory/variants?page={page}&pageSize={pageSize}`

#### `ProcessInventoryVariant()`
**Purpose**: Processes individual inventory variants from FlxPoint

**Key Operations**:
1. **Data Extraction**: Extracts all variant fields from JSON response
2. **Record Management**: Creates new or updates existing FlxPoint Inventory records
3. **BigCommerce Integration**: Retrieves pricing from BigCommerce API
4. **Business Central Mapping**: Maps UPC to Business Central items
5. **Inventory Calculations**: Calculates Business Central quantities and pricing

#### `UpdateFlxPointInventory()`
**Purpose**: Pushes Business Central inventory data back to FlxPoint

**Process Flow**:
1. Identifies variants with changes (QOH or price differences)
2. Builds JSON payload for batch updates
3. Processes in batches of 50 variants
4. Sends updates to FlxPoint API

**API Endpoint**: `PUT https://api.flxpoint.com/inventory/variants`

## Data Mapping

### FlxPoint to Business Central Fields

| FlxPoint Field | Business Central Field | Description |
|----------------|------------------------|-------------|
| `id` | `Inventory Variant ID` | Unique variant identifier |
| `sku` | `SKU` | Stock keeping unit |
| `title` | `Title` | Item title |
| `upc` | `UPC` | Universal product code |
| `quantity` | `Quantity` | Available quantity |
| `cost` | `Cost` | Item cost |
| `inventoryListPrice` | `Inventory List Price` | List price |
| `msrp` | `MSRP` | Manufacturer's suggested retail price |
| `weight` | `Weight` | Item weight |
| `length` | `Length` | Item length |
| `width` | `Width` | Item width |
| `height` | `Height` | Item height |
| `requiresFfl` | `Requires FFL` | FFL requirement flag |
| `allowBackorders` | `Allow Backorders` | Backorder allowance |
| `archived` | `Archived` | Archive status |

### Business Central to FlxPoint Fields

| Business Central Field | FlxPoint Field | Description |
|------------------------|----------------|-------------|
| `Business Central QOH` | `quantity` | Quantity on hand |
| `Business Central Cost` | `cost` | Item cost |
| `Business Central Price` | `inventoryListPrice` | Inventory list price |
| `Business Central Price` | `msrp` | MSRP price |
| `Business Central Map` | `map` | Minimum advertised price |
| `Allow Backorders` | `allowBackorders` | Backorder setting |

## Inventory Calculations

### Standard Items (`CalcInventory()`)
**Purpose**: Calculates quantity on hand for standard items

**Logic**:
1. Gets quantity on sales order
2. Calculates available quantity from bin contents (MAIN and SHIPPING zones)
3. Subtracts pick quantities
4. Handles firearms with NEW variant filter
5. Calculates net available quantity

### Ammunition Items (`CalcAmmunitionAvail()`)
**Purpose**: Special calculation for ammunition and magazines

**Logic**:
1. Calculates total available from bin contents
2. Handles unit of measure conversions
3. Subtracts sales order quantities
4. Returns converted quantity in requested UOM

### Assembly Items (`CalcAssemblyAvail()`)
**Purpose**: Calculates available quantity for assembly items

**Logic**:
1. Uses BOM tree calculation
2. Determines able-to-make quantity
3. Adds current inventory
4. Subtracts sales order quantities

## BigCommerce Integration

### Price Retrieval
- **Trigger**: When UPC is available on FlxPoint variant
- **Method**: `TryGetBigCommercePrice(UPC, Price)`
- **API**: Uses BigCommerce API codeunit
- **Fallback**: Continues sync even if BigCommerce API fails
- **Logging**: Detailed success/failure logging

### Error Handling
- BigCommerce API failures don't stop the sync process
- Errors are logged to both telemetry and job queue
- Continues processing other variants

## API Integration

### FlxPoint API Endpoints

#### GET Inventory Variants
- **URL**: `https://api.flxpoint.com/inventory/variants`
- **Method**: GET
- **Parameters**: `page`, `pageSize`
- **Authentication**: X-Api-Token header
- **Response**: Array of inventory variant objects

#### PUT Inventory Variants
- **URL**: `https://api.flxpoint.com/inventory/variants`
- **Method**: PUT
- **Authentication**: X-Api-Token header
- **Content-Type**: application/json
- **Payload**: Array of variant update objects

### Request/Response Format

#### GET Response Structure
```json
[
  {
    "id": "variant_id",
    "sku": "SKU_CODE",
    "title": "Item Title",
    "upc": "UPC_CODE",
    "quantity": 100,
    "cost": 25.50,
    "inventoryListPrice": 45.99,
    "msrp": 49.99,
    "weight": 2.5,
    "length": 10.0,
    "width": 5.0,
    "height": 3.0,
    "requiresFfl": false,
    "allowBackorders": true,
    "archived": false,
    "lastModifiedDate": "2024-01-01T00:00:00Z"
  }
]
```

#### PUT Request Structure
```json
[
  {
    "inventoryVariantId": "variant_id",
    "sku": "SKU_CODE",
    "quantity": 95,
    "cost": 26.00,
    "allowBackorders": true,
    "inventoryListPrice": 46.99,
    "msrp": 46.99,
    "map": 44.99,
    "customFields": [
      {
        "name": "GOPRICE",
        "value": "46.99"
      }
    ]
  }
]
```

## Configuration Requirements

### FlxPoint Setup
- **Enabled**: Must be true
- **API Key**: Valid FlxPoint API token
- **Price List Code**: For Business Central pricing

### Business Central Setup
- **Item References**: Barcode-type references for UPC mapping
- **Bin Contents**: Proper bin setup for inventory calculations
- **Price Lists**: Configured price lists for pricing
- **Item Categories**: Proper categorization for calculation logic

## Error Handling & Logging

### Telemetry Events
- `FlxPoint-InvSync-0001`: Process started
- `FlxPoint-InvSync-0002`: Process completed
- `FlxPoint-InvSync-0003`: Sync started
- `FlxPoint-InvSync-0004`: Setup not found
- `FlxPoint-InvSync-0005`: Parameters set
- `FlxPoint-InvSync-0006`: Processing page
- `FlxPoint-InvSync-0007`: API request failed
- `FlxPoint-InvSync-0008`: API error response
- `FlxPoint-InvSync-0009`: JSON parse error
- `FlxPoint-InvSync-0010`: Page empty
- `FlxPoint-InvSync-0011`: Variants retrieved
- `FlxPoint-InvSync-0012`: Last page reached
- `FlxPoint-InvSync-0013`: Sync completed
- `FlxPoint-InvSync-0014`: Missing variant ID
- `FlxPoint-InvSync-0015`: New variant created
- `FlxPoint-InvSync-0016`: Variant updated
- `FlxPoint-InvSync-0017`: Item reference found
- `FlxPoint-InvSync-0018`: Item reference not found
- `FlxPoint-InvSync-0019`: Business Central data calculated
- `FlxPoint-InvSync-BigCommerce`: BigCommerce API events

### Error Scenarios
1. **Setup Missing**: FlxPoint Setup record not found
2. **API Failures**: HTTP request failures or API errors
3. **JSON Parsing**: Invalid response format
4. **BigCommerce Errors**: BigCommerce API failures (non-blocking)
5. **Calculation Errors**: Inventory calculation failures

### Job Queue Logging
- Creates detailed job queue log entries
- Logs BigCommerce API errors
- Provides audit trail for troubleshooting

## Performance Characteristics

### Pagination
- **Page Size**: 100 variants per page
- **Memory Efficient**: Processes data in chunks
- **Scalable**: Handles large inventory datasets

### Batch Processing
- **Batch Size**: 50 variants per update request
- **Efficient Updates**: Only processes changed variants
- **API Friendly**: Respects FlxPoint API limits

### Change Detection
- **QOH Changes**: Only updates when quantity changes
- **Price Changes**: Only updates when pricing changes
- **Efficient Processing**: Skips unchanged variants

## Usage Examples

### Manual Execution
```al
// Run inventory sync manually
FlxPointInventorySync: Codeunit "FlxPoint Inventory Sync";
FlxPointInventorySync.Run();
```

### Job Queue Integration
```al
// Schedule in job queue
JobQueueEntry.Init();
JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
JobQueueEntry."Object ID to Run" := Codeunit::"FlxPoint Inventory Sync";
JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime;
JobQueueEntry.Status := JobQueueEntry.Status::Ready;
JobQueueEntry.Insert(true);
```

## Troubleshooting

### Common Issues

1. **"Setup not found"**
   - Ensure FlxPoint Setup record exists with key 'DEFAULT'
   - Verify all required fields are populated

2. **"API Request Failed"**
   - Check network connectivity to FlxPoint API
   - Verify API key is valid and active
   - Review API endpoint URLs

3. **"JSON Parse Error"**
   - Check FlxPoint API response format
   - Verify API version compatibility
   - Review response content in logs

4. **"Item Reference Not Found"**
   - Ensure UPC codes match between systems
   - Verify barcode-type item references exist
   - Check UPC format consistency

5. **BigCommerce API Errors**
   - Review BigCommerce API configuration
   - Check UPC format for BigCommerce compatibility
   - Verify BigCommerce API credentials

### Debugging Tips

1. **Enable Detailed Logging**: Review telemetry events for processing details
2. **Check Job Queue Logs**: Review job queue entries for error details
3. **Validate Data Mapping**: Ensure field mappings are correct
4. **Test API Connectivity**: Use FlxPoint Setup test connection
5. **Review Calculation Logic**: Verify inventory calculation formulas

## Dependencies

### Required Tables
- `FlxPoint Inventory`: Local inventory cache
- `Item`: Business Central item master
- `Item Reference`: UPC mapping
- `Bin Content`: Inventory calculations
- `Price List Line`: Pricing information
- `FlxPoint Setup`: Configuration

### Required Codeunits
- `BigCommerce API`: Price retrieval
- `Calculate BOM Tree`: Assembly calculations
- `Unit of Measure Management`: UOM conversions

### External Dependencies
- FlxPoint API access
- BigCommerce API access
- Valid API credentials
- Network connectivity

## Future Enhancements

### Potential Improvements
1. **Incremental Sync**: Only sync changed records
2. **Real-time Updates**: Webhook-based updates
3. **Conflict Resolution**: Handle data conflicts
4. **Performance Monitoring**: Detailed performance metrics
5. **Error Recovery**: Automatic retry mechanisms

### Configuration Options
1. **Configurable Batch Sizes**: Adjustable batch sizes
2. **Sync Filters**: Filter by item categories or locations
3. **Schedule Options**: Flexible scheduling options
4. **Notification System**: Email alerts for sync status

---

*This documentation covers the current implementation of the FlxPoint Inventory Sync functionality. For updates or questions, refer to the source code in `Cod50711.FlxPointInventorySync.al`.*
