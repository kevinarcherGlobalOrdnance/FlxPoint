page 50748 "FlxPoint Fulfillment Req List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FlxPoint Fulfillment Req";
    Caption = 'FlxPoint Fulfillment Requests';
    CardPageId = "FlxPoint Fulfillment Req Card";

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Request ID"; Rec."Request ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unique identifier for this fulfillment request.';
                }
                field("Fulfillment Request No."; Rec."Fulfillment Request No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fulfillment request number for reference.';
                }
                field("Order ID"; Rec."Order ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Original order ID from the source system.';
                }
                field("Generated At"; Rec."Generated At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time when this fulfillment request was generated.';
                }
                field("Fulfillment Status"; Rec."Fulfillment Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current fulfillment status from FlxPoint.';
                    Style = StrongAccent;
                }
                field("Sales Order Status"; Rec."Sales Order Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current sales order processing status in Business Central.';
                    Style = StrongAccent;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Business Central sales order number if created.';
                }
                field("Shipping Name"; Rec."Shipping Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Customer shipping name.';
                }
                field("Total Cost"; Rec."Total Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total cost of this fulfillment request.';
                    Style = StrongAccent;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessSelected)
            {
                ApplicationArea = All;
                Image = Process;
                Caption = 'Process Selected';
                ToolTip = 'Process the selected fulfillment requests.';

                trigger OnAction()
                var
                    FlxPointCreateSalesOrder: Codeunit "FlxPoint Create Sales Order";
                    ConfirmMsg: Label 'Are you sure you want to process the selected fulfillment requests?';
                begin
                    if not Confirm(ConfirmMsg) then
                        exit;

                    FlxPointCreateSalesOrder.Run();
                    Message('Selected fulfillment requests have been processed.');
                    CurrPage.Update();
                end;
            }
            action(RefreshData)
            {
                ApplicationArea = All;
                Image = Refresh;
                Caption = 'Refresh';
                ToolTip = 'Refresh the fulfillment request data from FlxPoint.';

                trigger OnAction()
                var
                    FlxPointFulfillment: Codeunit "FlxPoint Fulfillment";
                begin
                    FlxPointFulfillment.ProcessFulfillmentRequests();
                    Message('Fulfillment request data refreshed successfully.');
                    CurrPage.Update();
                end;
            }
            action(OpenSalesOrder)
            {
                ApplicationArea = All;
                Image = Document;
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
        }
    }
}
