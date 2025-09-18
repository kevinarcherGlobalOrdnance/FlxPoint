codeunit 50741 "BigCommerce API"
{
    var BigCommerceSetup: Record "BigCommerce Setup";
    procedure GetProductByUPC(UPC: Text; var Price: Decimal): JsonObject var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        ProductsUrl: Text;
        DataArray: JsonArray;
        ProductJson: JsonToken;
        ProductObject: JsonObject;
    begin
        Price:=0; // Initialize price
        // Get setup
        if not BigCommerceSetup.Get('DEFAULT')then Error('BigCommerce Setup not found.');
        if not BigCommerceSetup.Enabled then Error('BigCommerce integration is not enabled.');
        if(BigCommerceSetup."Store Hash" = '') or (BigCommerceSetup."API Token" = '')then Error('BigCommerce Store Hash and API Token are required.');
        if UPC = '' then Error('UPC cannot be empty.');
        // Build the URL with UPC filter
        ProductsUrl:=BigCommerceSetup.GetAPIBaseURL() + 'products?upc=' + UPC;
        // Create HTTP request
        RequestMessage.Method:='GET';
        RequestMessage.SetRequestUri(ProductsUrl);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Auth-Token', BigCommerceSetup."API Token");
        RequestHeaders.Add('Accept', 'application/json');
        // Send request
        if not Client.Send(RequestMessage, ResponseMessage)then Error('Failed to send request to BigCommerce API.');
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Error('BigCommerce API returned error: %1. Response: %2', ResponseMessage.HttpStatusCode, ResponseText);
        end;
        // Parse response
        ResponseMessage.Content.ReadAs(ResponseText);
        if not JsonObject.ReadFrom(ResponseText)then Error('Failed to parse BigCommerce API response.');
        // Extract price from the first product in the response
        if JsonObject.Get('data', JsonToken)then begin
            if JsonToken.IsArray()then begin
                DataArray:=JsonToken.AsArray();
                if DataArray.Count > 0 then begin
                    if DataArray.Get(0, ProductJson)then begin
                        if ProductJson.IsObject()then begin
                            ProductObject:=ProductJson.AsObject();
                            if ProductObject.Get('price', JsonToken)then if JsonToken.IsValue()then Price:=JsonToken.AsValue().AsDecimal();
                        end;
                    end;
                end;
            end;
        end;
        // Log the API call
        Session.LogMessage('BigCommerce-API', 'GetProductByUPC called for UPC: ' + UPC + ', Price: ' + Format(Price), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'UPC', UPC);
        exit(JsonObject);
    end;
    procedure GetProductDetailsByUPC(UPC: Text; var ProductFound: Boolean; var ProductID: Integer; var ProductName: Text; var ProductSKU: Text; var ProductPrice: Decimal): Boolean var
        ResponseJson: JsonObject;
        DataArray: JsonArray;
        ProductJson: JsonToken;
        ProductObject: JsonObject;
        JsonToken: JsonToken;
    begin
        ProductFound:=false;
        ProductID:=0;
        ProductName:='';
        ProductSKU:='';
        ProductPrice:=0;
        // Get the response from BigCommerce
        ResponseJson:=GetProductByUPC(UPC, ProductPrice);
        // Check if we have data array
        if not ResponseJson.Get('data', JsonToken)then exit(false);
        if not JsonToken.IsArray()then exit(false);
        DataArray:=JsonToken.AsArray();
        // Check if any products were found
        if DataArray.Count = 0 then exit(true); // Successfully called API but no products found
        // Get the first product (should be only one with exact UPC match)
        if DataArray.Get(0, ProductJson)then begin
            if ProductJson.IsObject()then begin
                ProductObject:=ProductJson.AsObject();
                ProductFound:=true;
                // Extract product details
                if ProductObject.Get('id', JsonToken)then if JsonToken.IsValue()then ProductID:=JsonToken.AsValue().AsInteger();
                if ProductObject.Get('name', JsonToken)then if JsonToken.IsValue()then ProductName:=JsonToken.AsValue().AsText();
                if ProductObject.Get('sku', JsonToken)then if JsonToken.IsValue()then ProductSKU:=JsonToken.AsValue().AsText();
                if ProductObject.Get('price', JsonToken)then if JsonToken.IsValue()then ProductPrice:=JsonToken.AsValue().AsDecimal();
                // Log successful retrieval
                Session.LogMessage('BigCommerce-API', 'Product found for UPC: ' + UPC + ', ID: ' + Format(ProductID) + ', Name: ' + ProductName, Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'UPC', UPC, 'ProductID', Format(ProductID));
            end;
        end;
        exit(true);
    end;
    procedure TestGetProductByUPC(UPC: Text): Text var
        ResponseJson: JsonObject;
        ResponseText: Text;
        TempPrice: Decimal;
    begin
        ResponseJson:=GetProductByUPC(UPC, TempPrice);
        ResponseJson.WriteTo(ResponseText);
        exit(ResponseText);
    end;
}
