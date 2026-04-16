codeunit 50713 "FlxPoint Create Inventory"
{
    procedure ProcessFlxPointEnabledItems(): Boolean
    var
        Item: Record Item;
        ItemReference: Record "Item Reference";
        FlxPointSetup: Record "FlxPoint Setup";
        ProcessedCount: Integer;
        ErrorCount: Integer;
        BatchSize: Integer;
        CurrentBatch: Integer;
        TotalItems: Integer;
        ErrorMessages: List of [Text];
        ErrorSummary: Text;
        ErrorDetails: Text;
        ErrorMsg: Text;
    begin
        if not FlxPointSetup.Get('DEFAULT') then begin
            Error('FlxPoint Setup not found. Please configure FlxPoint Setup first.');
            exit(false);
        end;

        if not FlxPointSetup.Enabled then begin
            Error('FlxPoint integration is disabled. Please enable it in FlxPoint Setup.');
            exit(false);
        end;

        // Filter items that are FlxPoint enabled
        Item.SetRange("FlxPoint Enabled", true);
        if not Item.FindSet() then
            exit(true);

        // Count total items for progress tracking
        TotalItems := 0;
        repeat
            ItemReference.SetRange("Item No.", Item."No.");
            ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
            ItemReference.SetFilter("Unit of Measure", '<>%1', 'ROUNDS');
            TotalItems += ItemReference.Count();
        until Item.Next() = 0;

        // Process in batches of 20
        BatchSize := 20;
        CurrentBatch := 0;
        Clear(ErrorMessages);

        // Log start of process
        Session.LogMessage('FlxPoint-CreateInv-0001', StrSubstNo('Processing started. Total items to process: %1', TotalItems), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');

        // Collect all items and process in batches
        if ProcessAllItemsInBatches(Item, ItemReference, BatchSize, ProcessedCount, ErrorCount, CurrentBatch, ErrorMessages) then begin
            // Success
        end;

        // Log completion
        Session.LogMessage('FlxPoint-CreateInv-0005', StrSubstNo('Processing completed. Processed: %1, Errors: %2', ProcessedCount, ErrorCount), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');

        // Display errors at the end if any occurred
        if ErrorMessages.Count > 0 then begin
            ErrorSummary := StrSubstNo('Inventory creation completed with %1 error(s).\', ErrorCount);
            ErrorSummary += StrSubstNo('Successfully processed: %1 item(s)\', ProcessedCount);
            ErrorSummary += '\Error Details:\';

            foreach ErrorMsg in ErrorMessages do begin
                ErrorDetails += ErrorMsg + '\';
            end;

            Error(ErrorSummary + ErrorDetails);
            exit(false);
        end;

        // Success message if no errors
        if ProcessedCount > 0 then
            Message('Successfully created %1 inventory item(s) in FlxPoint.', ProcessedCount);

        exit(true);
    end;

    local procedure ProcessAllItemsInBatches(var Item: Record Item; var ItemReference: Record "Item Reference"; BatchSize: Integer; var ProcessedCount: Integer; var ErrorCount: Integer; var CurrentBatch: Integer; var ErrorMessages: List of [Text]): Boolean
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
        ItemsInCurrentBatch: Integer;
        BatchItemList: List of [Text]; // Track items in current batch
        ItemInfo: Text;
    begin
        if not FlxPointSetup.Get('DEFAULT') then
            exit(false);

        // Process items in batches directly
        Item.SetRange("FlxPoint Enabled", true);
        if Item.FindSet() then begin
            repeat
                ItemReference.SetRange("Item No.", Item."No.");
                ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
                ItemReference.SetFilter("Unit of Measure", '<>%1', 'ROUNDS');
                ItemReference.SetFilter("Barcode Type", '<>%1', ItemReference."Barcode Type"::MPN);
                if ItemReference.FindSet() then begin
                    repeat
                        // Check if we need to start a new batch
                        if ItemsInCurrentBatch >= BatchSize then begin
                            // Send current batch
                            if ItemsInCurrentBatch > 0 then begin
                                CurrentBatch += 1;
                                if SendBatchToFlxPoint(BatchJsonArray, FlxPointSetup, Client, RequestMessage, ResponseMessage, RequestHeaders, ContentHeaders, ResponseText, HttpContent, JsonText, CurrentBatch, ItemsInCurrentBatch, BatchItemList, ErrorMessages) then
                                    ProcessedCount += ItemsInCurrentBatch
                                else
                                    ErrorCount += 1;
                            end;

                            // Start new batch
                            Clear(BatchJsonArray);
                            Clear(BatchItemList);
                            ItemsInCurrentBatch := 0;
                        end;

                        // Add item to current batch
                        BuildInventoryItemJson(BatchJsonArray, Item, ItemReference);
                        // Track which items are in this batch for error reporting
                        ItemInfo := StrSubstNo('Item: %1, UPC: %2', Item."No.", ItemReference."Reference No.");
                        BatchItemList.Add(ItemInfo);
                        ItemsInCurrentBatch += 1;
                    until ItemReference.Next() = 0;
                end;
            until Item.Next() = 0;
        end;

        // Send final batch if it has items
        if ItemsInCurrentBatch > 0 then begin
            CurrentBatch += 1;
            if SendBatchToFlxPoint(BatchJsonArray, FlxPointSetup, Client, RequestMessage, ResponseMessage, RequestHeaders, ContentHeaders, ResponseText, HttpContent, JsonText, CurrentBatch, ItemsInCurrentBatch, BatchItemList, ErrorMessages) then
                ProcessedCount += ItemsInCurrentBatch
            else
                ErrorCount += 1;
        end;

        exit(true);
    end;

    local procedure SendBatchToFlxPoint(var BatchJsonArray: JsonArray; FlxPointSetup: Record "FlxPoint Setup"; var Client: HttpClient; var RequestMessage: HttpRequestMessage; var ResponseMessage: HttpResponseMessage; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var ResponseText: Text; var HttpContent: HttpContent; var JsonText: Text; BatchNumber: Integer; ItemsInBatch: Integer; var BatchItemList: List of [Text]; var ErrorMessages: List of [Text]): Boolean
    var
        ResponseJsonArray: JsonArray;
        ErrorMsg: Text;
        ItemInfo: Text;
        ItemsInBatchText: Text;
    begin
        // Convert to text for sending
        BatchJsonArray.WriteTo(JsonText);

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
            // Network/communication error
            ItemsInBatchText := '';
            foreach ItemInfo in BatchItemList do begin
                if ItemsInBatchText <> '' then ItemsInBatchText += ', ';
                ItemsInBatchText += ItemInfo;
            end;
            ErrorMsg := StrSubstNo('Batch %1 (%2 items): Network error - Failed to send request to FlxPoint API. Items: %3', BatchNumber, ItemsInBatch, ItemsInBatchText);
            ErrorMessages.Add(ErrorMsg);
            Session.LogMessage('FlxPoint-CreateInv-0017', ErrorMsg, Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            // API error response
            ItemsInBatchText := '';
            foreach ItemInfo in BatchItemList do begin
                if ItemsInBatchText <> '' then ItemsInBatchText += ', ';
                ItemsInBatchText += ItemInfo;
            end;
            ErrorMsg := StrSubstNo('Batch %1 (%2 items): FlxPoint API error - Status: %3, Response: %4. Items: %5', BatchNumber, ItemsInBatch, ResponseMessage.HttpStatusCode(), CopyStr(ResponseText, 1, 500), ItemsInBatchText);
            ErrorMessages.Add(ErrorMsg);
            Session.LogMessage('FlxPoint-CreateInv-0018', StrSubstNo('Batch %1 API error: Status %2, Response: %3', BatchNumber, ResponseMessage.HttpStatusCode(), CopyStr(ResponseText, 1, 500)), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;

        // Get response content
        ResponseMessage.Content().ReadAs(ResponseText);

        // Parse response to get created item details
        if ResponseJsonArray.ReadFrom(ResponseText) then begin
            ProcessBatchResponse(ResponseJsonArray, BatchNumber);
            Session.LogMessage('FlxPoint-CreateInv-0019', StrSubstNo('Batch %1 completed successfully with %2 items', BatchNumber, ItemsInBatch), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        end else begin
            // JSON parsing error
            ItemsInBatchText := '';
            foreach ItemInfo in BatchItemList do begin
                if ItemsInBatchText <> '' then ItemsInBatchText += ', ';
                ItemsInBatchText += ItemInfo;
            end;
            ErrorMsg := StrSubstNo('Batch %1 (%2 items): Invalid response format from FlxPoint API. Items: %3', BatchNumber, ItemsInBatch, ItemsInBatchText);
            ErrorMessages.Add(ErrorMsg);
            Session.LogMessage('FlxPoint-CreateInv-0018', StrSubstNo('Batch %1 JSON parsing error', BatchNumber), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;

        exit(true);
    end;


    local procedure ProcessBatchResponse(JsonArray: JsonArray; BatchNumber: Integer)
    var
        JsonToken: JsonToken;
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
                    end;
                end;
            end;
        end;
    end;

    local procedure ProcessItemReference(Item: Record Item; ItemReference: Record "Item Reference"): Boolean
    begin
        // Create the item in FlxPoint (regardless of whether it already exists)
        // Note: This procedure is kept for backward compatibility but CreateInventoryItemForItem now handles errors directly
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
        if not Client.Send(RequestMessage, ResponseMessage) then
            exit(false);

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
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
    begin
        if not FlxPointSetup.Get('DEFAULT') then
            exit(false);

        // Build the JSON request body as an array
        Clear(JsonArray);
        BuildInventoryItemJson(JsonArray, Item, ItemReference);

        // Convert to text for sending
        JsonArray.WriteTo(JsonText);

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
        if not Client.Send(RequestMessage, ResponseMessage) then
            exit(false);

        // Check response
        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            exit(false);
        end;

        // Get response content
        ResponseMessage.Content().ReadAs(ResponseText);

        // Parse response to get created item details
        if JsonArray.ReadFrom(ResponseText) then begin
            ProcessCreateResponse(JsonArray, Item, ItemReference);
        end;

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
        ErrorMessages: List of [Text];
        ErrorMsg: Text;
        ErrorSummary: Text;
        ErrorDetails: Text;
    begin
        if not Item.Get(ItemNo) then begin
            Error('Item %1 not found.', ItemNo);
            exit(false);
        end;

        if not Item."FlxPoint Enabled" then begin
            Error('Item %1 is not FlxPoint enabled.', ItemNo);
            exit(false);
        end;

        // Find item references for this item with barcode type
        ItemReference.SetRange("Item No.", Item."No.");
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");

        if not ItemReference.FindSet() then
            exit(true);

        Clear(ErrorMessages);
        repeat
            if not CreateInventoryItem(Item, ItemReference) then begin
                ErrorCount += 1;
                ErrorMsg := StrSubstNo('Item: %1, UPC: %2 - Failed to create inventory item in FlxPoint', Item."No.", ItemReference."Reference No.");
                ErrorMessages.Add(ErrorMsg);
                Session.LogMessage('FlxPoint-CreateInv-0021', ErrorMsg, Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            end else begin
                ProcessedCount += 1;
                Session.LogMessage('FlxPoint-CreateInv-0020', StrSubstNo('Item %1 (UPC: %2) created successfully', Item."No.", ItemReference."Reference No."), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            end;
        until ItemReference.Next() = 0;

        // Display errors if any occurred
        if ErrorMessages.Count > 0 then begin
            ErrorSummary := StrSubstNo('Inventory creation for item %1 completed with %2 error(s).\', ItemNo, ErrorCount);
            ErrorSummary += StrSubstNo('Successfully processed: %1 item reference(s)\', ProcessedCount);
            ErrorSummary += '\Error Details:\';

            foreach ErrorMsg in ErrorMessages do begin
                ErrorDetails += ErrorMsg + '\';
            end;

            Error(ErrorSummary + ErrorDetails);
            exit(false);
        end;

        // Success message if no errors
        if ProcessedCount > 0 then
            Message('Successfully created %1 inventory item(s) for item %2 in FlxPoint.', ProcessedCount, ItemNo);

        exit(true);
    end;
}
