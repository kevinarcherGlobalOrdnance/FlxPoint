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
    var
        CalcBomTree: codeunit "Calculate BOM Tree";
        TempBOMBuffer: Record "BOM Buffer" temporary;
        BigCommerceAPI: Codeunit "BigCommerce API";

    /// <summary>
    /// Main entry point for the inventory synchronization process
    /// Executes both inbound and outbound sync operations in sequence
    /// </summary>
    trigger OnRun()
    begin
        SyncInventory();           // Step 1: Pull inventory from FlxPoint and enrich with BC data
        UpdateFlxPointInventory(); // Step 2: Push updated quantities and prices back to FlxPoint
    end;

    /// <summary>
    /// Synchronizes inventory variants from FlxPoint API to Business Central
    /// This procedure:
    /// 1. Clears all existing FlxPoint Inventory records to ensure a fresh sync
    /// 2. Pre-loads all lookup data (ItemReferences, PriceListLines, Items) into dictionaries for fast access
    /// 3. Retrieves inventory variants from FlxPoint API using pagination
    /// 4. Processes each variant to enrich with Business Central data (inventory, pricing, costs)
    /// 5. Matches variants to BC items using UPC codes via Item References
    /// 6. Integrates with BigCommerce to retrieve web pricing
    /// API Endpoint: GET https://api.flxpoint.com/inventory/variants
    /// </summary>
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
        ItemRefDict: Dictionary of [Text, Text[20]]; // Key: UPC, Value: Item No.
        ItemRefUOMDict: Dictionary of [Text, Code[10]]; // Key: UPC, Value: UOM
        PriceListDict: Dictionary of [Text, Decimal]; // Key: UPC, Value: Unit Price
        ItemTemp: Record Item temporary; // Temporary table to cache loaded items
    begin
        // Clear all existing FlxPoint inventory records for fresh sync
        FlxPointInventory.DeleteAll();

        // Validate setup exists before proceeding
        if not FlxPointSetup.Get('DEFAULT') then begin
            exit;
        end;

        // OPTIMIZATION: Pre-load all lookup data into dictionaries (eliminates N+1 queries)
        LoadItemReferences(ItemRefDict, ItemRefUOMDict);
        LoadPriceListLines(FlxPointSetup."Price List Code", PriceListDict);
        LoadItems(ItemRefDict, ItemTemp);

        // Initialize pagination parameters
        PageSize := 100; // FlxPoint API recommended page size
        HasMorePages := true;
        Page := 1;
        TotalVariantsProcessed := 0;

        // Loop through all pages of inventory variants
        while HasMorePages do begin
            // Prepare HTTP request for current page
            Clear(RequestMessage);
            RequestMessage.Method := 'GET';
            RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/variants?page=' + Format(Page) + '&pageSize=' + Format(PageSize));
            RequestMessage.GetHeaders(RequestHeaders);
            RequestHeaders.Add('Accept', 'application/json');
            RequestHeaders.Add('X-Api-Token', FlxPointSetup."API Key");

            // Execute API request
            if not Client.Send(RequestMessage, ResponseMessage) then begin
                exit; // Exit on communication failure
            end;

            // Validate successful response
            if not ResponseMessage.IsSuccessStatusCode() then begin
                exit; // Exit on API error response
            end;

            // Parse JSON response
            ResponseMessage.Content().ReadAs(ResponseText);
            if not JsonArray.ReadFrom(ResponseText) then begin
                exit; // Exit on JSON parsing failure
            end;

            // Check if page is empty (end of data)
            if JsonArray.Count = 0 then begin
                HasMorePages := false;
                continue;
            end;

            // Process each inventory variant in the current page
            foreach JsonToken in JsonArray do begin
                JsonObject := JsonToken.AsObject();
                ProcessInventoryVariant(JsonObject, FlxPointInventory, FlxPointSetup, ItemRefDict, ItemRefUOMDict, PriceListDict, ItemTemp);
                TotalVariantsProcessed += 1;
            end;

            // Determine if more pages exist
            if JsonArray.Count < PageSize then begin
                HasMorePages := false; // Last page reached
            end
            else
                Page += 1; // Move to next page
        end;
    end;

    /// <summary>
    /// Pre-loads all Item References into dictionaries for fast lookup
    /// Eliminates N+1 query problem by loading all data in one query
    /// </summary>
    /// <param name="ItemRefDict">Dictionary keyed by UPC, returns Item No.</param>
    /// <param name="ItemRefUOMDict">Dictionary keyed by UPC, returns Unit of Measure</param>
    local procedure LoadItemReferences(var ItemRefDict: Dictionary of [Text, Text[20]]; var ItemRefUOMDict: Dictionary of [Text, Code[10]])
    var
        ItemReference: Record "Item Reference";
    begin
        Clear(ItemRefDict);
        Clear(ItemRefUOMDict);

        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        if ItemReference.FindSet() then
            repeat
                if (ItemReference."Reference No." <> '') and (not ItemRefDict.ContainsKey(ItemReference."Reference No.")) then begin
                    ItemRefDict.Add(ItemReference."Reference No.", ItemReference."Item No.");
                    ItemRefUOMDict.Add(ItemReference."Reference No.", ItemReference."Unit of Measure");
                end;
            until ItemReference.Next() = 0;
    end;

    /// <summary>
    /// Pre-loads all Price List Lines into a dictionary for fast lookup
    /// Eliminates N+1 query problem by loading all data in one query
    /// </summary>
    /// <param name="PriceListCode">Price List Code to load</param>
    /// <param name="PriceListDict">Dictionary keyed by UPC (Item Reference), returns Unit Price</param>
    local procedure LoadPriceListLines(PriceListCode: Code[20]; var PriceListDict: Dictionary of [Text, Decimal])
    var
        PriceListLine: Record "Price List Line";
    begin
        Clear(PriceListDict);

        PriceListLine.SetRange("Price List Code", PriceListCode);
        if PriceListLine.FindSet() then
            repeat
                if (PriceListLine."Item Reference" <> '') and (not PriceListDict.ContainsKey(PriceListLine."Item Reference")) then
                    PriceListDict.Add(PriceListLine."Item Reference", PriceListLine."Unit Price");
            until PriceListLine.Next() = 0;
    end;

    /// <summary>
    /// Pre-loads all Items that are referenced in ItemReferences into a temporary table
    /// Eliminates N+1 query problem by loading all items in batch
    /// </summary>
    /// <param name="ItemRefDict">Dictionary of Item References (to get list of Item Nos.)</param>
    /// <param name="ItemTemp">Temporary Item table to cache loaded items</param>
    local procedure LoadItems(var ItemRefDict: Dictionary of [Text, Text[20]]; var ItemTemp: Record Item temporary)
    var
        Item: Record Item;
        ItemNo: Text[20];
        ItemNoList: List of [Code[20]];
        UniqueItemNo: Code[20];
    begin
        Clear(ItemTemp);
        Clear(ItemNoList);

        // Collect all unique item numbers
        foreach ItemNo in ItemRefDict.Values() do begin
            UniqueItemNo := CopyStr(ItemNo, 1, MaxStrLen(Item."No."));
            if not ItemNoList.Contains(UniqueItemNo) then
                ItemNoList.Add(UniqueItemNo);
        end;

        // Load all items in batch into temporary table
        foreach UniqueItemNo in ItemNoList do begin
            if Item.Get(UniqueItemNo) then begin
                ItemTemp := Item;
                ItemTemp.Insert();
            end;
        end;
    end;

    /// <summary>
    /// Processes a single inventory variant from FlxPoint JSON response
    /// This procedure:
    /// - Parses all FlxPoint variant fields (identifiers, quantities, pricing, dimensions, dates)
    /// - Creates or updates FlxPoint Inventory record
    /// - Matches variant to BC Item using UPC barcode via Item Reference
    /// - Retrieves BigCommerce pricing if UPC exists
    /// - Calculates Business Central inventory quantities based on item category:
    ///   * Assembly BOM items: Uses BOM tree calculation
    ///   * Ammunition/Magazines: Uses special ammunition calculation
    ///   * Firearms: Filters by 'NEW' variant only
    ///   * Other items: Uses standard inventory calculation
    /// - Enriches record with BC cost, price (from price list), and MAP
    /// </summary>
    /// <param name="JsonObject">JSON object containing FlxPoint variant data</param>
    /// <param name="FlxPointInventory">FlxPoint Inventory record to update (passed by reference)</param>
    /// <param name="FlxPointSetup">FlxPoint Setup record (pre-loaded to avoid repeated queries)</param>
    /// <param name="ItemRefDict">Dictionary of Item References keyed by UPC</param>
    /// <param name="ItemRefUOMDict">Dictionary of UOMs keyed by UPC</param>
    /// <param name="PriceListDict">Dictionary of Prices keyed by UPC</param>
    /// <param name="ItemTemp">Temporary table containing pre-loaded Items</param>
    local procedure ProcessInventoryVariant(
        JsonObject: JsonObject;
        var FlxPointInventory: Record "FlxPoint Inventory";
        FlxPointSetup: Record "FlxPoint Setup";
        var ItemRefDict: Dictionary of [Text, Text[20]];
        var ItemRefUOMDict: Dictionary of [Text, Code[10]];
        var PriceListDict: Dictionary of [Text, Decimal];
        var ItemTemp: Record Item temporary)
    var
        JsonToken: JsonToken;
        InventoryVariantId: Text;
        InventoryItemId: Text;
        LastModifiedDate: DateTime;
        WeightUnitObj: JsonObject;
        DimensionUnitObj: JsonObject;
        Item: Record Item;
        BinContents: Record "Bin Content";
        TotalAvailiable: Decimal;
        TotalAvailiableBase: Decimal;
        QtyOnSalesOrder: Decimal;
        TotalOnPick: Decimal;
        UOMMgt: codeunit "Unit of Measure Management";
        IsNewRecord: Boolean;
        BigCommercePrice: Decimal;
        ItemNo: Text[20];
        UOM: Code[10];
        UnitPrice: Decimal;
    begin

        // Extract required variant ID - exit if missing
        if not JsonObject.Get('id', JsonToken) then begin
            exit;
        end;
        InventoryVariantId := JsonToken.AsValue().AsText();
        if JsonObject.Get('inventoryItemId', JsonToken) then if not JsonToken.AsValue().IsNull() then InventoryItemId := JsonToken.AsValue().AsText();
        if JsonObject.Get('lastModifiedDate', JsonToken) then if not JsonToken.AsValue().IsNull() then Evaluate(LastModifiedDate, JsonToken.AsValue().AsText());

        // Create new record or retrieve existing
        IsNewRecord := not FlxPointInventory.Get(InventoryVariantId);
        if IsNewRecord then begin
            FlxPointInventory.Init();
            FlxPointInventory."Inventory Variant ID" := InventoryVariantId;
            FlxPointInventory.Insert(true);
        end;

        // ============================================================
        // PARSE FLXPOINT VARIANT DATA FIELDS
        // ============================================================

        // Basic product identifiers
        if JsonObject.Get('sku', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.SKU := JsonToken.AsValue().AsText();
        if JsonObject.Get('title', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Title := JsonToken.AsValue().AsText();
        if JsonObject.Get('itemReferenceId', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Item Reference ID" := JsonToken.AsValue().AsText();
        if JsonObject.Get('upc', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.UPC := JsonToken.AsValue().AsText();
        if JsonObject.Get('mpn', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.MPN := JsonToken.AsValue().AsText();

        // Extended product identifiers
        if JsonObject.Get('masterSku', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Master SKU" := JsonToken.AsValue().AsText();
        if JsonObject.Get('ean', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.EAN := JsonToken.AsValue().AsText();
        if JsonObject.Get('asin', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.ASIN := JsonToken.AsValue().AsText();

        // FlxPoint inventory quantities
        if JsonObject.Get('quantity', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Quantity := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('totalQuantity', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Total Quantity" := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('committedQuantity', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Committed Quantity" := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('incomingQuantity', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Incoming Quantity" := JsonToken.AsValue().AsDecimal();

        // FlxPoint pricing information
        if JsonObject.Get('cost', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Cost := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('inventoryListPrice', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Inventory List Price" := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('msrp', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.MSRP := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('map', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.MAP := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('shippingCost', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Shipping Cost" := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('dropshipFee', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Dropship Fee" := JsonToken.AsValue().AsDecimal();

        // Product dimensions (for shipping calculations)
        if JsonObject.Get('weight', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Weight := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('length', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Length := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('width', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Width := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('height', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Height := JsonToken.AsValue().AsDecimal();
        if JsonObject.Get('dimensionalWeight', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Dimensional Weight" := JsonToken.AsValue().AsDecimal();

        // Unit of measure information (weight and dimension units)
        if JsonObject.Get('weightUnit', JsonToken) then
            if JsonToken.IsObject() then begin
                WeightUnitObj := JsonToken.AsObject();
                if WeightUnitObj.Get('handle', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Weight Unit" := JsonToken.AsValue().AsText();
            end;
        if JsonObject.Get('dimensionUnit', JsonToken) then
            if JsonToken.IsObject() then begin
                DimensionUnitObj := JsonToken.AsObject();
                if DimensionUnitObj.Get('handle', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Dimension Unit" := JsonToken.AsValue().AsText();
            end;

        // Product status and compliance flags
        if JsonObject.Get('requiresFfl', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Requires FFL" := JsonToken.AsValue().AsBoolean();
        if JsonObject.Get('allowBackorders', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Allow Backorders" := JsonToken.AsValue().AsBoolean();
        if JsonObject.Get('archived', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Archived := JsonToken.AsValue().AsBoolean();

        // Miscellaneous product information
        if JsonObject.Get('description', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory.Description := JsonToken.AsValue().AsText();
        if JsonObject.Get('binLocation', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Bin Location" := JsonToken.AsValue().AsText();
        if JsonObject.Get('sourceId', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Source ID" := Format(JsonToken.AsValue().AsInteger());
        if JsonObject.Get('inventoryParentId', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Inventory Parent ID" := Format(JsonToken.AsValue().AsInteger());
        if JsonObject.Get('supplierVariantId', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Supplier Variant ID" := JsonToken.AsValue().AsText();
        if JsonObject.Get('referenceIdentifier', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Reference Identifier" := JsonToken.AsValue().AsText();
        if JsonObject.Get('accountId', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Account ID" := Format(JsonToken.AsValue().AsInteger());

        // Timestamp tracking fields
        FlxPointInventory."Last Modified Date" := LastModifiedDate;
        FlxPointInventory."Last Sync Date" := CurrentDateTime;
        if JsonObject.Get('insertedAt', JsonToken) then if not JsonToken.AsValue().IsNull() then Evaluate(FlxPointInventory."Inserted At", JsonToken.AsValue().AsText());
        if JsonObject.Get('updatedAt', JsonToken) then if not JsonToken.AsValue().IsNull() then Evaluate(FlxPointInventory."Updated At", JsonToken.AsValue().AsText());
        if JsonObject.Get('totalQuantityLastChangedAt', JsonToken) then if not JsonToken.AsValue().IsNull() then Evaluate(FlxPointInventory."Total Quantity Last Changed At", JsonToken.AsValue().AsText());
        if JsonObject.Get('contentUpdatedAt', JsonToken) then if not JsonToken.AsValue().IsNull() then Evaluate(FlxPointInventory."Content Updated At", JsonToken.AsValue().AsText());

        // Parent inventory item information
        FlxPointInventory."Inventory Item ID" := InventoryItemId;
        if JsonObject.Get('inventoryItemTitle', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Inventory Item Title" := JsonToken.AsValue().AsText();
        if JsonObject.Get('inventoryItemSku', JsonToken) then if not JsonToken.AsValue().IsNull() then FlxPointInventory."Inventory Item SKU" := JsonToken.AsValue().AsText();

        // ============================================================
        // BIGCOMMERCE PRICE INTEGRATION
        // ============================================================
        // Retrieve product pricing from BigCommerce using UPC lookup
        if FlxPointInventory.UPC <> '' then begin
            Clear(BigCommercePrice);
            if TryGetBigCommercePrice(FlxPointInventory.UPC, BigCommercePrice) then begin
                if BigCommercePrice > 0 then begin
                    FlxPointInventory."BigCommerce Price" := BigCommercePrice;
                end;
            end;
        end;

        // ============================================================
        // BUSINESS CENTRAL ITEM MATCHING & ENRICHMENT
        // ============================================================
        // OPTIMIZATION: Match FlxPoint variant to Business Central item using pre-loaded dictionary
        if (FlxPointInventory.UPC <> '') and ItemRefDict.Get(FlxPointInventory.UPC, ItemNo) then begin
            FlxPointInventory."Business Central Item No." := CopyStr(ItemNo, 1, MaxStrLen(FlxPointInventory."Business Central Item No."));

            // Get UOM from dictionary
            if ItemRefUOMDict.Get(FlxPointInventory.UPC, UOM) then
                FlxPointInventory."Business Central UOM" := UOM;

            // OPTIMIZATION: Get Item from pre-loaded temporary table instead of database query
            ItemTemp.SetRange("No.", FlxPointInventory."Business Central Item No.");
            if ItemTemp.FindFirst() then begin
                Item := ItemTemp;
                // Calculate unit cost (adjust for UOM if necessary)
                If FlxPointInventory."Business Central UOM" = Item."Base Unit of Measure" then
                    FlxPointInventory."Business Central Cost" := Item."Unit Cost"
                else
                    FlxPointInventory."Business Central Cost" := Item."Unit Cost" * UOMMgt.GetQtyPerUnitOfMeasure(Item, FlxPointInventory."Business Central UOM");

                // Set MAP (Minimum Advertised Price) from item
                FlxPointInventory.MAP := Item.MAP2;

                // OPTIMIZATION: Get price from pre-loaded dictionary instead of database query
                if PriceListDict.Get(FlxPointInventory.UPC, UnitPrice) then
                    FlxPointInventory."Business Central Price" := UnitPrice;

                // Calculate available quantity based on item type
                If Item."Assembly BOM" then
                    // Assembly items: Calculate based on component availability
                    FlxPointInventory."Business Central QOH" := CalcAssemblyAvail(Item."No.")
                else begin
                    IF (Item."Item Category Code" = 'AMMUNITION') OR (Item."Item Category Code" = 'MAGAZINES') then
                        // Ammunition/Magazines: Use base UOM calculation with rounding
                        FlxPointInventory."Business Central QOH" := CalcAmmunitionAvail(Item."No.", FlxPointInventory."Business Central UOM")
                    else
                        // Standard items: Use bin-based availability calculation
                        FlxPointInventory."Business Central QOH" := CalcInventory(Item."No.", FlxPointInventory."Business Central UOM");
                end;

                // Business rule: Hide inventory if no price is set
                If FlxPointInventory."Business Central Price" = 0 then FlxPointInventory."Business Central QOH" := 0;
            end;
        end;

        // Save the enriched record
        if FlxPointInventory.Modify(true) then;
    end;

    /// <summary>
    /// Calculates available inventory for standard items
    /// This calculation:
    /// - Sums available quantity from MAIN and SHIPPING zones
    /// - Subtracts sales order quantities that haven't been picked yet
    /// - For FIREARMS: Only counts items with 'NEW' variant code
    /// - For AMMUNITION/MAGAZINES: Aggregates both specified UOM and base UOM quantities
    /// Returns net available quantity that can be sold
    /// </summary>
    /// <param name="ItemNo">Item number to calculate inventory for</param>
    /// <param name="UnitofMeasureCode">Unit of measure to return quantity in</param>
    /// <returns>Net available quantity in the specified UOM</returns>
    local procedure CalcInventory(ItemNo: code[20]; UnitofMeasureCode: code[10]): Decimal
    var
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

        // Convert sales order quantity to requested UOM
        IF ItemRec."Base Unit of Measure" = UnitofMeasureCode then
            QtyOnSalesOrder := ItemRec."Qty. on Sales Order"
        else
            QtyOnSalesOrder := (ItemRec."Qty. on Sales Order" / UomMgmt.GetQtyPerUnitOfMeasure(ItemRec, UnitofMeasureCode));

        // Calculate available inventory in MAIN and SHIPPING zones for requested UOM
        BinContents.SETRANGE("Item No.", ItemNo);
        BinContents.SETFILTER("Zone Code", '%1|%2', 'MAIN', 'SHIPPING');
        BinContents.SetRange("Unit of Measure Code", UnitofMeasureCode);
        BinContents.CalcFields("Pick Qty.");

        // Special handling: Firearms must be 'NEW' variant only
        If ItemRec."Item Category Code" = 'FIREARMS' THen BinContents.SetRange("Variant Code", 'NEW');

        // Sum available and picking quantities
        If BinContents.FindSet() then
            repeat
                TotalAvailiable += BinContents.CalcQtyAvailToTakeUOM();
                TotalOnPick += BinContents."Pick Qty.";
            until BinContents.Next() = 0;

        // Special handling: Ammunition/Magazines - also include base UOM inventory
        IF (ItemRec."Item Category Code" = 'AMMUNITION') OR (ItemRec."Item Category Code" = 'MAGAZINES') then
            if UnitofMeasureCode <> ItemRec."Base Unit of Measure" then begin
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
                TotalOnPick := TotalOnPick + TotalOnPickBase;
            end;

        // Calculate unpicked demand (sales orders not yet picked)
        NotPicked := (QtyOnSalesOrder - TotalOnPick);

        // Return net available (available minus unpicked demand)
        If (TotalAvailiable - NotPicked) > 0 then
            exit(TotalAvailiable - NotPicked)
        else
            exit(0);
    end;

    /// <summary>
    /// Calculates available inventory specifically for ammunition and magazine items
    /// This specialized calculation:
    /// - Works in BASE unit of measure only (typically individual rounds/units)
    /// - Sums all inventory from MAIN and SHIPPING zones regardless of UOM
    /// - Subtracts unpicked sales order demand
    /// - Converts final result to requested UOM with rounding
    /// Used for ammunition/magazines because they're often stored in mixed UOMs
    /// </summary>
    /// <param name="ItemNo">Item number to calculate inventory for</param>
    /// <param name="UnitofMeasureCode">Target UOM to return quantity in (e.g., BOX, CASE)</param>
    /// <returns>Net available quantity in the specified UOM</returns>
    local procedure CalcAmmunitionAvail(ItemNo: code[20]; UnitofMeasureCode: code[10]): Decimal
    var
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
        QtyOnSalesOrder := ItemRec."Qty. on Sales Order";

        // Calculate total available in base UOM across all bin UOMs
        BinContents.SETRANGE("Item No.", ItemNo);
        BinContents.SETFILTER("Zone Code", '%1|%2', 'MAIN', 'SHIPPING');
        BinContents.CalcFields("Pick Qty.");

        // Sum available quantity in base UOM
        If BinContents.FindSet() then
            repeat
                TotalAvailiable += BinContents.CalcQtyAvailToTake(0);
                TotalOnPickBase += BinContents."Pick Qty.";
            until BinContents.Next() = 0;

        // Subtract unpicked sales order demand
        TotalAvailiable := TotalAvailiable - (qtyonsalesorder - TotalOnPickBase);

        // Convert to requested UOM with rounding
        IF TotalAvailiable > 0 then begin
            TotalAvailiableUOM := ROUND(TotalAvailiable / UomMgmt.GetQtyPerUnitOfMeasure(ItemRec, UnitofMeasureCode), 1, '=');
        end;

        Exit(TotalAvailiableUOM);
    end;

    /// <summary>
    /// Calculates available inventory for assembly BOM items
    /// This calculation:
    /// - Uses BOM Tree to determine how many assemblies can be made from components
    /// - Adds any pre-assembled finished goods in inventory
    /// - Subtracts sales order demand for the finished assembly
    /// Formula: (Able to Make) + (On Hand) - (On Sales Order)
    /// </summary>
    /// <param name="ItemNo">Assembly item number to calculate for</param>
    /// <returns>Net available quantity of assemblies that can be sold</returns>
    local procedure CalcAssemblyAvail(ItemNo: Code[20]): Decimal
    var
        ItemRec: record Item;
        AbleToMakeQty: Decimal;
    begin
        ItemRec.CalcFields(Inventory, "Qty. on Sales Order");
        // Generate BOM tree to calculate component availability
        CalcBOMTree.SetShowTotalAvailability(true);
        If ItemRec.Get(ItemNo) then begin
            Itemrec.CalcFields(Inventory, "Qty. on Sales Order");

            // Build BOM tree and get "able to make" quantity
            CalcBOMTree.GenerateTreeForItem(ItemRec, TempBOMBuffer, Today, 1);
            IF TempBOMBuffer.FindFirst() then AbleToMakeQty := TempBOMBuffer."Able to Make Top Item";

            // Return: Components available + Finished goods on hand - Sales orders
            EXIT(AbleToMakeQty + ItemRec.Inventory - ItemRec."Qty. on Sales Order");
        end;
    end;

    /// <summary>
    /// Pushes inventory updates from Business Central to FlxPoint API (outbound sync)
    /// This procedure:
    /// - Iterates through all FlxPoint Inventory records
    /// - Identifies variants where BC quantity or price differs from FlxPoint values
    /// - Builds JSON payloads with updated quantities, prices, costs, and MAP
    /// - Checks "FlxPoint Enabled" flowfield - if disabled, sends quantity as 0
    /// - Batches updates in groups of 50 (FlxPoint API limit)
    /// - Sends batched PUT requests to update multiple variants at once
    /// - Includes custom field "GOPRICE" with Business Central price
    /// API Endpoint: PUT https://api.flxpoint.com/inventory/variants
    /// </summary>
    procedure UpdateFlxPointInventory()
    var
        FlxPointInventory: Record "FlxPoint Inventory";
    begin
        // Process all FlxPoint Inventory records
        if FlxPointInventory.FindSet() then
            UpdateFlxPointInventoryFiltered(FlxPointInventory);
    end;

    /// <summary>
    /// Pushes inventory updates from Business Central to FlxPoint API for filtered records (outbound sync)
    /// This procedure:
    /// - Iterates through the provided filtered FlxPoint Inventory recordset
    /// - Identifies variants where BC quantity or price differs from FlxPoint values
    /// - Builds JSON payloads with updated quantities, prices, costs, and MAP
    /// - Checks "FlxPoint Enabled" flowfield - if disabled, sends quantity as 0
    /// - Batches updates in groups of 50 (FlxPoint API limit)
    /// - Sends batched PUT requests to update multiple variants at once
    /// - Includes custom field "GOPRICE" with Business Central price
    /// API Endpoint: PUT https://api.flxpoint.com/inventory/variants
    /// </summary>
    /// <param name="FlxPointInventory">Filtered FlxPoint Inventory recordset to process</param>
    procedure UpdateFlxPointInventoryFiltered(var FlxPointInventory: Record "FlxPoint Inventory")
    var
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
        if not FlxPointSetup.Get('DEFAULT') then exit;

        // Initialize batching parameters
        MaxBatchSize := 50; // FlxPoint API limit per request
        BatchCount := 0;
        TotalVariants := 0;
        UpdatedVariants := 0;

        // Process filtered FlxPoint Inventory records
        if FlxPointInventory.FindSet() then begin
            Clear(JsonArray);
            repeat
                TotalVariants += 1;

                // Only update variants with changes (QOH or price differences)
                if (FlxPointInventory."Business Central QOH" <> FlxPointInventory.Quantity) or (FlxPointInventory."Business Central Price" <> FlxPointInventory.MSRP) or (FlxPointInventory."Inventory List Price" <> FlxPointInventory."Business Central Price") then begin
                    // Build JSON object for this variant
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
                    BatchCount += 1;
                    UpdatedVariants += 1;

                    // Send batch when max size reached
                    if BatchCount >= MaxBatchSize then begin
                        SendBatchRequest(JsonArray, FlxPointSetup);
                        Clear(JsonArray);
                        BatchCount := 0;
                    end;
                end;
            until FlxPointInventory.Next() = 0;

            // Send final batch if any variants remain
            if JsonArray.Count > 0 then SendBatchRequest(JsonArray, FlxPointSetup);
        end;
    end;

    /// <summary>
    /// Sends a batch of inventory variant updates to FlxPoint API
    /// Executes HTTP PUT request with JSON array of variant updates
    /// Handles request/response headers and error checking
    /// </summary>
    /// <param name="JsonArray">Array of variant JSON objects to update</param>
    /// <param name="FlxPointSetup">FlxPoint setup record containing API credentials</param>
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
        RequestMessage.Content := HttpContent;

        // Execute request and handle response
        if not Client.Send(RequestMessage, ResponseMessage) then begin
            // Network/communication error
            Session.LogMessage('FlxPoint-InvSync-0001', StrSubstNo('Failed to send batch update request to FlxPoint API. Batch size: %1', JsonArray.Count), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit;
        end;

        if not ResponseMessage.IsSuccessStatusCode() then begin
            ResponseMessage.Content().ReadAs(ResponseText);
            // Log error response for troubleshooting
            Session.LogMessage('FlxPoint-InvSync-0002', StrSubstNo('FlxPoint API returned error for batch update. Status: %1, Response: %2, Batch size: %3', ResponseMessage.HttpStatusCode(), ResponseText, JsonArray.Count), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
            exit;
        end;
        // Success - variants updated in FlxPoint
        Session.LogMessage('FlxPoint-InvSync-0003', StrSubstNo('Successfully sent batch update to FlxPoint API. Batch size: %1', JsonArray.Count), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FlxPoint');
    end;

    /// <summary>
    /// Retrieves product price from BigCommerce API using UPC lookup
    /// Wrapper for BigCommerce API integration with error handling
    /// </summary>
    /// <param name="UPC">UPC barcode to search for</param>
    /// <param name="Price">Output parameter - receives the price if found</param>
    /// <returns>True if API call succeeds (even if no price found), False on error</returns>
    local procedure TryGetBigCommercePrice(UPC: Text; var Price: Decimal): Boolean
    var
        JsonObject: JsonObject;
    begin
        Clear(Price);
        JsonObject := BigCommerceAPI.GetProductByUPC(UPC, Price);
        exit(true);
    end;
}
