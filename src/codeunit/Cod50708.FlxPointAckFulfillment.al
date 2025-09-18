codeunit 50708 "FlxPoint Ack Fulfillment"
{
    var FlxPointSetup: Record "FlxPoint Setup";
    FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
    ErrorMsg: Label 'Error acknowledging fulfillment request: %1', Comment = '%1 = Error message';
    trigger OnRun()
    begin
        ProcessFulfillmentRequests();
    end;
    procedure ProcessFulfillmentRequests()
    var
        TotalProcessed: Integer;
        ErrorCount: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT')then Error('FlxPoint Setup not found.');
        if not FlxPointSetup.Enabled then Error('FlxPoint integration is not enabled.');
        TotalProcessed:=0;
        ErrorCount:=0;
        // Get all fulfillment requests with sales orders
        FlxPointFulfillmentReq.SetFilter("Sales Order No.", '<>%1', '');
        if FlxPointFulfillmentReq.FindSet()then repeat if AcknowledgeFulfillmentRequest(Format(FlxPointFulfillmentReq."Request ID"))then TotalProcessed+=1
                else
                    ErrorCount+=1;
            until FlxPointFulfillmentReq.Next() = 0;
        if ErrorCount > 0 then Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Processed %1 fulfillment requests with %2 errors', TotalProcessed, ErrorCount), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
    local procedure AcknowledgeFulfillmentRequest(FulfillmentRequestId: Text): Boolean var
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
        // First get the request to check its status
        RequestMessage.Method:='GET';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/fulfillment-requests/' + FulfillmentRequestId);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
        if not Client.Send(RequestMessage, ResponseMessage)then begin
            Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Failed to get fulfillment request %1 status', FulfillmentRequestId), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Failed to get fulfillment request %1 status. Status: %2, Response: %3', FulfillmentRequestId, ResponseMessage.HttpStatusCode, ResponseText), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;
        ResponseMessage.Content.ReadAs(ResponseText);
        if not JsonObject.ReadFrom(ResponseText)then begin
            Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Failed to parse fulfillment request %1 response', FulfillmentRequestId), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;
        if JsonObject.Get('fulfillmentRequestStatus', JsonToken)then if JsonToken.IsObject()then begin
                StatusObj:=JsonToken.AsObject();
                if StatusObj.Get('name', JsonToken)then if JsonToken.IsValue()then if not JsonToken.AsValue().IsNull()then begin
                            StatusName:=JsonToken.AsValue().AsText();
                            if StatusName = 'Acknowledged' then begin
                                Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Fulfillment request %1 already acknowledged', FulfillmentRequestId), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                                exit;
                            end;
                            if StatusName <> 'Processing' then begin
                                Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Fulfillment request %1 not in Processing status (current status: %2)', FulfillmentRequestId, StatusName), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                                exit;
                            end;
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
            Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Failed to acknowledge fulfillment request %1', FulfillmentRequestId), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Failed to acknowledge fulfillment request %1. Status: %2, Response: %3', FulfillmentRequestId, ResponseMessage.HttpStatusCode, ResponseText), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit(false);
        end;
        Session.LogMessage('FlxPointAcknowledge', StrSubstNo('Successfully acknowledged fulfillment request %1', FulfillmentRequestId), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        exit(true);
    end;
}
