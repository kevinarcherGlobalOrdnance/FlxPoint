codeunit 50741 "BigCommerce API"
{
    var
        BigCommerceSetup: Record "BigCommerce Setup";

    /// <summary>
    /// Fetches orders from BigCommerce and populates the BigCommerce Order Line table with order products.
    /// Uses Management API v2: GET /orders and GET /orders/{id}/products.
    /// </summary>
    /// <param name="MinOrderDate">Only include orders created on or after this date. Use 0D for no filter.</param>
    /// <param name="MaxOrders">Maximum number of orders to process. Use 0 for no limit (fetch all).</param>
    procedure FetchOrderLinesToTable(MinOrderDate: Date; MaxOrders: Integer)
    var
        BCOrderLine: Record "BigCommerce Order Line";
        OrdersJson: JsonArray;
        OrderToken: JsonToken;
        OrderObject: JsonObject;
        OrderIdToken: JsonToken;
        OrderId: Integer;
        DateCreatedText: Text;
        OrderDate: Date;
        Processed: Integer;
    begin
        EnsureSetup();
        BCOrderLine.DeleteAll();
        OrdersJson := GetOrdersFromAPI(MinOrderDate, MaxOrders);
        Processed := 0;
        foreach OrderToken in OrdersJson do begin
            if not OrderToken.IsObject() then
                continue;
            OrderObject := OrderToken.AsObject();
            if not OrderObject.Get('id', OrderIdToken) or not OrderIdToken.IsValue() then
                continue;
            OrderId := OrderIdToken.AsValue().AsInteger();
            OrderDate := 0D;
            if OrderObject.Get('date_created', OrderIdToken) and OrderIdToken.IsValue() then
                OrderDate := ParseDateCreatedFromAPI(OrderIdToken.AsValue().AsText());
            ImportOrderProducts(OrderId, OrderDate);
            Processed += 1;
        end;
        Session.LogMessage('BigCommerce-API', StrSubstNo('FetchOrderLinesToTable completed. Processed %1 orders.', Processed), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Count', Format(Processed));
    end;

    procedure GetProductByUPC(UPC: Text; var Price: Decimal): JsonObject
    var
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
        Price := 0; // Initialize price
        // Get setup
        if not BigCommerceSetup.Get('DEFAULT') then Error('BigCommerce Setup not found.');
        if not BigCommerceSetup.Enabled then Error('BigCommerce integration is not enabled.');
        if (BigCommerceSetup."Store Hash" = '') or (BigCommerceSetup."API Token" = '') then Error('BigCommerce Store Hash and API Token are required.');
        if UPC = '' then Error('UPC cannot be empty.');
        // Build the URL with UPC filter
        ProductsUrl := BigCommerceSetup.GetAPIBaseURL() + 'products?upc=' + UPC;
        // Create HTTP request
        RequestMessage.Method := 'GET';
        RequestMessage.SetRequestUri(ProductsUrl);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Auth-Token', BigCommerceSetup."API Token");
        RequestHeaders.Add('Accept', 'application/json');
        // Send request
        if not Client.Send(RequestMessage, ResponseMessage) then Error('Failed to send request to BigCommerce API.');
        if not ResponseMessage.IsSuccessStatusCode then begin
            ResponseMessage.Content.ReadAs(ResponseText);
            Error('BigCommerce API returned error: %1. Response: %2', ResponseMessage.HttpStatusCode, ResponseText);
        end;
        // Parse response
        ResponseMessage.Content.ReadAs(ResponseText);
        if not JsonObject.ReadFrom(ResponseText) then Error('Failed to parse BigCommerce API response.');
        // Extract price from the first product in the response
        if JsonObject.Get('data', JsonToken) then begin
            if JsonToken.IsArray() then begin
                DataArray := JsonToken.AsArray();
                if DataArray.Count > 0 then begin
                    if DataArray.Get(0, ProductJson) then begin
                        if ProductJson.IsObject() then begin
                            ProductObject := ProductJson.AsObject();
                            if ProductObject.Get('price', JsonToken) then if JsonToken.IsValue() then Price := JsonToken.AsValue().AsDecimal();
                        end;
                    end;
                end;
            end;
        end;
        // Log the API call
        Session.LogMessage('BigCommerce-API', 'GetProductByUPC called for UPC: ' + UPC + ', Price: ' + Format(Price), Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'UPC', UPC);
        exit(JsonObject);
    end;

    procedure GetProductDetailsByUPC(UPC: Text; var ProductFound: Boolean; var ProductID: Integer; var ProductName: Text; var ProductSKU: Text; var ProductPrice: Decimal): Boolean
    var
        ResponseJson: JsonObject;
        DataArray: JsonArray;
        ProductJson: JsonToken;
        ProductObject: JsonObject;
        JsonToken: JsonToken;
    begin
        ProductFound := false;
        ProductID := 0;
        ProductName := '';
        ProductSKU := '';
        ProductPrice := 0;
        // Get the response from BigCommerce
        ResponseJson := GetProductByUPC(UPC, ProductPrice);
        // Check if we have data array
        if not ResponseJson.Get('data', JsonToken) then exit(false);
        if not JsonToken.IsArray() then exit(false);
        DataArray := JsonToken.AsArray();
        // Check if any products were found
        if DataArray.Count = 0 then exit(true); // Successfully called API but no products found
        // Get the first product (should be only one with exact UPC match)
        if DataArray.Get(0, ProductJson) then begin
            if ProductJson.IsObject() then begin
                ProductObject := ProductJson.AsObject();
                ProductFound := true;
                // Extract product details
                if ProductObject.Get('id', JsonToken) then if JsonToken.IsValue() then ProductID := JsonToken.AsValue().AsInteger();
                if ProductObject.Get('name', JsonToken) then if JsonToken.IsValue() then ProductName := JsonToken.AsValue().AsText();
                if ProductObject.Get('sku', JsonToken) then if JsonToken.IsValue() then ProductSKU := JsonToken.AsValue().AsText();
                if ProductObject.Get('price', JsonToken) then if JsonToken.IsValue() then ProductPrice := JsonToken.AsValue().AsDecimal();
                // Log successful retrieval
                Session.LogMessage('BigCommerce-API', 'Product found for UPC: ' + UPC + ', ID: ' + Format(ProductID) + ', Name: ' + ProductName, Verbosity::Normal, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'UPC', UPC, 'ProductID', Format(ProductID));
            end;
        end;
        exit(true);
    end;

    procedure TestGetProductByUPC(UPC: Text): Text
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
        TempPrice: Decimal;
    begin
        ResponseJson := GetProductByUPC(UPC, TempPrice);
        ResponseJson.WriteTo(ResponseText);
        exit(ResponseText);
    end;

    local procedure EnsureSetup()
    begin
        if not BigCommerceSetup.Get('DEFAULT') then
            Error('BigCommerce Setup not found.');
        if not BigCommerceSetup.Enabled then
            Error('BigCommerce integration is not enabled.');
        if (BigCommerceSetup."Store Hash" = '') or (BigCommerceSetup."API Token" = '') then
            Error('BigCommerce Store Hash and API Token are required.');
    end;

    local procedure GetOrdersFromAPI(MinOrderDate: Date; Limit: Integer): JsonArray
    var
        ResultArray: JsonArray;
        PageArray: JsonArray;
        MinDateISO: Text;
        Page: Integer;
        PageSize: Integer;
        OrderToken: JsonToken;
    begin
        PageSize := 250; // BigCommerce max per page
        Page := 1;
        repeat
            PageArray := GetOrdersSinglePage(MinOrderDate, Page, PageSize);
            foreach OrderToken in PageArray do begin
                if (Limit > 0) and (ResultArray.Count >= Limit) then
                    break;
                ResultArray.Add(OrderToken);
            end;
            Page += 1;
        until (PageArray.Count < PageSize) or ((Limit > 0) and (ResultArray.Count >= Limit));
        exit(ResultArray);
    end;

    /// <summary>
    /// Parses BigCommerce date_created (ISO-8601 e.g. 2017-01-10T06:54:07Z) to a Date. Returns 0D if invalid.
    /// </summary>
    local procedure ParseDateCreatedFromAPI(DateCreatedText: Text): Date
    var
        Y: Integer;
        M: Integer;
        D: Integer;
    begin
        if (DateCreatedText = '') or (StrLen(DateCreatedText) < 10) then
            exit(0D);
        // ISO-8601: YYYY-MM-DD (first 10 chars)
        if not Evaluate(Y, CopyStr(DateCreatedText, 1, 4)) then
            exit(0D);
        if not Evaluate(M, CopyStr(DateCreatedText, 6, 2)) then
            exit(0D);
        if not Evaluate(D, CopyStr(DateCreatedText, 9, 2)) then
            exit(0D);
        if (Y < 2000) or (Y > 2100) or (M < 1) or (M > 12) or (D < 1) or (D > 31) then
            exit(0D);
        exit(DMY2Date(D, M, Y));
    end;

    local procedure GetOrdersSinglePage(MinOrderDate: Date; Page: Integer; PageSize: Integer): JsonArray
    var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        OrdersUrl: Text;
        MinDateISO: Text;
    begin
        OrdersUrl := BigCommerceSetup.GetOrdersAPIBaseURL() + 'orders?limit=' + Format(PageSize) + '&page=' + Format(Page);
        if TryFormatDateAsISO8601(MinOrderDate, MinDateISO) then
            OrdersUrl := OrdersUrl + '&min_date_created=' + MinDateISO;
        RequestMessage.Method := 'GET';
        RequestMessage.SetRequestUri(OrdersUrl);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Auth-Token', BigCommerceSetup."API Token");
        RequestHeaders.Add('Accept', 'application/json');
        if not Client.Send(RequestMessage, ResponseMessage) then
            Error('Failed to send request to BigCommerce Orders API.');
        ResponseMessage.Content.ReadAs(ResponseText);
        if not ResponseMessage.IsSuccessStatusCode then
            Error('BigCommerce Orders API error: %1. %2', ResponseMessage.HttpStatusCode, ResponseText);
        exit(GetOrdersPageArrayFromResponse(ResponseText));
    end;

    /// <summary>
    /// Formats a Date as ISO-8601 (YYYY-MM-DD) only when the date is valid (non-blank, day 1-31, month 1-12).
    /// Returns false for 0D or invalid dates so the caller can skip sending the value to the API.
    /// </summary>
    local procedure TryFormatDateAsISO8601(Value: Date; var IsoDate: Text): Boolean
    var
        Y: Integer;
        M: Integer;
        D: Integer;
    begin
        if Value = 0D then
            exit(false);
        D := Date2DMY(Value, 1);
        M := Date2DMY(Value, 2);
        Y := Date2DMY(Value, 3);
        if (D < 1) or (D > 31) or (M < 1) or (M > 12) or (Y < 2000) or (Y > 2100) then
            exit(false);
        IsoDate := StrSubstNo('%1-%2-%3', Y, PadStr(Format(M), 2, '0'), PadStr(Format(D), 2, '0'));
        exit(true);
    end;

    local procedure GetOrdersPageArrayFromResponse(ResponseText: Text): JsonArray
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        ResultArray: JsonArray;
    begin
        if ResultArray.ReadFrom(ResponseText) then
            exit(ResultArray);
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('data', JsonToken) and JsonToken.IsArray() then
                exit(JsonToken.AsArray());
            if JsonObject.Get('orders', JsonToken) and JsonToken.IsArray() then
                exit(JsonToken.AsArray());
        end;
        exit(ResultArray);
    end;

    local procedure ImportOrderProducts(OrderId: Integer; OrderDate: Date)
    var
        BCOrderLine: Record "BigCommerce Order Line";
        ProductsJson: JsonArray;
        ProductToken: JsonToken;
        ProductObject: JsonObject;
        JsonToken: JsonToken;
        OrderProductId: Integer;
        ProductId: Integer;
        LineName: Text;
        LineSKU: Text;
        LineType: Text;
        Qty: Decimal;
        BasePrice: Decimal;
        PriceExTax: Decimal;
        PriceIncTax: Decimal;
        TotalExTax: Decimal;
        TotalIncTax: Decimal;
        BCItemNo: Code[20];
        Page: Integer;
        PageSize: Integer;
    begin
        PageSize := 250; // BigCommerce max per page for order products
        Page := 1;
        repeat
            ProductsJson := GetOrderProductsSinglePage(OrderId, Page, PageSize);
            foreach ProductToken in ProductsJson do begin
                if not ProductToken.IsObject() then
                    continue;
                ProductObject := ProductToken.AsObject();
                OrderProductId := 0;
                ProductId := 0;
                LineName := '';
                LineSKU := '';
                LineType := '';
                Qty := 0;
                BasePrice := 0;
                PriceExTax := 0;
                PriceIncTax := 0;
                TotalExTax := 0;
                TotalIncTax := 0;
                if ProductObject.Get('id', JsonToken) and JsonToken.IsValue() then OrderProductId := JsonToken.AsValue().AsInteger();
                if ProductObject.Get('product_id', JsonToken) and JsonToken.IsValue() then ProductId := JsonToken.AsValue().AsInteger();
                if ProductObject.Get('name', JsonToken) and JsonToken.IsValue() then LineName := CopyStr(JsonToken.AsValue().AsText(), 1, MaxStrLen(BCOrderLine.Name));
                if ProductObject.Get('sku', JsonToken) and JsonToken.IsValue() then LineSKU := CopyStr(JsonToken.AsValue().AsText(), 1, MaxStrLen(BCOrderLine.SKU));
                if ProductObject.Get('type', JsonToken) and JsonToken.IsValue() then LineType := CopyStr(JsonToken.AsValue().AsText(), 1, 30);
                if ProductObject.Get('quantity', JsonToken) and JsonToken.IsValue() then Qty := JsonToken.AsValue().AsDecimal();
                if ProductObject.Get('base_price', JsonToken) and JsonToken.IsValue() then BasePrice := JsonToken.AsValue().AsDecimal();
                if ProductObject.Get('price_ex_tax', JsonToken) and JsonToken.IsValue() then PriceExTax := JsonToken.AsValue().AsDecimal();
                if ProductObject.Get('price_inc_tax', JsonToken) and JsonToken.IsValue() then PriceIncTax := JsonToken.AsValue().AsDecimal();
                if ProductObject.Get('total_ex_tax', JsonToken) and JsonToken.IsValue() then TotalExTax := JsonToken.AsValue().AsDecimal();
                if ProductObject.Get('total_inc_tax', JsonToken) and JsonToken.IsValue() then TotalIncTax := JsonToken.AsValue().AsDecimal();
                BCItemNo := ResolveBCItemNoFromSKU(LineSKU);
                BCOrderLine.Reset();
                BCOrderLine.SetRange("Order ID", OrderId);
                BCOrderLine.SetRange("Order Product ID", OrderProductId);
                if BCOrderLine.FindFirst() then begin
                    BCOrderLine."Order Date" := OrderDate;
                    BCOrderLine.Name := LineName;
                    BCOrderLine.SKU := LineSKU;
                    BCOrderLine."Product Type" := LineType;
                    BCOrderLine.Quantity := Qty;
                    BCOrderLine."Base Price" := BasePrice;
                    BCOrderLine."Price Excl. Tax" := PriceExTax;
                    BCOrderLine."Price Incl. Tax" := PriceIncTax;
                    BCOrderLine."Total Excl. Tax" := TotalExTax;
                    BCOrderLine."Total Incl. Tax" := TotalIncTax;
                    BCOrderLine."BC Item No." := BCItemNo;
                    BCOrderLine."Last Fetched At" := CurrentDateTime();
                    BCOrderLine.Modify(true);
                end else begin
                    Clear(BCOrderLine);
                    BCOrderLine.Init();
                    BCOrderLine."Order ID" := OrderId;
                    BCOrderLine."Order Date" := OrderDate;
                    BCOrderLine."Order Product ID" := OrderProductId;
                    BCOrderLine."Product ID" := ProductId;
                    BCOrderLine.Name := LineName;
                    BCOrderLine.SKU := LineSKU;
                    BCOrderLine."Product Type" := LineType;
                    BCOrderLine.Quantity := Qty;
                    BCOrderLine."Base Price" := BasePrice;
                    BCOrderLine."Price Excl. Tax" := PriceExTax;
                    BCOrderLine."Price Incl. Tax" := PriceIncTax;
                    BCOrderLine."Total Excl. Tax" := TotalExTax;
                    BCOrderLine."Total Incl. Tax" := TotalIncTax;
                    BCOrderLine."BC Item No." := BCItemNo;
                    BCOrderLine."Last Fetched At" := CurrentDateTime();
                    BCOrderLine.Insert(true);
                end;
            end;
            Page += 1;
        until ProductsJson.Count < PageSize;
    end;

    local procedure GetOrderProductsSinglePage(OrderId: Integer; Page: Integer; PageSize: Integer): JsonArray
    var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        ProductsUrl: Text;
    begin
        ProductsUrl := BigCommerceSetup.GetOrdersAPIBaseURL() + 'orders/' + Format(OrderId) + '/products?limit=' + Format(PageSize) + '&page=' + Format(Page);
        RequestMessage.Method := 'GET';
        RequestMessage.SetRequestUri(ProductsUrl);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Auth-Token', BigCommerceSetup."API Token");
        RequestHeaders.Add('Accept', 'application/json');
        if not Client.Send(RequestMessage, ResponseMessage) then
            exit(GetOrderProductsPageArrayFromResponse('[]'));
        if not ResponseMessage.IsSuccessStatusCode then
            exit(GetOrderProductsPageArrayFromResponse('[]'));
        ResponseMessage.Content.ReadAs(ResponseText);
        exit(GetOrderProductsPageArrayFromResponse(ResponseText));
    end;

    local procedure GetOrderProductsPageArrayFromResponse(ResponseText: Text): JsonArray
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        ResultArray: JsonArray;
    begin
        if ResultArray.ReadFrom(ResponseText) then
            exit(ResultArray);
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('data', JsonToken) and JsonToken.IsArray() then
                exit(JsonToken.AsArray());
            if JsonObject.Get('products', JsonToken) and JsonToken.IsArray() then
                exit(JsonToken.AsArray());
        end;
        exit(ResultArray);
    end;

    /// <summary>
    /// Looks up Item Reference by Reference Type = Bar Code: first by Reference No. = SKU, then by GTIN = SKU if no match.
    /// Returns the Item No. if found; otherwise returns blank.
    /// </summary>
    local procedure ResolveBCItemNoFromSKU(SKU: Text): Code[20]
    var
        ItemReference: Record "Item Reference";
        SKUCode: Code[50];
    begin
        if SKU = '' then
            exit('');
        SKUCode := CopyStr(SKU, 1, MaxStrLen(ItemReference."Reference No."));
        ItemReference.Reset();
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        ItemReference.SetRange("Reference No.", SKUCode);
        if ItemReference.FindFirst() then
            exit(ItemReference."Item No.");
        ItemReference.Reset();
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        ItemReference.SetRange(GTIN, CopyStr(SKU, 1, MaxStrLen(ItemReference.GTIN)));
        if ItemReference.FindFirst() then
            exit(ItemReference."Item No.");
        exit('');
    end;
}
