# FlxPoint Create Inventory - Technical Documentation

## Overview

The FlxPoint Create Inventory codeunit (`Cod50713`) is responsible for synchronizing Business Central items with the FlxPoint inventory management system. It processes FlxPoint-enabled items in batches and creates/updates them in the FlxPoint API using the `/inventory/parents` endpoint.

## Key Features

- **Batch Processing**: Processes items in batches of 20 for optimal API performance
- **Custom Field Integration**: Automatically adds custom fields including GOPRICE from price lists
- **Error Handling**: Comprehensive logging and error tracking
- **Idempotent Operations**: Can safely run multiple times without creating duplicates
- **Price List Integration**: Retrieves pricing from configured price lists

## Architecture

### Main Procedures

#### `ProcessFlxPointEnabledItems(): Boolean`
**Purpose**: Main entry point for processing all FlxPoint-enabled items

**Process Flow**:
1. Validates FlxPoint setup configuration
2. Counts total items to be processed
3. Processes items in batches of 20
4. Returns success/failure status

**Parameters**: None
**Returns**: Boolean (true if successful, false if errors occurred)

#### `ProcessAllItemsInBatches()`
**Purpose**: Handles the batch processing logic

**Process Flow**:
1. Iterates through all FlxPoint-enabled items
2. Collects items and their barcode references
3. Builds JSON arrays for batch requests
4. Sends batches to FlxPoint API when batch size reaches 20
5. Handles final partial batch if needed

#### `SendBatchToFlxPoint()`
**Purpose**: Sends individual batches to the FlxPoint API

**Process Flow**:
1. Converts JSON array to text
2. Sets up HTTP request with proper headers
3. Sends POST request to `/inventory/parents`
4. Processes response and logs results

#### `BuildInventoryItemJson()`
**Purpose**: Builds the JSON structure for individual inventory items

**JSON Structure Created**:
```json
{
  "sku": "ITEM_REFERENCE_NO",
  "title": "Item Description",
  "description": "Item Description 2",
  "upc": "ITEM_REFERENCE_NO",
  "requiresFfl": false,
  "allowBackorders": false,
  "archived": false,
  "customFields": [
    {
      "name": "GOPRICE",
      "value": "1.99" // or price from price list
    }
  ],
  "variants": [
    {
      "sku": "ITEM_REFERENCE_NO",
      "title": "Item Description",
      "description": "Item Description 2",
      "upc": "ITEM_REFERENCE_NO",
      "requiresFfl": false,
      "allowBackorders": false,
      "archived": false,
      "customFields": [...]
    }
  ]
}
```

## Configuration Requirements

### FlxPoint Setup
The system requires a `FlxPoint Setup` record with:
- **Enabled**: Must be true
- **API Key**: Valid FlxPoint API token
- **API Base URL**: FlxPoint API endpoint
- **Price List Code**: For GOPRICE custom field pricing

### Item Configuration
Items must have:
- **FlxPoint Enabled**: Set to true
- **Item References**: Barcode type references for SKU mapping

## API Integration

### Endpoint
- **URL**: `https://api.flxpoint.com/inventory/parents`
- **Method**: POST
- **Authentication**: X-Api-Token header
- **Content-Type**: application/json

### Request Format
```json
[
  {
    "sku": "PARENT_SKU",
    "title": "Item Title",
    "description": "Item Description",
    "upc": "UPC_CODE",
    "requiresFfl": false,
    "allowBackorders": false,
    "archived": false,
    "customFields": [...],
    "variants": [...]
  }
]
```

### Response Handling
- Processes array of created/updated inventory items
- Extracts item IDs from response
- Logs detailed success/failure information

## Custom Fields

### GOPRICE Field
- **Purpose**: Stores item pricing information
- **Source**: FlxPoint Setup Price List or default value (1.99)
- **Logic**: 
  1. Looks up item in configured price list
  2. Uses price list unit price if found
  3. Falls back to default value (1.99) if not found

### Price List Integration
```al
FlxPointSetup.Get('DEFAULT');
pricelistline.SetRange("Price List Code", FlxPointSetup."Price List Code");
pricelistline.SetRange("Item Reference", ItemReference."Reference No.");
if pricelistline.FindFirst() then
    CustomFieldObject.Add('value', Format(pricelistline."Unit Price"))
else
    CustomFieldObject.Add('value', '1.99');
```

## Error Handling & Logging

### Telemetry Events
- `FlxPoint-CreateInv-0001`: Processing started
- `FlxPoint-CreateInv-0002`: Setup not found
- `FlxPoint-CreateInv-0003`: Integration disabled
- `FlxPoint-CreateInv-0004`: No items found
- `FlxPoint-CreateInv-0005`: Processing completed
- `FlxPoint-CreateInv-0016`: Batch processing
- `FlxPoint-CreateInv-0017`: Batch request failed
- `FlxPoint-CreateInv-0018`: Batch API error
- `FlxPoint-CreateInv-0019`: Batch completed successfully
- `FlxPoint-CreateInv-0020`: Individual item created

### Error Scenarios
1. **Setup Missing**: FlxPoint Setup record not found
2. **Integration Disabled**: FlxPoint integration turned off
3. **No Items**: No FlxPoint-enabled items found
4. **API Errors**: HTTP request failures or API error responses
5. **JSON Parsing**: Invalid response format

## Performance Characteristics

### Batch Processing Benefits
- **20x Fewer API Calls**: Processes 20 items per request vs 1 item per request
- **Improved Throughput**: Significantly faster for large item sets
- **Rate Limit Friendly**: Reduces API rate limit concerns
- **Network Efficient**: Better bandwidth utilization

### Processing Flow
1. **Collection Phase**: Gathers all FlxPoint-enabled items
2. **Batch Building**: Groups items into batches of 20
3. **API Transmission**: Sends batches to FlxPoint
4. **Response Processing**: Handles success/failure responses
5. **Logging**: Records detailed processing information

## Usage Examples

### Basic Usage
```al
// Process all FlxPoint-enabled items
FlxPointCreateInventory: Codeunit "FlxPoint Create Inventory";
if FlxPointCreateInventory.ProcessFlxPointEnabledItems() then
    Message('Inventory sync completed successfully')
else
    Message('Inventory sync completed with errors');
```

### From FlxPoint Setup Page
The system provides a UI action on the FlxPoint Setup page:
- **Action**: "Create Inventory Items"
- **Validation**: Checks if integration is enabled and API key is configured
- **Confirmation**: Prompts user before processing
- **Feedback**: Shows success/error messages

## Troubleshooting

### Common Issues

1. **"FlxPoint Setup not found"**
   - Ensure FlxPoint Setup record exists with key 'DEFAULT'
   - Verify all required fields are populated

2. **"Integration is disabled"**
   - Check FlxPoint Setup.Enabled field
   - Ensure integration is properly configured

3. **"No FlxPoint enabled items found"**
   - Verify items have "FlxPoint Enabled" set to true
   - Check for barcode-type item references

4. **API Authentication Errors**
   - Verify API Key is correct and active
   - Check API endpoint URL configuration

5. **Batch Processing Failures**
   - Review telemetry logs for specific error details
   - Check network connectivity to FlxPoint API
   - Verify JSON structure matches API requirements

### Debugging Tips

1. **Enable Telemetry Logging**: Review event log for detailed processing information
2. **Check Item References**: Ensure items have proper barcode references
3. **Validate Price List**: Verify price list configuration and item pricing
4. **Test API Connectivity**: Use FlxPoint Setup test connection feature
5. **Review JSON Structure**: Ensure custom fields and variants are properly formatted

## Dependencies

### Required Tables
- `Item`: Business Central item master
- `Item Reference`: Item reference numbers (barcodes)
- `FlxPoint Setup`: Integration configuration
- `Price List Line`: Pricing information for GOPRICE field

### Required Pages
- `FlxPoint Setup`: Configuration and manual execution
- `Item Card`: Item configuration (FlxPoint Enabled field)

### External Dependencies
- FlxPoint API access
- Valid API credentials
- Network connectivity to FlxPoint servers

## Future Enhancements

### Potential Improvements
1. **Retry Logic**: Automatic retry for failed batches
2. **Progress Tracking**: Real-time progress indicators
3. **Selective Processing**: Process specific items or date ranges
4. **Conflict Resolution**: Handle duplicate SKU scenarios
5. **Performance Monitoring**: Detailed performance metrics

### Configuration Options
1. **Configurable Batch Size**: Allow adjustment of batch size
2. **Custom Field Mapping**: Dynamic custom field configuration
3. **Error Notification**: Email alerts for processing failures
4. **Scheduling**: Automated processing schedules

---

*This documentation covers the current implementation of the FlxPoint Create Inventory functionality. For updates or questions, refer to the source code in `Cod50713.FlxPointCreateInventory.al`.*
