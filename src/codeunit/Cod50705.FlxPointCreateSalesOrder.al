codeunit 50705 "FlxPoint Create Sales Order"
{
    var
        FlxPointSetup: Record "FlxPoint Setup";
        NoSeries: Codeunit "No. Series";
        NoSeriesMgt: Codeunit "No. Series";
        ErrorMessage: Text[250];
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
        Item: Record Item;
        ErrorMsg: Label 'Error creating sales order: %1', Comment = '%1 = Error message';
        FlxPointFulfillment: Codeunit "FlxPoint Fulfillment";

    trigger OnRun()
    begin
        Session.LogMessage('FlxPoint-CreateSO-0001', 'Sales Order Creation Process Started', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Operation', 'StartProcess');
        ProcessFulfillmentRequests();
    end;

    procedure ProcessFulfillmentRequests()
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
        TotalProcessed: Integer;
        ErrorCount: Integer;
        TelemetryDimensions: Dictionary of [Text, Text];
        ErrorDetails: List of [Text];
        ErrorSummary: Text;
        ErrorDetail: Text;
    begin
        if not FlxPointSetup.Get('DEFAULT') then begin
            Session.LogMessage('FlxPoint-CreateSO-0002', 'Sales Order Creation Failed: Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'SetupMissing');
            Error('FlxPoint Setup not found.');
        end;
        if not FlxPointSetup.Enabled then begin
            Session.LogMessage('FlxPoint-CreateSO-0003', 'Sales Order Creation Failed: Integration disabled', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorType', 'IntegrationDisabled');
            Error('FlxPoint integration is not enabled.');
        end;
        TotalProcessed := 0;
        ErrorCount := 0;
        Clear(ErrorDetails);
        // Get all unprocessed fulfillment requests
        FlxPointFulfillmentReq.Setrange("Fulfillment Status", 'Processing');
        FlxPointFulfillmentReq.SetRange("Sales Order No.", '');
        Session.LogMessage('FlxPoint-CreateSO-0004', 'Fulfillment Requests Retrieved', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'RequestCount', Format(FlxPointFulfillmentReq.Count));
        if FlxPointFulfillmentReq.FindSet() then
            repeat
                if CreateSalesOrder(FlxPointFulfillmentReq) then begin
                    // Acknowledge the fulfillment request after successful sales order creation
                    //FlxPointFulfillment.AcknowledgeFulfillmentRequest(Format(FlxPointFulfillmentReq."Request ID"));
                    TotalProcessed += 1;
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('SalesOrderNo', FlxPointFulfillmentReq."Sales Order No.");
                    TelemetryDimensions.Add('FulfillmentRequestNo', FlxPointFulfillmentReq."Fulfillment Request No.");
                    Session.LogMessage('FlxPoint-CreateSO-0005', 'Sales Order Created Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                end
                else begin
                    ErrorCount += 1;
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('FulfillmentRequestNo', FlxPointFulfillmentReq."Fulfillment Request No.");
                    TelemetryDimensions.Add('ErrorMessage', ErrorMessage);
                    Session.LogMessage('FlxPoint-CreateSO-0006', 'Sales Order Creation Failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
                    // Add detailed error information to the list
                    ErrorDetails.Add(StrSubstNo('Fulfillment Request %1: %2', FlxPointFulfillmentReq."Fulfillment Request No.", ErrorMessage));
                end;
            until FlxPointFulfillmentReq.Next() = 0;

        // Log final summary
        Session.LogMessage('FlxPoint-CreateSO-0007', 'Sales Order Creation Process Completed', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'TotalProcessed', Format(TotalProcessed), 'ErrorCount', Format(ErrorCount));

        // Create detailed error summary if there were errors
        if ErrorCount > 0 then begin
            ErrorSummary := StrSubstNo('Successfully processed %1 fulfillment requests. %2 requests failed with the following errors:', TotalProcessed, ErrorCount);
            foreach ErrorDetail in ErrorDetails do begin
                ErrorSummary += '\n- ' + ErrorDetail;
            end;

            // Log the detailed error summary
            Session.LogMessage('FlxPoint-CreateSO-0008', 'Sales Order Creation Completed with Errors', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'ErrorSummary', ErrorSummary);
        end else begin
            Session.LogMessage('FlxPoint-CreateSO-0009', 'Sales Order Creation Completed Successfully', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'TotalProcessed', Format(TotalProcessed));
        end;
    end;

    local procedure CreateSalesOrder(FulfillmentRequest: Record "FlxPoint Fulfillment Req"): Boolean
    var
        SalesOrderNo: Code[20];
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        if not TryCreateSalesOrder(FulfillmentRequest, SalesOrderNo) then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('FulfillmentRequestNo', FulfillmentRequest."Fulfillment Request No.");
            TelemetryDimensions.Add('ExceptionDetails', GetLastErrorText());
            Session.LogMessage('FlxPoint-CreateSO-0008', 'Sales Order Creation Exception Occurred', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;
        exit(true);
    end;

    local procedure TryCreateSalesOrder(FulfillmentRequest: Record "FlxPoint Fulfillment Req"; var SalesOrderNo: Code[20]): Boolean
    var
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
        Customer: Record Customer;
        Item: Record Item;
        OrderIDText: Text[35];
        DSHIPPackageOptions: Record "DSHIP Package Options";
        salesrel: Codeunit "Release Sales Document";
        LineCount: Integer;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        Session.LogMessage('FlxPoint-CreateSO-0009', 'Sales Order Creation Started', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'FulfillmentRequestNo', FulfillmentRequest."Fulfillment Request No.");
        // Get next sales order number
        FlxPointSetup.Get('DEFAULT');
        FlxPointSetup.TestField("Order No Series Code");
        SalesOrderNo := NoSeriesMgt.GetNextNo(FlxPointSetup."Order No Series Code", WorkDate(), true);
        // Create Sales Header
        SalesHeader.Init();
        SalesHeader.SetHideValidationDialog(true);
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader."No. Series" := FlxPointSetup."Order No Series Code";
        SalesHeader."No." := SalesOrderNo;
        SalesHeader.InitInsert();
        // Set customer information
        if not FindOrCreateCustomer(FulfillmentRequest, Customer) then begin
            ErrorMessage := StrSubstNo('Could not find or create customer for fulfillment request %1.', FulfillmentRequest."Fulfillment Request No.");
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('FulfillmentRequestNo', FulfillmentRequest."Fulfillment Request No.");
            TelemetryDimensions.Add('Reason', 'CustomerNotFoundOrCreated');
            Session.LogMessage('FlxPoint-CreateSO-0010', 'Customer Creation Failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(false);
        end;
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('CustomerNo', Customer."No.");
        TelemetryDimensions.Add('FulfillmentRequestNo', FulfillmentRequest."Fulfillment Request No.");
        Session.LogMessage('FlxPoint-CreateSO-0011', 'Customer Found or Created', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        SalesHeader.Validate("Sell-to Customer No.", Customer."No.");
        SalesHeader.Validate("Bill-to Customer No.", Customer."No.");
        SalesHeader.Validate("Ship-to Code", '');
        // Set shipping information
        SalesHeader.Validate("Ship-to Name", FulfillmentRequest."Shipping Name");
        SalesHeader.Validate("Ship-to Address", FulfillmentRequest."Shipping Address 1");
        SalesHeader.Validate("Ship-to Address 2", FulfillmentRequest."Shipping Address 2");
        SalesHeader.Validate("Ship-to City", FulfillmentRequest."Shipping City");
        SalesHeader.Validate("Ship-to County", FulfillmentRequest."Shipping State");
        SalesHeader.Validate("Ship-to Country/Region Code", FulfillmentRequest."Shipping Country Code");
        SalesHeader.Validate("Ship-to Post Code", FulfillmentRequest."Shipping Postal Code");
        SalesHeader.Validate("Ship-to Contact", FulfillmentRequest."Shipping First Name" + ' ' + FulfillmentRequest."Shipping Last Name");
        // Set additional fields
        OrderIDText := Format(FulfillmentRequest."Order ID");
        SalesHeader.Validate("External Document No.", FulfillmentRequest."Fulfillment Request No.");
        SalesHeader.Validate("Your Reference", OrderIDText);
        SalesHeader.Validate("Order Date", DT2Date(FulfillmentRequest."Generated At"));
        SalesHeader.Insert();
        Session.LogMessage('FlxPoint-CreateSO-0012', 'Sales Header Created', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'SalesOrderNo', SalesHeader."No.", 'CustomerNo', Customer."No.");
        // Create Sales Lines
        FlxPointFulfillmentReqLine.SetRange("Request ID", FulfillmentRequest."Request ID");
        if FlxPointFulfillmentReqLine.FindSet() then
            repeat
                if FindItemBySKU(FlxPointFulfillmentReqLine.SKU, Item) then begin
                    SalesLine.Init();
                    SalesLine.Validate("Document Type", SalesHeader."Document Type");
                    SalesLine.Validate("Document No.", SalesHeader."No.");
                    SalesLine.Validate("Line No.", FlxPointFulfillmentReqLine."Line No.");
                    SalesLine.Insert(true);
                    SalesLine.Validate(Type, SalesLine.Type::Item);
                    SalesLine.Validate(SalesLine."Item Reference No.", FlxPointFulfillmentReqLine.SKU);
                    SalesLine.Validate(Quantity, FlxPointFulfillmentReqLine.Quantity);
                    SalesLine.Validate("Unit Price", 0);
                    SalesLine.Modify(true);
                    LineCount += 1;
                end
                else begin
                    ErrorMessage := StrSubstNo('Item with SKU %1 not found.', FlxPointFulfillmentReqLine.SKU);
                    Session.LogMessage('FlxPoint-CreateSO-0013', 'Sales Line Creation Failed: Item not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'SKU', FlxPointFulfillmentReqLine.SKU, 'SalesOrderNo', SalesHeader."No.");
                    exit(false);
                end;
            until FlxPointFulfillmentReqLine.Next() = 0;
        Session.LogMessage('FlxPoint-CreateSO-0014', 'Sales Lines Created', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'SalesOrderNo', SalesHeader."No.", 'LineCount', Format(LineCount));
        // Update fulfillment request with sales order information
        FulfillmentRequest."Sales Order No." := SalesHeader."No.";
        FulfillmentRequest."Sales Order Status" := FulfillmentRequest."Sales Order Status"::Created;
        FulfillmentRequest."Sales Order Created Date" := CurrentDateTime;
        FulfillmentRequest.Modify(true);
        //Compliance
        SalesHeader.CalcFields("FFL Required", "Compliance Required");
        IF NOT SalesHeader."FFL Required" AND NOT SalesHeader."Compliance Required" then begin
            salesrel.ReleaseSalesHeader(SalesHeader, false);
            Session.LogMessage('FlxPoint-CreateSO-0015', 'Sales Order Released Automatically', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'SalesOrderNo', SalesHeader."No.", 'Reason', 'NoComplianceRequired');
        end
        else begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('SalesOrderNo', SalesHeader."No.");
            TelemetryDimensions.Add('FFLRequired', Format(SalesHeader."FFL Required"));
            TelemetryDimensions.Add('ComplianceRequired', Format(SalesHeader."Compliance Required"));
            Session.LogMessage('FlxPoint-CreateSO-0016', 'Sales Order Held for Compliance', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        end;
        exit(true);
    end;

    local procedure FindOrCreateCustomer(FulfillmentRequest: Record "FlxPoint Fulfillment Req"; var Customer: Record Customer): Boolean
    var
        CustomerTemplate: Record "Customer Templ.";
        CustomerNo: Code[20];
        DSHIPCustomerOptions: Record "DSHIP Customer Options";
        CustTemplateMgmt: Codeunit "Customer Templ. Mgt.";
        IsNewCustomer: Boolean;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        IsNewCustomer := false;
        // First try to find existing customer by email
        if FulfillmentRequest."Shipping Email" <> '' then begin
            Customer.SetRange("E-Mail", FulfillmentRequest."Shipping Email");
            if Customer.FindFirst() then begin
                Session.LogMessage('FlxPoint-CreateSO-0017', 'Existing Customer Found by Email', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'CustomerNo', Customer."No.");
                exit(true);
            end;
        end;
        // Try to find by name and address
        Customer.SetRange(Name, FulfillmentRequest."Shipping First Name" + ' ' + FulfillmentRequest."Shipping Last Name");
        Customer.SetRange("Ecommerce Customer 2", true);
        Customer.SetRange("Phone No.", FulfillmentRequest."Shipping Phone");
        Customer.SetRange(Address, FulfillmentRequest."Shipping Address 1");
        Customer.SetRange("Post Code", FulfillmentRequest."Shipping Postal Code");
        if Customer.FindFirst() then begin
            Session.LogMessage('FlxPoint-CreateSO-0018', 'Existing Customer Found by Address', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'CustomerNo', Customer."No.");
            exit(true);
        end;
        // If not found, create new customer
        IsNewCustomer := true;
        if not CustomerTemplate.Get(FlxPointSetup."Customer Template") then begin
            Session.LogMessage('FlxPoint-CreateSO-0019', 'Customer Creation Failed: Template not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'TemplateCode', FlxPointSetup."Customer Template");
            exit(false);
        end;
        CustomerNo := NoSeries.GetNextNo(CustomerTemplate."No. Series", WorkDate());
        Customer.Init();
        Customer.Validate("No.", CustomerNo);
        Customer.Insert(true);
        CustTemplateMgmt.ApplyCustomerTemplate(Customer, CustomerTemplate);
        Customer.Name := FulfillmentRequest."Shipping First Name" + ' ' + FulfillmentRequest."Shipping Last Name";
        Customer.Address := CopyStr(FulfillmentRequest."Shipping Address 1", 1, MaxStrLen(Customer.Address));
        Customer."Address 2" := CopyStr(FulfillmentRequest."Shipping Address 2", 1, MaxStrLen(Customer."Address 2"));
        Customer."Post Code" := FulfillmentRequest."Shipping Postal Code";
        Customer.County := FulfillmentRequest."Shipping State";
        Customer.City := FulfillmentRequest."Shipping City";
        Customer."Phone No." := FulfillmentRequest."Shipping Phone";
        Customer."Ecommerce Customer 2" := true;
        Customer."Tax Area Code" := 'AVATAX';
        Customer."Contact Type" := Customer."Contact Type"::Person;
        Customer.Contact := FulfillmentRequest."Shipping First Name" + ' ' + FulfillmentRequest."Shipping Last Name";
        Customer.Validate("Shipping Advice", Customer."Shipping Advice"::Complete);
        Customer.Validate(Reserve, Customer.Reserve::Always);
        Customer.Validate("Country/Region Code", 'US');
        Customer.Validate("E-Mail", FulfillmentRequest."Shipping Email");
        Customer.Validate("Shipping Advice", Customer."Shipping Advice"::Partial);
        Customer.Modify(true);
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('CustomerNo', Customer."No.");
        TelemetryDimensions.Add('CustomerName', Customer.Name);
        Session.LogMessage('FlxPoint-CreateSO-0020', 'New Customer Created', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
        // Create Dynamic Ship Options
        DSHIPCustomerOptions.Init();
        DSHIPCustomerOptions.Validate("Customer No.", Customer."No.");
        DSHIPCustomerOptions.Validate("Shipment Options Template Code", 'ECOMMERCE');
        DSHIPCustomerOptions."Use As Default" := DSHIPCustomerOptions."Use As Default"::Customer;
        DSHIPCustomerOptions.Validate("Shipping Agent Code", 'FEDEX');
        DSHIPCustomerOptions.Validate("Shipping Agent Service Code", 'GROUNDHOME');
        DSHIPCustomerOptions.Insert(true);
        exit(true);
    end;

    local procedure FindItemBySKU(SKU: Text[50]; var Item: Record Item): Boolean
    var
        itemreference: Record "Item Reference";
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        itemreference.SetRange("Reference No.", SKU);
        itemreference.SetRange("Reference Type", itemreference."Reference Type"::"Bar Code");
        if itemreference.FindFirst() then begin
            Clear(TelemetryDimensions);
            TelemetryDimensions.Add('SKU', SKU);
            TelemetryDimensions.Add('ItemNo', itemreference."Item No.");
            Session.LogMessage('FlxPoint-CreateSO-0021', 'Item Found by SKU', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, TelemetryDimensions);
            exit(Item.Get(itemreference."Item No."));
        end
        else begin
            Session.LogMessage('FlxPoint-CreateSO-0022', 'Item Not Found by SKU', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'SKU', SKU);
            exit(false);
        end;
    end;
}
