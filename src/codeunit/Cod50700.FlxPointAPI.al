codeunit 50700 "FlxPoint API"
{
    var Setup: Record "FlxPoint Setup";
    ErrorMsg: Label 'Error calling FlxPoint API: %1', Comment = '%1 = Error message';
    procedure Initialize()
    begin
        if not Setup.Get('DEFAULT')then Error('FlxPoint Setup not found. Please configure the integration first.');
        if not Setup.Enabled then Error('FlxPoint integration is not enabled.');
    end;
    procedure TestConnection(var ResponseText: Text)
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
    begin
        Initialize();
        RequestMessage.SetRequestUri(Setup."API Base URL" + '/inventory/variants');
        RequestMessage.Method('GET');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-API-TOKEN', Setup."API Key");
        if HttpClient.Send(RequestMessage, ResponseMessage)then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            if ResponseMessage.IsSuccessStatusCode()then exit;
            Error(ErrorMsg, ResponseMessage.ReasonPhrase());
        end
        else
            Error(ErrorMsg, GetLastErrorText());
    end;
    procedure CreateUpdateInventory(InventoryData: JsonArray; var ResponseText: Text)
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        HttpContent: HttpContent;
        ContentHeaders: HttpHeaders;
        JsonText: Text;
    begin
        Initialize();
        // Convert JsonArray to Text
        InventoryData.WriteTo(JsonText);
        // Setup request
        RequestMessage.SetRequestUri(Setup."API Base URL" + '/inventory/parents');
        RequestMessage.Method('POST');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-API-TOKEN', Setup."API Key");
        // Setup content
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content(HttpContent);
        // Send request and handle response
        if HttpClient.Send(RequestMessage, ResponseMessage)then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            if ResponseMessage.IsSuccessStatusCode()then exit;
            Error(ErrorMsg, ResponseMessage.ReasonPhrase());
        end
        else
            Error(ErrorMsg, GetLastErrorText());
    end;
    procedure GetOrders(var ResponseText: Text)
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
    begin
        Initialize();
        RequestMessage.SetRequestUri(Setup."API Base URL" + '/api/v2/orders');
        RequestMessage.Method('GET');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-API-TOKEN', Setup."API Key");
        if HttpClient.Send(RequestMessage, ResponseMessage)then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            if ResponseMessage.IsSuccessStatusCode()then exit;
            Error(ErrorMsg, ResponseMessage.ReasonPhrase());
        end
        else
            Error(ErrorMsg, GetLastErrorText());
    end;
    procedure GetProducts(var ResponseText: Text)
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
    begin
        Initialize();
        RequestMessage.SetRequestUri(Setup."API Base URL" + '/api/v2/products');
        RequestMessage.Method('GET');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-API-TOKEN', Setup."API Key");
        if HttpClient.Send(RequestMessage, ResponseMessage)then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            if ResponseMessage.IsSuccessStatusCode()then exit;
            Error(ErrorMsg, ResponseMessage.ReasonPhrase());
        end
        else
            Error(ErrorMsg, GetLastErrorText());
    end;
    procedure GetInventory(var ResponseText: Text)
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
    begin
        Initialize();
        RequestMessage.SetRequestUri(Setup."API Base URL" + '/api/v2/inventory');
        RequestMessage.Method('GET');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-API-TOKEN', Setup."API Key");
        if HttpClient.Send(RequestMessage, ResponseMessage)then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            if ResponseMessage.IsSuccessStatusCode()then exit;
            Error(ErrorMsg, ResponseMessage.ReasonPhrase());
        end
        else
            Error(ErrorMsg, GetLastErrorText());
    end;
}
