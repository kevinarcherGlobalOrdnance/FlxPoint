codeunit 50704 "FlxPoint Fulfillment"
{
    var FlxPointSetup: Record "FlxPoint Setup";
    ErrorMsg: Label 'Error processing fulfillment requests: %1', Comment = '%1 = Error message';
    JobQueueEntry: Record "Job Queue Entry";
    FlxPointCreateSalesOrder: Codeunit "FlxPoint Create Sales Order";
    trigger OnRun()
    begin
        if not TryProcessAllFulfillmentRequests()then CreateJobQueueLogEntry('FlxPoint Fulfillment Process Failed', GetLastErrorText(), true);
    end;
    local procedure TryProcessAllFulfillmentRequests(): Boolean begin
        ProcessFulfillmentRequests();
        // Launch the CreateSalesOrder codeunit
        if not TryRunCreateSalesOrder()then begin
            CreateJobQueueLogEntry('FlxPoint Create Sales Order Failed', GetLastErrorText(), true);
            exit(false);
        end;
        exit(true);
    end;
    local procedure TryRunCreateSalesOrder(): Boolean begin
        FlxPointCreateSalesOrder.Run();
        exit(true);
    end;
    procedure GetFulfillmentRequests(var FulfillmentRequests: JsonArray): Boolean var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        ResponseArray: JsonArray;
        JsonToken: JsonToken;
        DataArray: JsonArray;
        Page: Integer;
        HasMorePages: Boolean;
        PageSize: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT')then begin
            CreateJobQueueLogEntry('FlxPoint Setup Error', 'FlxPoint Setup not found.', true);
            exit(false);
        end;
        if not FlxPointSetup.Enabled then begin
            CreateJobQueueLogEntry('FlxPoint Integration Disabled', 'FlxPoint integration is not enabled.', true);
            exit(false);
        end;
        // Initialize the result array only if it's empty
        if FulfillmentRequests.Count = 0 then Clear(FulfillmentRequests);
        Page:=1;
        PageSize:=20; // Adjust page size as needed
        HasMorePages:=true;
        while HasMorePages do begin
            // Create a new request message for each page
            Clear(RequestMessage);
            RequestMessage.Method:='GET';
            RequestMessage.SetRequestUri('https://api.flxpoint.com/fulfillment-requests?filterPageSize=' + Format(PageSize) + '&filterPageNumber=' + Format(Page));
            RequestMessage.GetHeaders(RequestHeaders);
            RequestHeaders.Add('Accept', 'application/json');
            RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
            if not Client.Send(RequestMessage, ResponseMessage)then begin
                Session.LogMessage('FlxPointFulfillment', StrSubstNo('Failed to send request to FlxPoint API for page %1', Page), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                CreateJobQueueLogEntry('FlxPoint API Request Failed', StrSubstNo('Failed to send request to FlxPoint API for page %1', Page), true);
                exit(false);
            end;
            if not ResponseMessage.IsSuccessStatusCode then begin
                ResponseMessage.Content.ReadAs(ResponseText);
                Session.LogMessage('FlxPointFulfillment', StrSubstNo('FlxPoint API returned error for page %1. Status: %2, Response: %3', Page, ResponseMessage.HttpStatusCode, ResponseText), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                // Check if the error is due to already acknowledged request
                if ResponseMessage.HttpStatusCode = 400 then if ResponseText.Contains('already acknowledged')then begin
                        Session.LogMessage('FlxPointFulfillment', 'Request already acknowledged, continuing...', Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                        exit(true);
                    end;
                CreateJobQueueLogEntry('FlxPoint API Error', StrSubstNo('FlxPoint API returned error: %1. Response: %2', ResponseMessage.HttpStatusCode, ResponseText), true);
                exit(false);
            end;
            ResponseMessage.Content.ReadAs(ResponseText);
            // Log the raw response for debugging
            Session.LogMessage('FlxPointFulfillment', StrSubstNo('Raw Response for Page %1: %2', Page, ResponseText), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            // Try to parse the response as an array first
            if ResponseArray.ReadFrom(ResponseText)then begin
                // If it's a direct array, add all items
                if ResponseArray.Count > 0 then begin
                    foreach JsonToken in ResponseArray do begin
                        if JsonToken.IsObject()then begin
                            FulfillmentRequests.Add(JsonToken);
                            Session.LogMessage('FlxPointFulfillment', StrSubstNo('Added item to FulfillmentRequests array. Total items now: %1', FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                        end
                        else
                            Session.LogMessage('FlxPointFulfillment', 'Skipped non-object item in data array', Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    end;
                    HasMorePages:=true;
                end
                else
                begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Empty array found on page %1, stopping pagination', Page), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    HasMorePages:=false;
                end;
            end
            else
            begin
                // If not an array, try parsing as an object
                if not JsonObject.ReadFrom(ResponseText)then begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Failed to parse JSON for page %1. Response length: %2, First 100 chars: %3', Page, StrLen(ResponseText), CopyStr(ResponseText, 1, 100)), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    CreateJobQueueLogEntry('FlxPoint JSON Parse Error', StrSubstNo('Failed to parse FlxPoint API response for page %1', Page), true);
                    exit(false);
                end;
                // Log the parsed object structure
                Session.LogMessage('FlxPointFulfillment', StrSubstNo('Successfully parsed JSON for Page %1', Page), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                // Get the data array
                if not JsonObject.Get('data', JsonToken)then begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('No data field found in response for page %1', Page), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    CreateJobQueueLogEntry('FlxPoint API Response Error', StrSubstNo('No data found in FlxPoint API response for page %1', Page), true);
                    exit(false);
                end;
                if not JsonToken.IsArray()then begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Data field is not an array for page %1', Page), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    CreateJobQueueLogEntry('FlxPoint API Response Error', StrSubstNo('Expected array in data field for page %1', Page), true);
                    exit(false);
                end;
                DataArray:=JsonToken.AsArray();
                // Log the number of items found in this page
                Session.LogMessage('FlxPointFulfillment', StrSubstNo('Found %1 items on page %2', DataArray.Count, Page), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                // Add items from current page to the result array
                if DataArray.Count > 0 then begin
                    foreach JsonToken in DataArray do begin
                        if JsonToken.IsObject()then begin
                            FulfillmentRequests.Add(JsonToken);
                            Session.LogMessage('FlxPointFulfillment', StrSubstNo('Added item to FulfillmentRequests array. Total items now: %1', FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                        end
                        else
                            Session.LogMessage('FlxPointFulfillment', 'Skipped non-object item in data array', Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    end;
                    HasMorePages:=true;
                end
                else
                begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Empty data array found on page %1, stopping pagination', Page), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    HasMorePages:=false;
                end;
            end;
            // Log the current state of the FulfillmentRequests array
            Session.LogMessage('FlxPointFulfillment', StrSubstNo('After page %1, FulfillmentRequests array has %2 items', Page, FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            Page+=1;
        end;
        // Log final results
        Session.LogMessage('FlxPointFulfillment', StrSubstNo('Finished processing. Total items collected: %1', FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        exit(true);
    end;
    procedure ProcessFulfillmentRequests()
    var
        FulfillmentRequests: JsonArray;
        FulfillmentRequest: JsonToken;
        JsonObject: JsonObject;
        i: Integer;
        TotalProcessed: Integer;
        ErrorCount: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT')then begin
            CreateJobQueueLogEntry('FlxPoint Setup Error', 'FlxPoint Setup not found.', true);
            exit;
        end;
        if not FlxPointSetup.Enabled then begin
            CreateJobQueueLogEntry('FlxPoint Integration Disabled', 'FlxPoint integration is not enabled.', true);
            exit;
        end;
        TotalProcessed:=0;
        ErrorCount:=0;
        if not GetFulfillmentRequests(FulfillmentRequests)then begin
            CreateJobQueueLogEntry('FlxPoint Fulfillment Request Retrieval Failed', 'Failed to retrieve fulfillment requests from FlxPoint API', true);
            exit;
        end;
        Session.LogMessage('FlxPointFulfillment', StrSubstNo('Starting to process %1 fulfillment requests', FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        for i:=0 to FulfillmentRequests.Count - 1 do begin
            if FulfillmentRequests.Get(i, FulfillmentRequest)then begin
                if FulfillmentRequest.IsObject()then begin
                    JsonObject:=FulfillmentRequest.AsObject();
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Processing request %1 of %2', i + 1, FulfillmentRequests.Count), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    if TryProcessFulfillmentRequest(JsonObject)then TotalProcessed+=1
                    else
                        ErrorCount+=1;
                end
                else
                begin
                    Session.LogMessage('FlxPointFulfillment', StrSubstNo('Skipping non-object request at index %1', i), Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    ErrorCount+=1;
                end;
            end
            else
            begin
                Session.LogMessage('FlxPointFulfillment', StrSubstNo('Failed to get request at index %1', i), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                ErrorCount+=1;
            end;
        end;
        Session.LogMessage('FlxPointFulfillment', StrSubstNo('Finished processing. Total processed: %1, Errors: %2', TotalProcessed, ErrorCount), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        if ErrorCount > 0 then CreateJobQueueLogEntry('FlxPoint Fulfillment Process Completed with Errors', StrSubstNo('Processed %1 fulfillment requests with %2 errors.', TotalProcessed, ErrorCount), false);
    end;
    local procedure IsRequestAcknowledged(FulfillmentRequest: JsonObject): Boolean var
        JsonToken: JsonToken;
        StatusObj: JsonObject;
        StatusName: Text;
    begin
        if FulfillmentRequest.Get('fulfillmentRequestStatus', JsonToken)then if JsonToken.IsObject()then begin
                StatusObj:=JsonToken.AsObject();
                if StatusObj.Get('name', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then begin
                            StatusName:=JsonToken.AsValue().AsText();
                            exit(StatusName = 'Acknowledged');
                        end;
            end;
        exit(false);
    end;
    local procedure TryProcessFulfillmentRequest(FulfillmentRequest: JsonObject): Boolean begin
        ProcessFulfillmentRequest(FulfillmentRequest);
        exit(true);
    end;
    local procedure ProcessFulfillmentRequest(FulfillmentRequest: JsonObject)
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
        JsonToken: JsonToken;
        ShippingAddressObj: JsonObject;
        StatusObj: JsonObject;
        RequestId: Text;
        FulfillmentRequestNo: Text;
        OrderId: Text;
        ShippingName: Text;
        ShippingAddress1: Text;
        ShippingAddress2: Text;
        ShippingCity: Text;
        ShippingState: Text;
        ShippingCountry: Text;
        ShippingStateCode: Text;
        ShippingCountryCode: Text;
        ShippingPostal: Text;
        ShippingEmail: Text;
        ShippingPhone: Text;
        ShippingCompany: Text;
        ShippingFirstName: Text;
        ShippingLastName: Text;
        FulfillmentStatus: Text;
        GeneratedAt: DateTime;
        VoidedAt: DateTime;
        IsNewRecord: Boolean;
    begin
        // Get header fields
        if FulfillmentRequest.Get('id', JsonToken)then if JsonToken.IsValue()then RequestId:=JsonToken.AsValue().AsText();
        if FulfillmentRequest.Get('fulfillmentRequestNumber', JsonToken)then if JsonToken.IsValue()then FulfillmentRequestNo:=JsonToken.AsValue().AsText();
        if FulfillmentRequest.Get('orderId', JsonToken)then if JsonToken.IsValue()then OrderId:=JsonToken.AsValue().AsText();
        if FulfillmentRequest.Get('fulfillmentRequestStatus', JsonToken)then if JsonToken.IsObject()then begin
                StatusObj:=JsonToken.AsObject();
                if StatusObj.Get('name', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FulfillmentStatus:=JsonToken.AsValue().AsText();
            end;
        if FulfillmentRequest.Get('generatedAt', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(GeneratedAt, JsonToken.AsValue().AsText());
        if FulfillmentRequest.Get('voidedAt', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(VoidedAt, JsonToken.AsValue().AsText());
        // Get shipping address
        if FulfillmentRequest.Get('shippingAddress', JsonToken)then begin
            ShippingAddressObj:=JsonToken.AsObject();
            if ShippingAddressObj.Get('name', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingName:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('addressLine1', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingAddress1:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('addressLine2', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingAddress2:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('city', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingCity:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('state', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingState:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('country', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingCountry:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('stateCode', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingStateCode:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('countryCode', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingCountryCode:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('postal', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingPostal:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('email', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingEmail:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('phone', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingPhone:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('companyName', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingCompany:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('firstName', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingFirstName:=JsonToken.AsValue().AsText();
            if ShippingAddressObj.Get('lastName', JsonToken)then if not JsonToken.AsValue().IsNull()then ShippingLastName:=JsonToken.AsValue().AsText();
        end;
        // Insert or update header
        IsNewRecord:=not FlxPointFulfillmentReq.Get(RequestId);
        if IsNewRecord then begin
            FlxPointFulfillmentReq.Init();
            Evaluate(FlxPointFulfillmentReq."Request ID", RequestId);
        end;
        // Always update these fields
        FlxPointFulfillmentReq."Fulfillment Status":=FulfillmentStatus;
        FlxPointFulfillmentReq."Generated At":=GeneratedAt;
        FlxPointFulfillmentReq."Voided At":=VoidedAt;
        // Only update other fields for new records
        if IsNewRecord then begin
            FlxPointFulfillmentReq."Fulfillment Request No.":=FulfillmentRequestNo;
            Evaluate(FlxPointFulfillmentReq."Order ID", OrderId);
            FlxPointFulfillmentReq."Shipping Name":=ShippingName;
            FlxPointFulfillmentReq."Shipping Address 1":=ShippingAddress1;
            FlxPointFulfillmentReq."Shipping Address 2":=ShippingAddress2;
            FlxPointFulfillmentReq."Shipping City":=ShippingCity;
            FlxPointFulfillmentReq."Shipping State":=ShippingState;
            FlxPointFulfillmentReq."Shipping Country":=ShippingCountry;
            FlxPointFulfillmentReq."Shipping State Code":=ShippingStateCode;
            FlxPointFulfillmentReq."Shipping Country Code":=ShippingCountryCode;
            FlxPointFulfillmentReq."Shipping Postal Code":=ShippingPostal;
            FlxPointFulfillmentReq."Shipping Email":=ShippingEmail;
            FlxPointFulfillmentReq."Shipping Phone":=ShippingPhone;
            FlxPointFulfillmentReq."Shipping Company":=ShippingCompany;
            FlxPointFulfillmentReq."Shipping First Name":=ShippingFirstName;
            FlxPointFulfillmentReq."Shipping Last Name":=ShippingLastName;
        end;
        if IsNewRecord then FlxPointFulfillmentReq.Insert(true)
        else
            FlxPointFulfillmentReq.Modify(true);
        // Process line items only for new records
        if IsNewRecord then if FulfillmentRequest.Get('fulfillmentRequestItems', JsonToken)then if JsonToken.IsArray()then ProcessFulfillmentRequestLines(RequestId, JsonToken.AsArray());
    end;
    local procedure ProcessFulfillmentRequestLines(RequestId: Text; Items: JsonArray)
    var
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
        Item: JsonToken;
        JsonObject: JsonObject;
        LineNo: Integer;
        SKU: Text;
        Title: Text;
        Quantity: Decimal;
        Cost: Decimal;
        JsonToken: JsonToken;
        WeightUnitObj: JsonObject;
        DimensionUnitObj: JsonObject;
    begin
        LineNo:=0;
        foreach Item in Items do begin
            LineNo+=10000;
            if Item.IsObject()then begin
                JsonObject:=Item.AsObject();
                if JsonObject.Get('sku', JsonToken)then if JsonToken.IsValue()then SKU:=JsonToken.AsValue().AsText();
                if JsonObject.Get('title', JsonToken)then if JsonToken.IsValue()then Title:=JsonToken.AsValue().AsText();
                if JsonObject.Get('quantity', JsonToken)then if JsonToken.IsValue()then Evaluate(Quantity, JsonToken.AsValue().AsText());
                if JsonObject.Get('cost', JsonToken)then if JsonToken.IsValue()then Evaluate(Cost, JsonToken.AsValue().AsText());
                if not FlxPointFulfillmentReqLine.Get(RequestId, LineNo)then begin
                    FlxPointFulfillmentReqLine.Init();
                    Evaluate(FlxPointFulfillmentReqLine."Request ID", RequestId);
                    FlxPointFulfillmentReqLine."Line No.":=LineNo;
                end;
                // Basic fields
                FlxPointFulfillmentReqLine.SKU:=SKU;
                FlxPointFulfillmentReqLine.Title:=Title;
                FlxPointFulfillmentReqLine.Quantity:=Quantity;
                FlxPointFulfillmentReqLine.Cost:=Cost;
                FlxPointFulfillmentReqLine.Subtotal:=Quantity * Cost;
                // Additional fields
                if JsonObject.Get('itemReferenceId', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine."Item Reference ID":=JsonToken.AsValue().AsText();
                if JsonObject.Get('referenceId', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine."Reference ID":=JsonToken.AsValue().AsText();
                if JsonObject.Get('shippedQuantity', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Shipped Quantity", JsonToken.AsValue().AsText());
                if JsonObject.Get('voidedQuantity', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Voided Quantity", JsonToken.AsValue().AsText());
                if JsonObject.Get('acknowledgedQuantity', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Acknowledged Quantity", JsonToken.AsValue().AsText());
                if JsonObject.Get('secondaryAcknowledgedQuantity', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Sec. Ack. Quantity", JsonToken.AsValue().AsText());
                if JsonObject.Get('inventoryVariantId', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Inventory Variant ID", JsonToken.AsValue().AsText());
                if JsonObject.Get('orderItemId', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine."Order Item ID", JsonToken.AsValue().AsText());
                // Weight and dimensions
                if JsonObject.Get('weightUnit', JsonToken)then if JsonToken.IsObject()then begin
                        WeightUnitObj:=JsonToken.AsObject();
                        if WeightUnitObj.Get('handle', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine."Weight Unit":=JsonToken.AsValue().AsText();
                    end;
                if JsonObject.Get('weight', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine.Weight, JsonToken.AsValue().AsText());
                if JsonObject.Get('dimensionUnit', JsonToken)then if JsonToken.IsObject()then begin
                        DimensionUnitObj:=JsonToken.AsObject();
                        if DimensionUnitObj.Get('handle', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine."Dimension Unit":=JsonToken.AsValue().AsText();
                    end;
                if JsonObject.Get('length', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine.Length, JsonToken.AsValue().AsText());
                if JsonObject.Get('width', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine.Width, JsonToken.AsValue().AsText());
                if JsonObject.Get('height', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointFulfillmentReqLine.Height, JsonToken.AsValue().AsText());
                // Additional identifiers
                if JsonObject.Get('upc', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine.UPC:=JsonToken.AsValue().AsText();
                if JsonObject.Get('mpn', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then FlxPointFulfillmentReqLine.MPN:=JsonToken.AsValue().AsText();
                if FlxPointFulfillmentReqLine.Insert(true)then;
                if FlxPointFulfillmentReqLine.Modify(true)then;
            end;
        end;
    end;
    local procedure LogError(ErrorMessage: Text)
    begin
        Session.LogMessage('FlxPointFulfillment', ErrorMessage, Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
    procedure AcknowledgeFulfillmentRequest(FulfillmentRequestId: Text): Boolean var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        StatusObj: JsonObject;
        StatusName: Text;
    begin
        if not FlxPointSetup.Get('DEFAULT')then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'FlxPoint Setup not found.', true);
            exit(false);
        end;
        if not FlxPointSetup.Enabled then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'FlxPoint integration is not enabled.', true);
            exit(false);
        end;
        // First get the request to check its status
        RequestMessage.Method:='GET';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/fulfillment-requests/' + FulfillmentRequestId);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
        if not Client.Send(RequestMessage, ResponseMessage)then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'Failed to get fulfillment request status.', true);
            exit(false);
        end;
        if not ResponseMessage.IsSuccessStatusCode then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'Failed to get fulfillment request status.', true);
            exit(false);
        end;
        ResponseMessage.Content.ReadAs(ResponseText);
        if not JsonObject.ReadFrom(ResponseText)then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'Failed to parse fulfillment request response.', true);
            exit(false);
        end;
        // Check if already acknowledged
        if JsonObject.Get('fulfillmentRequestStatus', JsonToken)then if JsonToken.IsObject()then begin
                StatusObj:=JsonToken.AsObject();
                if StatusObj.Get('name', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then begin
                            StatusName:=JsonToken.AsValue().AsText();
                            if StatusName = 'Acknowledged' then exit(true); // Already acknowledged, no need to acknowledge again
                        end;
            end;
        // If not acknowledged, proceed with acknowledgment
        Clear(RequestMessage);
        RequestMessage.Method:='PATCH';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/fulfillment-requests/' + FulfillmentRequestId + '/acknowledge');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
        if not Client.Send(RequestMessage, ResponseMessage)then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', 'Failed to send acknowledge request to FlxPoint API.', true);
            exit(false);
        end;
        if not ResponseMessage.IsSuccessStatusCode then begin
            CreateJobQueueLogEntry('FlxPoint Acknowledge Error', StrSubstNo('FlxPoint API returned error: %1. Check event log for details.', ResponseMessage.HttpStatusCode), true);
            exit(false);
        end;
        Session.LogMessage('FlxPointFulfillment', StrSubstNo('Successfully acknowledged fulfillment request %1', FulfillmentRequestId), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        exit(true);
    end;
    local procedure CreateJobQueueLogEntry(Description: Text; ErrorMessage: Text; IsError: Boolean)
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
        JobQueueEntry: Record "Job Queue Entry";
        EntryNo: Integer;
    begin
        // Try to find the current job queue entry
        if JobQueueEntry.FindLast()then;
        JobQueueLogEntry.Init();
        if JobQueueLogEntry.FindLast()then EntryNo:=JobQueueLogEntry."Entry No." + 1
        else
            EntryNo:=1;
        JobQueueLogEntry."Entry No.":=EntryNo;
        JobQueueLogEntry."User ID":=UserId;
        JobQueueLogEntry."Start Date/Time":=CurrentDateTime;
        JobQueueLogEntry."End Date/Time":=CurrentDateTime;
        JobQueueLogEntry.Description:=CopyStr(Description, 1, MaxStrLen(JobQueueLogEntry.Description));
        JobQueueLogEntry."Error Message":=CopyStr(ErrorMessage, 1, MaxStrLen(JobQueueLogEntry."Error Message"));
        JobQueueLogEntry."Object Type to Run":=JobQueueLogEntry."Object Type to Run"::Codeunit;
        JobQueueLogEntry."Object ID to Run":=Codeunit::"FlxPoint Fulfillment";
        if IsError then JobQueueLogEntry.Status:=JobQueueLogEntry.Status::Error
        else
            JobQueueLogEntry.Status:=JobQueueLogEntry.Status::Success;
        JobQueueLogEntry.Insert(true);
        // Also log to session for immediate visibility
        if IsError then Session.LogMessage('FlxPointFulfillment', Description + ': ' + ErrorMessage, Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint')
        else
            Session.LogMessage('FlxPointFulfillment', Description + ': ' + ErrorMessage, Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
}
