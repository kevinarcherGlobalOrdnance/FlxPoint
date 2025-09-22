page 50709 "FlxPoint Fulfillment Req Card"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FlxPoint Fulfillment Req";
    Caption = 'FlxPoint Fulfillment Request';

    layout
    {
        area(Content)
        {
            group(OrderInformation)
            {
                Caption = 'Order Information';
                InstructionalText = 'Basic order details and identification information.';

                field("Request ID"; Rec."Request ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unique identifier for this fulfillment request from FlxPoint.';
                    Editable = false;
                }
                field("Fulfillment Request No."; Rec."Fulfillment Request No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fulfillment request number for reference.';
                    Editable = false;
                }
                field("Order ID"; Rec."Order ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Original order ID from the source system.';
                    Editable = false;
                }
                field("Generated At"; Rec."Generated At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time when this fulfillment request was generated.';
                    Editable = false;
                }
            }

            group(StatusInformation)
            {
                Caption = 'Status Information';
                InstructionalText = 'Current processing status and related information.';

                field("Fulfillment Status"; Rec."Fulfillment Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current fulfillment status from FlxPoint.';
                    Editable = false;
                    Style = StrongAccent;
                }
                field("Sales Order Status"; Rec."Sales Order Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current sales order processing status in Business Central.';
                    Editable = false;
                    Style = StrongAccent;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Business Central sales order number if created.';
                    Editable = false;
                }
                field("Sales Order Created Date"; Rec."Sales Order Created Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time when the sales order was created.';
                    Editable = false;
                }
                field("Shipped Status"; Rec."Shipped Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current shipping status.';
                    Editable = false;
                }
            }

            group(OrderSummary)
            {
                Caption = 'Order Summary';
                InstructionalText = 'Order totals and item counts.';

                field("Total Items"; Rec."Total Items")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total number of different items in this order.';
                    Editable = false;
                }
                field("Total Quantity"; Rec."Total Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total quantity of all items in this order.';
                    Editable = false;
                }
                field("Total Cost"; Rec."Total Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total cost of all items in this order.';
                    Editable = false;
                    Style = StrongAccent;
                }
            }
            group(ShippingInformation)
            {
                Caption = 'Shipping Information';
                InstructionalText = 'Customer shipping details and delivery information.';

                field("Shipping Name"; Rec."Shipping Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Full name of the shipping recipient.';
                    Editable = false;
                }
                field("Shipping Address 1"; Rec."Shipping Address 1")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primary shipping address line.';
                    Editable = false;
                }
                field("Shipping Address 2"; Rec."Shipping Address 2")
                {
                    ApplicationArea = All;
                    ToolTip = 'Secondary shipping address line (apartment, suite, etc.).';
                    Editable = false;
                }
                field("Shipping City"; Rec."Shipping City")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shipping city.';
                    Editable = false;
                }
                field("Shipping State"; Rec."Shipping State")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shipping state or province.';
                    Editable = false;
                }
                field("Shipping Country"; Rec."Shipping Country")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shipping country.';
                    Editable = false;
                }
                field("Shipping Postal Code"; Rec."Shipping Postal Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shipping postal or ZIP code.';
                    Editable = false;
                }
                field("Shipping Email"; Rec."Shipping Email")
                {
                    ApplicationArea = All;
                    ToolTip = 'Customer email address for shipping notifications.';
                    Editable = false;
                }
                field("Shipping Phone"; Rec."Shipping Phone")
                {
                    ApplicationArea = All;
                    ToolTip = 'Customer phone number for shipping contact.';
                    Editable = false;
                }
                field("Shipping Method"; Rec."Shipping Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Selected shipping method.';
                    Editable = false;
                }
                field("Carrier"; Rec."Carrier")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shipping carrier (FedEx, UPS, etc.).';
                    Editable = false;
                }
                field("Method"; Rec."Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specific shipping method within the carrier.';
                    Editable = false;
                }
            }
            group(Package)
            {
                field("Package Length"; Rec."Package Length")
                {
                    ApplicationArea = All;
                }
                field("Package Width"; Rec."Package Width")
                {
                    ApplicationArea = All;
                }
                field("Package Height"; Rec."Package Height")
                {
                    ApplicationArea = All;
                }
                field("Package Weight"; Rec."Package Weight")
                {
                    ApplicationArea = All;
                }
            }
            group(Processing)
            {
                field("Processed"; Rec."Processed")
                {
                    ApplicationArea = All;
                }
                field("Processing Date"; Rec."Processing Date")
                {
                    ApplicationArea = All;
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                }
                field("Processing Error Reason"; Rec."Processing Error Reason")
                {
                    ApplicationArea = All;
                }
                field("Cancel Reason"; Rec."Cancel Reason")
                {
                    ApplicationArea = All;
                }
                field("Voided Reason"; Rec."Voided Reason")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ProcessRequest)
            {
                ApplicationArea = All;
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Caption = 'Process Request';
                ToolTip = 'Process this fulfillment request to create a sales order.';

                trigger OnAction()
                var
                    FlxPointCreateSalesOrder: Codeunit "FlxPoint Create Sales Order";
                    ConfirmMsg: Label 'Are you sure you want to process this fulfillment request?';
                begin
                    if not Confirm(ConfirmMsg) then
                        exit;

                    if Rec."Sales Order Status" <> Rec."Sales Order Status"::"Not Created" then begin
                        Message('This fulfillment request has already been processed.');
                        exit;
                    end;

                    FlxPointCreateSalesOrder.Run();
                    Message('Fulfillment request processing completed. Check the status for results.');
                    CurrPage.Update();
                end;
            }
            action(ViewLines)
            {
                ApplicationArea = All;
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'View Lines';
                ToolTip = 'View the fulfillment request line items.';

                trigger OnAction()
                var
                    FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
                begin
                    FlxPointFulfillmentReqLine.SetRange("Request ID", Rec."Request ID");
                    Page.Run(Page::"FlxPoint Fulfillment Req Lines", FlxPointFulfillmentReqLine);
                end;
            }
            action(OpenSalesOrder)
            {
                ApplicationArea = All;
                Image = Document;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'Open Sales Order';
                ToolTip = 'Open the related sales order if it has been created.';
                Enabled = Rec."Sales Order No." <> '';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if Rec."Sales Order No." = '' then begin
                        Message('No sales order has been created for this fulfillment request yet.');
                        exit;
                    end;

                    if SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Sales Order No.") then
                        Page.Run(Page::"Sales Order", SalesHeader)
                    else
                        Message('Sales order %1 could not be found.', Rec."Sales Order No.");
                end;
            }
            action(RefreshStatus)
            {
                ApplicationArea = All;
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'Refresh Status';
                ToolTip = 'Refresh the fulfillment request status from FlxPoint.';

                trigger OnAction()
                var
                    FlxPointFulfillment: Codeunit "FlxPoint Fulfillment";
                begin
                    FlxPointFulfillment.ProcessFulfillmentRequests();
                    Message('Status refreshed successfully.');
                    CurrPage.Update();
                end;
            }
        }
        area(Navigation)
        {
            action(OpenCustomer)
            {
                ApplicationArea = All;
                Image = Customer;
                Caption = 'Open Customer';
                ToolTip = 'Open the customer record if available.';
                Enabled = Rec."Shipping Email" <> '';

                trigger OnAction()
                var
                    Customer: Record Customer;
                begin
                    if Rec."Shipping Email" = '' then begin
                        Message('No customer email available for this fulfillment request.');
                        exit;
                    end;

                    Customer.SetRange("E-Mail", Rec."Shipping Email");
                    if Customer.FindFirst() then
                        Page.Run(Page::"Customer Card", Customer)
                    else
                        Message('No customer found with email %1.', Rec."Shipping Email");
                end;
            }
        }
    }
}
