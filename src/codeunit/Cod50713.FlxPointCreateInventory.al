codeunit 50713 "FlxPoint Create Inventory"
{
    procedure ProcessFlxPointEnabledItems(): Boolean
    var
        Item: Record Item;
        ItemReference: Record "Item Reference";
        FlxPointSetup: Record "FlxPoint Setup";
        TelemetryDimensions: Dictionary of [Text, Text];
        ProcessedCount: Integer;
        ErrorCount: Integer;
        BatchSize: Integer;
        CurrentBatch: Integer;
        TotalItems: Integer;
    begin
        Session.LogMessage('FlxPoint-CreateInv-0001', 'Processing FlxPoint Enabled Items Started', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'StartProcess');

        if not FlxPointSetup.Get('DEFAULT') then begin
            Session.LogMessage('FlxPoint-CreateInv-0002', 'FlxPoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'SetupMissing');
            exit(false);
        end;

        if not FlxPointSetup.Enabled then begin
            Session.LogMessage('FlxPoint-CreateInv-0003', 'FlxPoint integration is disabled', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'IntegrationDisabled');
            exit(false);
        end;

        // Filter items that are FlxPoint enabled
        Item.SetRange("FlxPoint Enabled", true);
        if not Item.FindSet() then begin
            Session.LogMessage('FlxPoint-CreateInv-0004', 'No FlxPoint enabled items found', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'NoItemsFound');
            exit(true);
        end;

        // Count total items for progress tracking
        TotalItems := 0;
        repeat
            ItemReference.SetRange("Item No.", Item."No.");
            ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
            TotalItems += ItemReference.Count();
        until Item.Next() = 0;

        // Process in batches of 20
        BatchSize := 20;
        CurrentBatch := 0;

        // Collect all items and process in batches
        if ProcessAllItemsInBatches(Item, ItemReference, BatchSize, ProcessedCount, ErrorCount, CurrentBatch) then begin
            // Success
        end;

        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ProcessedCount', Format(ProcessedCount));
        TelemetryDimensions.Add('ErrorCount', Format(ErrorCount));
        TelemetryDimensions.Add('TotalItems', Format(TotalItems));
        TelemetryDimensions.Add('BatchesProcessed', Format(CurrentBatch));
        Session.LogMessage('FlxPoint-CreateInv-0005', 'Processing FlxPoint Enabled Items Completed', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);

        exit(ErrorCount = 0);
    end;

    local procedure ProcessAllItemsInBatches(var Item: Record Item; var ItemReference: Record "Item Reference"; BatchSize: Integer; var ProcessedCount: Integer; var ErrorCount: Integer; var CurrentBatch: Integer): Boolean
    var
        BatchJsonArray: JsonArray;
        FlxPointSetup: Record "FlxPoint Setup";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        HttpContent: HttpContent;
        JsonText: Text;
        TelemetryDimensions: Dictionary of [Text, Text];
        ItemsInCurrentBatch: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT') then
            exit(false);

        // Process items in batches directly
        Item.SetRange("FlxPoint Enabled", true);
        if Item.FindSet() then begin
            repeat
                ItemReference.SetRange("Item No.", Item."No.");
                ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
                if ItemReference.FindSet() then begin
                    repeat
                        // Check if we need to start a new batch
                        if ItemsInCurrentBatch >= BatchSize then begin
                            // Send current batch
                            if ItemsInCurrentBatch > 0 then begin
                                CurrentBatch += 1;
                                if SendBatchToFlxPoint(BatchJsonArray, FlxPointSetup, Client, RequestMessage, ResponseMessage, RequestHeaders, ContentHeaders, ResponseText, HttpContent, JsonText, CurrentBatch, ItemsInCurrentBatch) then
                                    ProcessedCount += ItemsInCurrentBatch
                                else
                                    ErrorCount += 1;
                            end;

                            // Start new batch
                            Clear(BatchJsonArray);
                            ItemsInCurrentBatch := 0;
                        end;

                        // Add item to current batch
                        BuildInventoryItemJson(BatchJsonArray, Item, ItemReference);
                        ItemsInCurrentBatch += 1;
                    until ItemReference.Next() = 0;
                end;
            until Item.Next() = 0;
        end;

        // Send final batch if it has items
        if ItemsInCurrentBatch > 0 then begin
            CurrentBatch += 1;
            if SendBatchToFlxPoint(BatchJsonArray, FlxPointSetup, Client, RequestMessage, ResponseMessage, RequestHeaders, ContentHeaders, ResponseText, HttpContent, JsonText, CurrentBatch, ItemsInCurrentBatch) then
                ProcessedCount += ItemsInCurrentBatch
            else
                ErrorCount += 1;
        end;

        exit(true);
    end;

    local procedure SendBatchToFlxPoint(var BatchJsonArray: JsonArray; FlxPointSetup: Record "FlxPoint Setup"; var Client: HttpClient; var RequestMessage: HttpRequestMessage; var ResponseMessage: HttpResponseMessage; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var ResponseText: Text; var HttpContent: HttpContent; var JsonText: Text; BatchNumber: Integer; ItemsInBatch: Integer): Boolean
    var
        TelemetryDimensions: Dictionary of [Text, Text];
        ResponseJsonArray: JsonArray;
    begin
        // Convert to text for sending
        BatchJsonArray.WriteTo(JsonText);

        // Log the batch request
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('BatchNumber', Format(BatchNumber));
        TelemetryDimensions.Add('ItemsInBatch', Format(ItemsInBatch));
        Session.LogMessage('FlxPoint-CreateInv-0016', 'Processing Batch', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);

        // Setup HTTP request
        Clear(RequestMessage);
        RequestMessage.Method := 'POST';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/parents');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");

        // Set content
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content := HttpContent;

        // Send request
        if not Client.Send(RequestMessage, ResponseMessage) then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('BatchNumber', Format(BatchNumber));
            TelemetryDimensions.Add('Error', 'RequestFailed');
            Session.LogMessage('FlxPoint-CreateInv-0017', 'Failed to send batch request to FlxPoint', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('BatchNumber', Format(BatchNumber));
            TelemetryDimensions.Add('StatusCode', Format(ResponseMessage.HttpStatusCode()));
            TelemetryDimensions.Add('Response', ResponseText);
            Session.LogMessage('FlxPoint-CreateInv-0018', 'Batch Processing Failed: API Error Response', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Get response content
        ResponseMessage.Content().ReadAs(ResponseText);

        // Parse response to get created item details
        if ResponseJsonArray.ReadFrom(ResponseText) then begin
            ProcessBatchResponse(ResponseJsonArray, BatchNumber);
        end;

        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('BatchNumber', Format(BatchNumber));
        TelemetryDimensions.Add('ItemsInBatch', Format(ItemsInBatch));
        Session.LogMessage('FlxPoint-CreateInv-0019', 'Batch Processing Completed Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        exit(true);
    end;


    local procedure ProcessBatchResponse(JsonArray: JsonArray; BatchNumber: Integer)
    var
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
        CreatedItemId: Text;
        JsonObject: JsonObject;
        ItemIndex: Integer;
    begin
        // Process each item in the batch response
        for ItemIndex := 0 to JsonArray.Count - 1 do begin
            if JsonArray.Get(ItemIndex, JsonToken) then begin
                if JsonToken.IsObject() then begin
                    JsonObject := JsonToken.AsObject();
                    if JsonObject.Get('id', JsonToken) then begin
                        CreatedItemId := JsonToken.AsValue().AsText();
                        Clear(TelemetryDimensions);
                        TelemetryDimensions.Add('BatchNumber', Format(BatchNumber));
                        TelemetryDimensions.Add('ItemIndex', Format(ItemIndex));
                        TelemetryDimensions.Add('InventoryItemId', CreatedItemId);
                        Session.LogMessage('FlxPoint-CreateInv-0020', 'Inventory Item Created in Batch', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                    end;
                end;
            end;
        end;
    end;

    local procedure ProcessItemReference(Item: Record Item; ItemReference: Record "Item Reference"): Boolean
    begin
        // Create the item in FlxPoint (regardless of whether it already exists)
        exit(CreateInventoryItem(Item, ItemReference));
    end;

    local procedure CheckItemExistsInFlxPoint(ReferenceNo: Text): Boolean
    var
        FlxPointSetup: Record "FlxPoint Setup";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        if not FlxPointSetup.Get('DEFAULT') then
            exit(false);

        // Setup HTTP request to get inventory variants
        Clear(RequestMessage);
        RequestMessage.Method := 'GET';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/variants?skus=' + ReferenceNo);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");

        // Send request
        if not Client.Send(RequestMessage, ResponseMessage) then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('ReferenceNo', ReferenceNo);
            TelemetryDimensions.Add('Error', 'RequestFailed');
            Session.LogMessage('FlxPoint-CreateInv-0007', 'Failed to check if item exists in FlxPoint', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('ReferenceNo', ReferenceNo);
            TelemetryDimensions.Add('StatusCode', Format(ResponseMessage.HttpStatusCode()));
            TelemetryDimensions.Add('Response', ResponseText);
            Session.LogMessage('FlxPoint-CreateInv-0008', 'Error checking if item exists in FlxPoint', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Parse response
        ResponseMessage.Content().ReadAs(ResponseText);
        if not JsonObject.ReadFrom(ResponseText) then
            exit(false);

        // Check if data array exists and has items
        if JsonObject.Get('data', JsonToken) and JsonToken.IsArray() then begin
            JsonArray := JsonToken.AsArray();
            exit(JsonArray.Count > 0);
        end;

        exit(false);
    end;

    procedure CreateInventoryItem(Item: Record Item; ItemReference: Record "Item Reference"): Boolean
    var
        FlxPointSetup: Record "FlxPoint Setup";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        JsonArray: JsonArray;
        HttpContent: HttpContent;
        JsonText: Text;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        if not FlxPointSetup.Get('DEFAULT') then begin
            Session.LogMessage('FlxPoint-CreateInv-0009', 'FlxPoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'SetupMissing');
            exit(false);
        end;

        // Build the JSON request body as an array
        Clear(JsonArray);
        BuildInventoryItemJson(JsonArray, Item, ItemReference);

        // Convert to text for logging and sending
        JsonArray.WriteTo(JsonText);

        // Log the request content for debugging
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ItemNo', Item."No.");
        TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
        Session.LogMessage('FlxPoint-CreateInv-0010', 'Sending create inventory request: ' + JsonText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);

        // Setup HTTP request
        Clear(RequestMessage);
        RequestMessage.Method := 'POST';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/parents');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");

        // Setup content
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content := HttpContent;

        // Send request
        if not Client.Send(RequestMessage, ResponseMessage) then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('ItemNo', Item."No.");
            TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
            TelemetryDimensions.Add('Error', 'RequestFailed');
            Session.LogMessage('FlxPoint-CreateInv-0011', 'Create Inventory Failed: API Request Failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('ItemNo', Item."No.");
            TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
            TelemetryDimensions.Add('StatusCode', Format(ResponseMessage.HttpStatusCode()));
            TelemetryDimensions.Add('Response', ResponseText);
            Session.LogMessage('FlxPoint-CreateInv-0012', 'Create Inventory Failed: API Error Response', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;

        // Get response content
        ResponseMessage.Content().ReadAs(ResponseText);

        // Parse response to get created item details
        if JsonArray.ReadFrom(ResponseText) then begin
            ProcessCreateResponse(JsonArray, Item, ItemReference);
        end;

        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ItemNo', Item."No.");
        TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
        Session.LogMessage('FlxPoint-CreateInv-0013', 'Create Inventory Item Process Completed Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        exit(true);
    end;

    local procedure BuildInventoryItemJson(var JsonArray: JsonArray; Item: Record Item; ItemReference: Record "Item Reference")
    var
        InventoryItemObject: JsonObject;
        VariantsArray: JsonArray;
        VariantJsonObject: JsonObject;
        CustomFieldsArray: JsonArray;
        CustomFieldObject: JsonObject;
        FlxPointSetup: Record "FlxPoint Setup";
        pricelistline: record "Price List Line";
    begin
        // Build main inventory item object for FlxPoint API
        Clear(InventoryItemObject);
        InventoryItemObject.Add('sku', ItemReference."Reference No.");
        InventoryItemObject.Add('title', Item.Description);
        InventoryItemObject.Add('description', Item."Description 2");
        InventoryItemObject.Add('upc', ItemReference."Reference No.");
        InventoryItemObject.Add('requiresFfl', false);
        InventoryItemObject.Add('allowBackorders', false);
        InventoryItemObject.Add('archived', false);

        // Add custom fields for item
        Clear(CustomFieldsArray);

        // Add item number as custom field
        Clear(CustomFieldObject);

        // Add GOPRICE custom field with value 1.99
        Clear(CustomFieldObject);
        FlxPointSetup.Get('DEFAULT');
        pricelistline.SETRANGE(PriceListLine."Price List Code", FlxPointSetup."Price List Code");
        pricelistline.SetRange("Item Reference", ItemReference."Reference No.");
        CustomFieldObject.Add('name', 'GOPRICE');
        IF pricelistline.FindFirst() then
            CustomFieldObject.Add('value', Format(pricelistline."Unit Price")) else
            CustomFieldObject.Add('value', '1.99');
        CustomFieldsArray.Add(CustomFieldObject);

        if CustomFieldsArray.Count > 0 then
            InventoryItemObject.Add('customFields', CustomFieldsArray);

        // Build variants array with single variant
        Clear(VariantsArray);
        Clear(VariantJsonObject);
        VariantJsonObject.Add('sku', ItemReference."Reference No.");
        VariantJsonObject.Add('title', Item.Description);
        VariantJsonObject.Add('description', Item."Description 2");
        VariantJsonObject.Add('upc', ItemReference."Reference No.");
        VariantJsonObject.Add('requiresFfl', false);
        VariantJsonObject.Add('allowBackorders', false);
        VariantJsonObject.Add('archived', false);

        VariantsArray.Add(VariantJsonObject);
        InventoryItemObject.Add('variants', VariantsArray);

        // Add the inventory item directly to the array
        JsonArray.Add(InventoryItemObject);
    end;

    local procedure ProcessCreateResponse(JsonArray: JsonArray; Item: Record Item; ItemReference: Record "Item Reference")
    var
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
        CreatedItemId: Text;
        JsonObject: JsonObject;
    begin
        // Extract the created item ID from the response array
        if JsonArray.Count > 0 then begin
            JsonArray.Get(0, JsonToken);
            if JsonToken.IsObject() then begin
                JsonObject := JsonToken.AsObject();
                if JsonObject.Get('id', JsonToken) then begin
                    CreatedItemId := JsonToken.AsValue().AsText();
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('InventoryItemId', CreatedItemId);
                    TelemetryDimensions.Add('ItemNo', Item."No.");
                    TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
                    Session.LogMessage('FlxPoint-CreateInv-0014', 'Inventory Item Created Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                end;
            end;
        end;
    end;

    procedure CreateInventoryItemForItem(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
        ItemReference: Record "Item Reference";
        ProcessedCount: Integer;
        ErrorCount: Integer;
    begin
        if not Item.Get(ItemNo) then
            exit(false);

        if not Item."FlxPoint Enabled" then
            exit(false);

        // Find item references for this item with barcode type
        ItemReference.SetRange("Item No.", Item."No.");
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");

        if not ItemReference.FindSet() then
            exit(true);

        repeat
            if ProcessItemReference(Item, ItemReference) then
                ProcessedCount += 1
            else
                ErrorCount += 1;
        until ItemReference.Next() = 0;

        exit(ErrorCount = 0);
    end;
}
