codeunit 50712 "FlxPoint Create Shipment"
{
    var FlxPointSetup: Record "FlxPoint Setup";
    ErrorMsg: Label 'Error creating shipment: %1', Comment = '%1 = Error message';
    procedure CreateShipment(PurchaseOrderId: Text; TrackingNumber: Text; CarrierCode: Text; ServiceCode: Text; ShipDate: Date)
    var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        ShipmentObject: JsonObject;
        ShipmentItemsArray: JsonArray;
        ShipmentItemObject: JsonObject;
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
        HttpContent: HttpContent;
        JsonText: Text;
        ShipDateTime: DateTime;
        OrderIdInt: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT')then Error('FlxPoint Setup not found.');
        if not FlxPointSetup.Enabled then Error('FlxPoint integration is not enabled.');
        // Convert date to datetime
        ShipDateTime:=CreateDateTime(ShipDate, Time());
        // Convert PurchaseOrderId to Integer (Order ID is stored as Integer)
        Evaluate(OrderIdInt, PurchaseOrderId);
        // Find the fulfillment request by Order ID
        if not FlxPointFulfillmentReq.Get(OrderIdInt)then Error('Fulfillment request not found for Order ID %1.', OrderIdInt);
        // Build shipmentItems array from fulfillment request lines
        Clear(ShipmentItemsArray);
        FlxPointFulfillmentReqLine.SetRange("Request ID", FlxPointFulfillmentReq."Request ID");
        if FlxPointFulfillmentReqLine.FindSet()then repeat Clear(ShipmentItemObject);
                ShipmentItemObject.Add('sku', FlxPointFulfillmentReqLine.SKU);
                ShipmentItemObject.Add('quantity', FlxPointFulfillmentReqLine.Quantity);
                ShipmentItemsArray.Add(ShipmentItemObject);
            until FlxPointFulfillmentReqLine.Next() = 0;
        // Create shipment object
        Clear(ShipmentObject);
        ShipmentObject.Add('trackingNumber', TrackingNumber);
        ShipmentObject.Add('carrier', CarrierCode);
        ShipmentObject.Add('method', ServiceCode);
        ShipmentObject.Add('shipmentItems', ShipmentItemsArray);
        // Optionally add shippedAt if required by API
        // ShipmentObject.Add('shippedAt', Format(ShipDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        // Create the request body
        Clear(JsonObject);
        JsonObject.Add('purchaseOrderId', OrderIdInt);
        JsonObject.Add('shipment', ShipmentObject);
        // Convert to JSON text
        JsonObject.WriteTo(JsonText);
        // Setup request
        Clear(RequestMessage);
        RequestMessage.Method:='POST';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/shipments');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
        // Setup content
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content:=HttpContent;
        // Log the request content for debugging
        Session.LogMessage('FlxPointCreateShipment', 'Sending request with content: ' + JsonText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        if not Client.Send(RequestMessage, ResponseMessage)then Error('Failed to send shipment request to FlxPoint API.');
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Session.LogMessage('FlxPointCreateShipment', StrSubstNo('FlxPoint API returned error: Status: %1, Response: %2, Request Content: %3', ResponseMessage.HttpStatusCode, ResponseText, JsonText), Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        //Error('FlxPoint API returned error: %1. Check event log for details.', ResponseMessage.HttpStatusCode);
        end;
        Session.LogMessage('FlxPointCreateShipment', StrSubstNo('Successfully created shipment for purchase order %1', PurchaseOrderId), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
    procedure CreateShipmentWithItems(PurchaseOrderId: Text; TrackingNumber: Text; CarrierCode: Text; ServiceCode: Text; ShipDate: Date; var ShipmentItems: JsonArray)
    var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        ShipmentObject: JsonObject;
        ShipmentsArray: JsonArray;
        JsonToken: JsonToken;
        HttpContent: HttpContent;
        JsonText: Text;
        ShipDateTime: DateTime;
    begin
        if not FlxPointSetup.Get('DEFAULT')then Error('FlxPoint Setup not found.');
        if not FlxPointSetup.Enabled then Error('FlxPoint integration is not enabled.');
        // Convert date to datetime
        ShipDateTime:=CreateDateTime(ShipDate, Time());
        // Create the request body
        Clear(JsonObject);
        JsonObject.Add('purchaseOrderId', PurchaseOrderId);
        // Create shipment object
        Clear(ShipmentObject);
        ShipmentObject.Add('trackingNumber', TrackingNumber);
        ShipmentObject.Add('carrier', CarrierCode);
        ShipmentObject.Add('method', ServiceCode);
        ShipmentObject.Add('shippedAt', Format(ShipDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        ShipmentObject.Add('shipmentItems', ShipmentItems);
        // Create shipments array and add the shipment
        Clear(ShipmentsArray);
        ShipmentsArray.Add(ShipmentObject);
        // Add shipments array to main object
        JsonObject.Add('shipments', ShipmentsArray);
        // Convert to JSON text
        JsonObject.WriteTo(JsonText);
        // Setup request
        Clear(RequestMessage);
        RequestMessage.Method:='POST';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/shipments');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
        // Setup content
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content:=HttpContent;
        // Log the request content for debugging
        Session.LogMessage('FlxPointCreateShipment', 'Sending request with content: ' + JsonText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        if not Client.Send(RequestMessage, ResponseMessage)then Error('Failed to send shipment request to FlxPoint API.');
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Session.LogMessage('FlxPointCreateShipment', StrSubstNo('FlxPoint API returned error: Status: %1, Response: %2, Request Content: %3', ResponseMessage.HttpStatusCode, ResponseText, JsonText), Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            Error('FlxPoint API returned error: %1. Check event log for details.', ResponseMessage.HttpStatusCode);
        end;
        Session.LogMessage('FlxPointCreateShipment', StrSubstNo('Successfully created shipment for purchase order %1', PurchaseOrderId), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
}
