/// <summary>
/// FlxPoint Inventory Sync Codeunit
/// This codeunit manages the bidirectional synchronization of inventory data between 
/// Business Central and FlxPoint API. It handles:
/// - Pulling inventory variants from FlxPoint API (inbound sync)
/// - Enriching FlxPoint data with Business Central inventory levels, pricing, and costs
/// - Pushing updated inventory quantities and prices back to FlxPoint (outbound sync)
/// - Integration with BigCommerce API for price retrieval
/// - Special handling for different item categories (firearms, ammunition, magazines, assemblies)
/// </summary>
codeunit 50711 "FlxPoint Inventory Sync"
{
    var CalcBomTree: codeunit "Calculate BOM Tree";
    TempBOMBuffer: Record "BOM Buffer" temporary;
    BigCommerceAPI: Codeunit "BigCommerce API";
    trigger OnRun()
    begin
        Session.LogMessage('FlxPoint-InvSync-0001', 'Inventory Sync Process Started', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'StartProcess');
        SyncInventory();
        UpdateFlxPointInventory();
        Session.LogMessage('FlxPoint-InvSync-0002', 'Inventory Sync Process Completed', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'ProcessCompleted');
    end;
    procedure SyncInventory()
    var
        FlxPointSetup: Record "FlxPoint Setup";
        FlxPointInventory: Record "FlxPoint Inventory";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        Page: Integer;
        PageSize: Integer;
        HasMorePages: Boolean;
        TotalVariantsProcessed: Integer;
        TelemetryDimensions: Dictionary of[Text, Text];
    begin
        Session.LogMessage('FlxPoint-InvSync-0003', 'Inventory Sync Started', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'SyncStarted');
        if not FlxPointSetup.Get('DEFAULT')then begin
            Session.LogMessage('FlxPoint-InvSync-0004', 'Inventory Sync Failed: Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'SetupMissing');
            exit;
        end;
        PageSize:=100; // Adjust page size as needed
        HasMorePages:=true;
        Page:=1;
        TotalVariantsProcessed:=0;
        Session.LogMessage('FlxPoint-InvSync-0005', 'Inventory Sync Parameters Set', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'PageSize', Format(PageSize));
        while HasMorePages do begin
            // Prepare HTTP request for current page
            Clear(RequestMessage);
            RequestMessage.Method := 'GET';
            RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/variants?page=' + Format(Page) + '&pageSize=' + Format(PageSize));
            RequestMessage.GetHeaders(RequestHeaders);
            RequestHeaders.Add('Accept', 'application/json');
            RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");
            // Send request
            if not Client.Send(RequestMessage, ResponseMessage)then begin
                Session.LogMessage('FlxPoint-InvSync-0007', 'Inventory Sync Failed: API Request Failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'PageNumber', Format(Page));
                exit;
            end;
            // Check response
            if not ResponseMessage.IsSuccessStatusCode()then begin
                Clear(TelemetryDimensions);
                TelemetryDimensions.Add('PageNumber', Format(Page));
                TelemetryDimensions.Add('StatusCode', Format(ResponseMessage.HttpStatusCode()));
                Session.LogMessage('FlxPoint-InvSync-0008', 'Inventory Sync Failed: API Error Response', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                exit;
            end;

            // Parse JSON response
            ResponseMessage.Content().ReadAs(ResponseText);
            // Parse response as array
            if not JsonArray.ReadFrom(ResponseText)then begin
                Session.LogMessage('FlxPoint-InvSync-0009', 'Inventory Sync Failed: JSON Parse Error', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'PageNumber', Format(Page));
                exit;
            end;
            if JsonArray.Count = 0 then begin
                Session.LogMessage('FlxPoint-InvSync-0010', 'Inventory Sync Page Empty: Stopping Pagination', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'PageNumber', Format(Page));
                HasMorePages:=false;
                continue;
            end;

            // Process each inventory variant in the current page
            foreach JsonToken in JsonArray do begin
                JsonObject := JsonToken.AsObject();
                ProcessInventoryVariant(JsonObject, FlxPointInventory);
                TotalVariantsProcessed += 1;
            end;

            // Determine if more pages exist
            if JsonArray.Count < PageSize then begin
                Session.LogMessage('FlxPoint-InvSync-0012', 'Inventory Sync Last Page Reached', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'PageNumber', Format(Page), 'VariantCount', Format(JsonArray.Count));
                HasMorePages:=false;
            end
            else
                Page+=1;
        end;
        Session.LogMessage('FlxPoint-InvSync-0013', 'Inventory Sync Completed Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'TotalPages', Format(Page), 'TotalVariants', Format(TotalVariantsProcessed));
    end;
    local procedure ProcessInventoryVariant(JsonObject: JsonObject; var FlxPointInventory: Record "FlxPoint Inventory")
    var
        JsonToken: JsonToken;
        InventoryVariantId: Text;
        InventoryItemId: Text;
        LastModifiedDate: DateTime;
        WeightUnitObj: JsonObject;
        DimensionUnitObj: JsonObject;
        ItemReference: Record "Item Reference";
        Item: Record Item;
        BinContents: Record "Bin Content";
        TotalAvailiable: Decimal;
        TotalAvailiableBase: Decimal;
        PriceListLine: Record "Price List Line";
        QtyOnSalesOrder: Decimal;
        TotalOnPick: Decimal;
        UOMMgt: codeunit "Unit of Measure Management";
        FlxPointSetup: Record "FlxPoint Setup";
        IsNewRecord: Boolean;
        TelemetryDimensions: Dictionary of[Text, Text];
        // BigCommerce API variables
        BigCommercePrice: Decimal;
    begin
        FlxPointSetup.Get('DEFAULT');
        // Get required fields
        if not JsonObject.Get('id', JsonToken)then begin
            Clear(TelemetryDimensions);
            Session.LogMessage('FlxPoint-InvSync-0014', 'Inventory Variant Processing Failed: Missing ID', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit;
        end;
        InventoryVariantId:=JsonToken.AsValue().AsText();
        if JsonObject.Get('inventoryItemId', JsonToken)then if not JsonToken.AsValue().IsNull()then InventoryItemId:=JsonToken.AsValue().AsText();
        if JsonObject.Get('lastModifiedDate', JsonToken)then if not JsonToken.AsValue().IsNull()then Evaluate(LastModifiedDate, JsonToken.AsValue().AsText());
        // Check if record exists
        IsNewRecord:=not FlxPointInventory.Get(InventoryVariantId);
        if IsNewRecord then begin
            FlxPointInventory.Init();
            FlxPointInventory."Inventory Variant ID" := InventoryVariantId;
            FlxPointInventory.Insert(true);
            TelemetryDimensions.Set('VariantId', InventoryVariantId);
            Session.LogMessage('FlxPoint-InvSync-0015', 'New Inventory Variant Created', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end
        else
        begin
            TelemetryDimensions.Set('VariantId', InventoryVariantId);
            Session.LogMessage('FlxPoint-InvSync-0016', 'Existing Inventory Variant Updated', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end;
        // Basic fields
        if JsonObject.Get('sku', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.SKU:=JsonToken.AsValue().AsText();
        if JsonObject.Get('title', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Title:=JsonToken.AsValue().AsText();
        if JsonObject.Get('itemReferenceId', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Item Reference ID":=JsonToken.AsValue().AsText();
        if JsonObject.Get('upc', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.UPC:=JsonToken.AsValue().AsText();
        if JsonObject.Get('mpn', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.MPN:=JsonToken.AsValue().AsText();
        // Additional identifiers
        if JsonObject.Get('masterSku', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Master SKU":=JsonToken.AsValue().AsText();
        if JsonObject.Get('ean', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.EAN:=JsonToken.AsValue().AsText();
        if JsonObject.Get('asin', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.ASIN:=JsonToken.AsValue().AsText();
        // Quantities
        if JsonObject.Get('quantity', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Quantity:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('totalQuantity', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Total Quantity":=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('committedQuantity', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Committed Quantity":=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('incomingQuantity', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Incoming Quantity":=JsonToken.AsValue().AsDecimal();
        // Pricing
        if JsonObject.Get('cost', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Cost:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('inventoryListPrice', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Inventory List Price":=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('msrp', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.MSRP:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('map', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.MAP:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('shippingCost', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Shipping Cost":=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('dropshipFee', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Dropship Fee":=JsonToken.AsValue().AsDecimal();
        // Dimensions
        if JsonObject.Get('weight', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Weight:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('length', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Length:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('width', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Width:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('height', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Height:=JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('dimensionalWeight', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Dimensional Weight":=JsonToken.AsValue().AsDecimal();
        // Units
        if JsonObject.Get('weightUnit', JsonToken)then if JsonToken.IsObject()then begin
                WeightUnitObj:=JsonToken.AsObject();
                if WeightUnitObj.Get('handle', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Weight Unit":=JsonToken.AsValue().AsText();
            end;
        if JsonObject.Get('dimensionUnit', JsonToken) then
            if JsonToken.IsObject() then begin
                DimensionUnitObj := JsonToken.AsObject();
                if DimensionUnitObj.Get('handle', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Dimension Unit" := JsonToken.AsValue().AsText();
            end;
        // Status fields
        if JsonObject.Get('requiresFfl', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Requires FFL":=JsonToken.AsValue().AsBoolean();
        if JsonObject.Get('allowBackorders', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Allow Backorders":=JsonToken.AsValue().AsBoolean();
        if JsonObject.Get('archived', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Archived:=JsonToken.AsValue().AsBoolean();
        // Additional fields
        if JsonObject.Get('description', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory.Description:=JsonToken.AsValue().AsText();
        if JsonObject.Get('binLocation', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Bin Location":=JsonToken.AsValue().AsText();
        if JsonObject.Get('sourceId', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Source ID":=Format(JsonToken.AsValue().AsInteger());
        if JsonObject.Get('inventoryParentId', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Inventory Parent ID":=Format(JsonToken.AsValue().AsInteger());
        if JsonObject.Get('supplierVariantId', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Supplier Variant ID":=JsonToken.AsValue().AsText();
        if JsonObject.Get('referenceIdentifier', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Reference Identifier":=JsonToken.AsValue().AsText();
        if JsonObject.Get('accountId', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Account ID":=Format(JsonToken.AsValue().AsInteger());
        // Dates
        FlxPointInventory."Last Modified Date":=LastModifiedDate;
        FlxPointInventory."Last Sync Date":=CurrentDateTime;
        if JsonObject.Get('insertedAt', JsonToken)then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointInventory."Inserted At", JsonToken.AsValue().AsText());
        if JsonObject.Get('updatedAt', JsonToken)then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointInventory."Updated At", JsonToken.AsValue().AsText());
        if JsonObject.Get('totalQuantityLastChangedAt', JsonToken)then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointInventory."Total Quantity Last Changed At", JsonToken.AsValue().AsText());
        if JsonObject.Get('contentUpdatedAt', JsonToken)then if not JsonToken.AsValue().IsNull()then Evaluate(FlxPointInventory."Content Updated At", JsonToken.AsValue().AsText());
        FlxPointInventory."Inventory Item ID":=InventoryItemId;
        if JsonObject.Get('inventoryItemTitle', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Inventory Item Title":=JsonToken.AsValue().AsText();
        if JsonObject.Get('inventoryItemSku', JsonToken)then if not JsonToken.AsValue().IsNull()then FlxPointInventory."Inventory Item SKU":=JsonToken.AsValue().AsText();
        // Call BigCommerce API to get product price by UPC
        if FlxPointInventory.UPC <> '' then begin
            Clear(BigCommercePrice);
            if TryGetBigCommercePrice(FlxPointInventory.UPC, BigCommercePrice) then begin
                if BigCommercePrice > 0 then begin
                    FlxPointInventory."BigCommerce Price":=BigCommercePrice;
                    TelemetryDimensions.Set('UPC', FlxPointInventory.UPC);
                    TelemetryDimensions.Set('BigCommercePrice', Format(BigCommercePrice));
                    Session.LogMessage('FlxPoint-InvSync-BigCommerce', 'BigCommerce price retrieved for UPC', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                end
                else
                begin
                    TelemetryDimensions.Set('UPC', FlxPointInventory.UPC);
                    Session.LogMessage('FlxPoint-InvSync-BigCommerce', 'No BigCommerce price found for UPC', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                end;
            end
            else
            begin
                // BigCommerce API call failed, but don't stop the sync process
                TelemetryDimensions.Set('UPC', FlxPointInventory.UPC);
                TelemetryDimensions.Set('Error', GetLastErrorText());
                Session.LogMessage('FlxPoint-InvSync-BigCommerce', 'BigCommerce API call failed for UPC', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                CreateJobQueueLogEntry('BigCommerce API Error', StrSubstNo('Failed to retrieve BigCommerce price for UPC %1: %2', FlxPointInventory.UPC, GetLastErrorText()), true);
            end;
        end;

        // ============================================================
        // BUSINESS CENTRAL ITEM MATCHING & ENRICHMENT
        // ============================================================
        // Match FlxPoint variant to Business Central item using UPC barcode
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        ItemReference.SetRange("Reference No.", FlxPointInventory.UPC);
        if ItemReference.FindFirst()then begin
            FlxPointInventory."Business Central Item No.":=ItemReference."Item No.";
            FlxPointInventory."Business Central UOM":=ItemReference."Unit of Measure";
            TelemetryDimensions.Set('VariantId', InventoryVariantId);
            TelemetryDimensions.Set('ItemNo', ItemReference."Item No.");
            Session.LogMessage('FlxPoint-InvSync-0017', 'Item Reference Found for Variant', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end
        else
        begin
            TelemetryDimensions.Set('VariantId', InventoryVariantId);
            TelemetryDimensions.Set('UPC', FlxPointInventory.UPC);
            Session.LogMessage('FlxPoint-InvSync-0018', 'Item Reference Not Found for Variant', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end;
        IF Item.Get(FlxPointInventory."Business Central Item No.")then begin
            If FlxPointInventory."Business Central UOM" = Item."Base Unit of Measure" then FlxPointInventory."Business Central Cost":=Item."Unit Cost"
            else
                FlxPointInventory."Business Central Cost":=Item."Unit Cost" * UOMMgt.GetQtyPerUnitOfMeasure(Item, FlxPointInventory."Business Central UOM");
            FlxPointInventory.MAP:=Item.MAP2;
            PriceListLine.Setrange(PriceListLine."Price List Code", FlxPointSetup."Price List Code");
            PriceListLine.Setrange("Item Reference", ItemReference."Reference No.");
            If PriceListLine.FindFirst()then FlxPointInventory."Business Central Price":=PriceListLine."Unit Price";
            If Item."Assembly BOM" then FlxPointInventory."Business Central QOH":=CalcAssemblyAvail(Item."No.")
            else
            begin
                IF(Item."Item Category Code" = 'AMMUNITION') OR (Item."Item Category Code" = 'MAGAZINES')then FlxPointInventory."Business Central QOH":=CalcAmmunitionAvail(Item."No.", FlxPointInventory."Business Central UOM")
                else
                    FlxPointInventory."Business Central QOH":=CalcInventory(Item."No.", FlxPointInventory."Business Central UOM");
            end;
            If FlxPointInventory."Business Central Price" = 0 then FlxPointInventory."Business Central QOH":=0;
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('VariantId', InventoryVariantId);
            TelemetryDimensions.Add('ItemNo', Item."No.");
            TelemetryDimensions.Add('QOH', Format(FlxPointInventory."Business Central QOH"));
            TelemetryDimensions.Add('Price', Format(FlxPointInventory."Business Central Price"));
            Session.LogMessage('FlxPoint-InvSync-0019', 'Business Central Data Calculated for Variant', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end;
        if FlxPointInventory.Modify(true)then;
    end;
    local procedure CalcInventory(ItemNo: code[20]; UnitofMeasureCode: code[10]): Decimal var
        BinContents: record "Bin Content";
        TotalAvailiable: Decimal;
        TotalAvailiableBase: Decimal;
        TotalOnPick: Decimal;
        TotalOnPickBase: Decimal;
        ItemRec: Record Item;
        NotPicked: Decimal;
        QtyOnSalesOrder: Decimal;
        UomMgmt: Codeunit "Unit of Measure Management";
    begin
        // Get item and calculate sales order demand
        ItemRec.Get(ItemNo);
        ItemRec.CalcFields("Qty. on Sales Order");
        IF ItemRec."Base Unit of Measure" = UnitofMeasureCode then QtyOnSalesOrder:=ItemRec."Qty. on Sales Order"
        else
            QtyOnSalesOrder:=(ItemRec."Qty. on Sales Order" / UomMgmt.GetQtyPerUnitOfMeasure(ItemRec, UnitofMeasureCode));
        BinContents.SETRANGE("Item No.", ItemNo);
        BinContents.SETFILTER("Zone Code", '%1|%2', 'MAIN', 'SHIPPING');
        BinContents.SetRange("Unit of Measure Code", UnitofMeasureCode);
        BinContents.CalcFields("Pick Qty.");

        // Special handling: Firearms must be 'NEW' variant only
        If ItemRec."Item Category Code" = 'FIREARMS' THen BinContents.SetRange("Variant Code", 'NEW');
        If BinContents.FindSet()then repeat TotalAvailiable+=BinContents.CalcQtyAvailToTakeUOM();
                TotalOnPick+=BinContents."Pick Qty.";
            until BinContents.Next() = 0;
        IF(ItemRec."Item Category Code" = 'AMMUNITION') OR (ItemRec."Item Category Code" = 'MAGAZINES')then if UnitofMeasureCode <> ItemRec."Base Unit of Measure" then begin
                BinContents.SETRANGE("Unit of Measure Code", itemrec."Base Unit of Measure");
                If BinContents.FindSet() then
                    repeat
                        TotalAvailiableBase += BinContents.CalcQtyAvailToTakeUOM();
                        TotalOnPickBase += BinContents."Pick Qty.";
                    until BinContents.Next() = 0;
                // Convert base UOM to requested UOM and add to total
                If TotalAvailiableBase > 0 then begin
                    TotalAvailiable += ROUND(TotalAvailiableBase / UomMgmt.GetQtyPerUnitOfMeasure(ItemRec, UnitofMeasureCode), 1, '=');
                end;
                //TotalAvailiable := TotalAvailiable + TotalAvailiableBase;
                TotalOnPick:=TotalOnPick + TotalOnPickBase;
            end;
        NotPicked:=(QtyOnSalesOrder - TotalOnPick);
        If(TotalAvailiable - NotPicked) > 0 then exit(TotalAvailiable - NotPicked)
        else
            exit(0);
    end;
    local procedure CalcAmmunitionAvail(ItemNo: code[20]; UnitofMeasureCode: code[10]): Decimal var
        BinContents: record "Bin Content";
        TotalAvailiable: Decimal;
        TotalAvailiableUOM: Decimal;
        ItemRec: Record Item;
        QtyOnSalesOrder: Decimal;
        UomMgmt: Codeunit "Unit of Measure Management";
        TotalOnPickBase: Decimal;
        NotPicked: Decimal;
    begin
        // Get item and sales order demand (in base UOM)
        ItemRec.Get(ItemNo);
        ItemRec.CalcFields("Qty. on Sales Order");
        QtyOnSalesOrder:=ItemRec."Qty. on Sales Order";
        BinContents.SETRANGE("Item No.", ItemNo);
        BinContents.SETFILTER("Zone Code", '%1|%2', 'MAIN', 'SHIPPING');
        BinContents.CalcFields("Pick Qty.");
        If BinContents.FindSet()then repeat TotalAvailiable+=BinContents.CalcQtyAvailToTake(0);
                TotalOnPickBase+=BinContents."Pick Qty.";
            until BinContents.Next() = 0;
        TotalAvailiable:=TotalAvailiable - (qtyonsalesorder - TotalOnPickBase);
        IF TotalAvailiable > 0 then begin
            TotalAvailiableUOM := ROUND(TotalAvailiable / UomMgmt.GetQtyPerUnitOfMeasure(ItemRec, UnitofMeasureCode), 1, '=');
        end;

        Exit(TotalAvailiableUOM);
    end;
    local procedure CalcAssemblyAvail(ItemNo: Code[20]): Decimal var
        ItemRec: record Item;
        AbleToMakeQty: Decimal;
    begin
        // Generate BOM tree to calculate component availability
        CalcBOMTree.SetShowTotalAvailability(true);
        If ItemRec.Get(ItemNo) then begin
            Itemrec.CalcFields(Inventory, "Qty. on Sales Order");

            // Build BOM tree and get "able to make" quantity
            CalcBOMTree.GenerateTreeForItem(ItemRec, TempBOMBuffer, Today, 1);
            IF TempBOMBuffer.FindFirst()then AbleToMakeQty:=TempBOMBuffer."Able to Make Top Item";
            EXIT(AbleToMakeQty + ItemRec.Inventory - ItemRec."Qty. on Sales Order");
        end;
    end;
    procedure UpdateFlxPointInventory()
    var
        FlxPointInventory: Record "FlxPoint Inventory";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonArray: JsonArray;
        TempJsonArray: JsonArray;
        JsonToken: JsonToken;
        FlxPointSetup: Record "FlxPoint Setup";
        CustomFieldsArray: JsonArray;
        CustomFieldObject: JsonObject;
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        FileName: Text;
        BatchCount: Integer;
        MaxBatchSize: Integer;
        TotalVariants: Integer;
        UpdatedVariants: Integer;
    begin
        if not FlxPointSetup.Get('DEFAULT')then exit;
        MaxBatchSize:=50; // API limit is 50 variants per request
        BatchCount:=0;
        TotalVariants:=0;
        UpdatedVariants:=0;
        Session.LogMessage('FlxPointInventorySync', 'Starting inventory sync process', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        //FlxPointInventory.SetFilter("Business Central QOH", '<>0');
        // FlxPointInventory.SetRange(FlxPointInventory."Inventory Variant ID", '23584674878');
        if FlxPointInventory.FindSet()then begin
            Clear(JsonArray);
            repeat TotalVariants+=1;
                // Only include variants that have changes in QOH or price
                if(FlxPointInventory."Business Central QOH" <> FlxPointInventory.Quantity) or (FlxPointInventory."Business Central Price" <> FlxPointInventory.MSRP) or (FlxPointInventory."Inventory List Price" <> FlxPointInventory."Business Central Price")then begin
                    // Log the changes for this variant
                    Session.LogMessage('FlxPointInventorySync', StrSubstNo('Updating variant - SKU: %1, Old QOH: %2, New QOH: %3, Old Price: %4, New Price: %5', FlxPointInventory.SKU, FlxPointInventory.Quantity, FlxPointInventory."Business Central QOH", FlxPointInventory.MSRP, FlxPointInventory."Business Central Price"), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
                    Clear(JsonObject);
                    JsonObject.Add('inventoryVariantId', FlxPointInventory."Inventory Variant ID");
                    JsonObject.Add('sku', FlxPointInventory.SKU);

                    // Check if item is FlxPoint enabled - if not, send 0 quantity to hide from marketplace
                    FlxPointInventory.CalcFields("FlxPoint Enabled");
                    if FlxPointInventory."FlxPoint Enabled" then
                        JsonObject.Add('quantity', FlxPointInventory."Business Central QOH") else
                        JsonObject.Add('quantity', 0);

                    // Add cost if available
                    if FlxPointInventory."Business Central Cost" > 0 then JsonObject.Add('cost', FlxPointInventory."Business Central Cost");

                    // Add pricing and inventory settings
                    JsonObject.Add('allowBackorders', FlxPointInventory."Allow Backorders");
                    JsonObject.Add('inventoryListPrice', FlxPointInventory."Business Central Price");
                    JsonObject.Add('msrp', FlxPointInventory."Business Central Price");
                    JsonObject.Add('map', FlxPointInventory."Business Central Map");

                    // Add custom field for Business Central price (for external systems)
                    Clear(CustomFieldsArray);
                    Clear(CustomFieldObject);
                    CustomFieldObject.Add('name', 'GOPRICE');
                    CustomFieldObject.Add('value', Format(FlxPointInventory."Business Central Price"));
                    CustomFieldsArray.Add(CustomFieldObject);
                    JsonObject.Add('customFields', CustomFieldsArray);

                    // Add to batch array
                    JsonArray.Add(JsonObject);
                    BatchCount+=1;
                    UpdatedVariants+=1;
                    // If we've reached the batch size, send the request
                    if BatchCount >= MaxBatchSize then begin
                        //SendBatchRequest(JsonArray, FlxPointSetup);
                        Clear(JsonArray);
                        BatchCount := 0;
                    end;
                end;
            until FlxPointInventory.Next() = 0;

            // Send final batch if any variants remain
            if JsonArray.Count > 0 then SendBatchRequest(JsonArray, FlxPointSetup);
        end;
    end;
    local procedure SendBatchRequest(var JsonArray: JsonArray; FlxPointSetup: Record "FlxPoint Setup")
    var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        FileName: Text;
        JsonText: Text;
        HttpContent: HttpContent;
    begin
        // Convert JSON array to text
        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStr);
        JsonArray.WriteTo(JsonText);

        // Prepare HTTP PUT request
        Clear(RequestMessage);
        RequestMessage.Method := 'PUT';
        RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/variants');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");

        // Setup JSON content with proper content-type header
        HttpContent.WriteFrom(JsonText);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.Content:=HttpContent;
        // Log the request content for debugging
        Session.LogMessage('FlxPointInventorySync', 'Sending request with content: ' + JsonText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
        if not Client.Send(RequestMessage, ResponseMessage)then begin
            Session.LogMessage('FlxPointInventorySync', 'Failed to send update request to FlxPoint API', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit;
        end;
        if not ResponseMessage.IsSuccessStatusCode()then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            Session.LogMessage('FlxPointInventorySync', StrSubstNo('FlxPoint API returned error: Status: %1, Response: %2, Request Content: %3', ResponseMessage.HttpStatusCode(), ResponseText, JsonText), Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit;
        end;
    end;
    local procedure TryGetBigCommercePrice(UPC: Text; var Price: Decimal): Boolean var
        JsonObject: JsonObject;
    begin
        Clear(Price);
        JsonObject := BigCommerceAPI.GetProductByUPC(UPC, Price);
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
        JobQueueLogEntry."Object ID to Run":=Codeunit::"FlxPoint Inventory Sync";
        if IsError then JobQueueLogEntry.Status:=JobQueueLogEntry.Status::Error
        else
            JobQueueLogEntry.Status:=JobQueueLogEntry.Status::Success;
        JobQueueLogEntry.Insert(true);
        // Also log to session for immediate visibility
        if IsError then Session.LogMessage('FlxPointInventorySync', Description + ': ' + ErrorMessage, Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint')
        else
            Session.LogMessage('FlxPointInventorySync', Description + ': ' + ErrorMessage, Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;
}
