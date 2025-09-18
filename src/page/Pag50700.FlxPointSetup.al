page 50700 "FlxPoint Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FlxPoint Setup";
    Caption = 'FlxPoint Setup';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API Key for FlxPoint integration.';
                }
                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base URL for FlxPoint API.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the FlxPoint integration is enabled.';
                }
                field("Price List Code"; Rec."Price List Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the price list code for FlxPoint integration.';
                }
                field("Customer Template"; Rec."Customer Template")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer template to use when creating new customers.';
                }
                field("Order No Series Code"; Rec."Order No Series Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the order no series code for FlxPoint integration.';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(TestCreateSalesOrder)
            {
                ApplicationArea = All;
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Caption = 'Test Create Sales Order';
                ToolTip = 'Tests creating a sales order from a fulfillment request.';

                trigger OnAction()
                var
                    FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
                    FlxPointCreateSalesOrder: Codeunit "FlxPoint Create Sales Order";
                begin
                    if not Rec.Enabled then Error('FlxPoint integration is not enabled.');
                    if Rec."Customer Template" = '' then Error('Please specify a Customer Template first.');
                    // Find first unprocessed fulfillment request
                    FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::"Not Created");
                    if not FlxPointFulfillmentReq.FindFirst() then Error('No unprocessed fulfillment requests found.');
                    FlxPointCreateSalesOrder.Run();
                    Message('Sales order creation completed. Check the fulfillment request for status.');
                end;
            }
            action(TestCreateInventoryItem)
            {
                ApplicationArea = All;
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'Test Create Inventory Item';
                ToolTip = 'Tests creating an inventory item from a product.';

                trigger OnAction()
                var
                    FlxPointCreateInventoryItem: Codeunit "FlxPoint Create Inventory";
                begin
                    FlxPointCreateInventoryItem.ProcessFlxPointEnabledItems();
                end;
            }
            action(SetFlxPointApiConnection)
            {
                ApplicationArea = All;
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
            }
            action(TestCreateShipment)
            {
                ApplicationArea = All;
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    FlxPointCreateShipment: Codeunit "FlxPoint Create Shipment";
                begin
                    FlxPointCreateShipment.CreateShipment('11318928', '289660835384', 'FEDEXFA', '2DAY', 20250612D);
                end;
            }
        }
    }
}
