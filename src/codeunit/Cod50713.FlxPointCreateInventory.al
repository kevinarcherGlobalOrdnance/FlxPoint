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

        repeat
            // Find item references for this item with barcode type
            ItemReference.SetRange("Item No.", Item."No.");
            ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");

            if ItemReference.FindSet() then begin
                repeat
                    if ProcessItemReference(Item, ItemReference) then
                        ProcessedCount += 1
                    else
                        ErrorCount += 1;
                until ItemReference.Next() = 0;
            end;
        until Item.Next() = 0;

        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ProcessedCount', Format(ProcessedCount));
        TelemetryDimensions.Add('ErrorCount', Format(ErrorCount));
        Session.LogMessage('FlxPoint-CreateInv-0005', 'Processing FlxPoint Enabled Items Completed', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);

        exit(ErrorCount = 0);
    end;

    local procedure ProcessItemReference(Item: Record Item; ItemReference: Record "Item Reference"): Boolean
    var
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Check if this item reference already exists in FlxPoint
        if CheckItemExistsInFlxPoint(ItemReference."Reference No.") then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
            TelemetryDimensions.Add('ItemNo', Item."No.");
            Session.LogMessage('FlxPoint-CreateInv-0006', 'Item already exists in FlxPoint', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(true);
        end;

        // Create the item in FlxPoint
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
        RequestMessage.SetRequestUri('https://api.flxpoint.com/v2/inventory/variants?sku=' + ReferenceNo);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Authorization', 'Bearer ' + FlxPointSetup."API Key");

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
        JsonObject: JsonObject;
        HttpContent: HttpContent;
        JsonText: Text;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        if not FlxPointSetup.Get('DEFAULT') then begin
            Session.LogMessage('FlxPoint-CreateInv-0009', 'FlxPoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'SetupMissing');
            exit(false);
        end;

        // Build the JSON request body
        Clear(JsonObject);
        BuildInventoryItemJson(JsonObject, Item, ItemReference);

        // Convert to text for logging and sending
        JsonObject.WriteTo(JsonText);

        // Log the request content for debugging
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ItemNo', Item."No.");
        TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
        Session.LogMessage('FlxPoint-CreateInv-0010', 'Sending create inventory request: ' + JsonText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);

        // Setup HTTP request
        Clear(RequestMessage);
        RequestMessage.Method := 'POST';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/v2/inventory');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Authorization', 'Bearer ' + FlxPointSetup."API Key");

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
        if JsonObject.ReadFrom(ResponseText) then begin
            ProcessCreateResponse(JsonObject, Item, ItemReference);
        end;

        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('ItemNo', Item."No.");
        TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
        Session.LogMessage('FlxPoint-CreateInv-0013', 'Create Inventory Item Process Completed Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        exit(true);
    end;

    local procedure BuildInventoryItemJson(var JsonObject: JsonObject; Item: Record Item; ItemReference: Record "Item Reference")
    var
        VariantsArray: JsonArray;
        VariantJsonObject: JsonObject;
        CustomFieldsArray: JsonArray;
        CustomFieldObject: JsonObject;
    begin
        // Build main inventory item object for FlxPoint v2 API
        JsonObject.Add('sku', ItemReference."Reference No.");
        JsonObject.Add('title', Item.Description);
        JsonObject.Add('description', Item."Description 2");
        JsonObject.Add('upc', ItemReference."Reference No.");
        JsonObject.Add('requiresFfl', false);
        JsonObject.Add('allowBackorders', true);
        JsonObject.Add('archived', false);

        // Add custom fields for item
        Clear(CustomFieldsArray);

        // Add item number as custom field
        Clear(CustomFieldObject);
        CustomFieldObject.Add('name', 'ITEM_NO');
        CustomFieldObject.Add('value', Item."No.");
        CustomFieldsArray.Add(CustomFieldObject);

        // Add unit of measure as custom field
        if ItemReference."Unit of Measure" <> '' then begin
            Clear(CustomFieldObject);
            CustomFieldObject.Add('name', 'UOM');
            CustomFieldObject.Add('value', ItemReference."Unit of Measure");
            CustomFieldsArray.Add(CustomFieldObject);
        end;

        // Add unit price if available
        if Item."Unit Price" > 0 then begin
            Clear(CustomFieldObject);
            CustomFieldObject.Add('name', 'UNIT_PRICE');
            CustomFieldObject.Add('value', Format(Item."Unit Price"));
            CustomFieldsArray.Add(CustomFieldObject);
        end;

        if CustomFieldsArray.Count > 0 then
            JsonObject.Add('customFields', CustomFieldsArray);

        // Build variants array with single variant
        Clear(VariantsArray);
        Clear(VariantJsonObject);
        VariantJsonObject.Add('sku', ItemReference."Reference No.");
        VariantJsonObject.Add('title', Item.Description);
        VariantJsonObject.Add('description', Item."Description 2");
        VariantJsonObject.Add('upc', ItemReference."Reference No.");
        VariantJsonObject.Add('requiresFfl', false);
        VariantJsonObject.Add('allowBackorders', true);
        VariantJsonObject.Add('archived', false);

        // Add custom fields for variant
        if CustomFieldsArray.Count > 0 then
            VariantJsonObject.Add('customFields', CustomFieldsArray);

        VariantsArray.Add(VariantJsonObject);
        JsonObject.Add('variants', VariantsArray);
    end;

    local procedure ProcessCreateResponse(JsonObject: JsonObject; Item: Record Item; ItemReference: Record "Item Reference")
    var
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
        CreatedItemId: Text;
    begin
        // Extract the created item ID from the response
        if JsonObject.Get('id', JsonToken) then begin
            CreatedItemId := JsonToken.AsValue().AsText();
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('InventoryItemId', CreatedItemId);
            TelemetryDimensions.Add('ItemNo', Item."No.");
            TelemetryDimensions.Add('ReferenceNo', ItemReference."Reference No.");
            Session.LogMessage('FlxPoint-CreateInv-0014', 'Inventory Item Created Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
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
