page 50711 "FlxPoint Activities"
{
    PageType = CardPart;
    Caption = 'FlxPoint Activities';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            cuegroup(Fulfillment)
            {
                Caption = 'Fulfillment Requests';

                field(NotCreated; NotCreated)
                {
                    ApplicationArea = All;
                    Caption = 'Not Created';
                    ToolTip = 'Number of fulfillment requests not yet created as sales orders';
                }
                field(Created; Created)
                {
                    ApplicationArea = All;
                    Caption = 'Created';
                    ToolTip = 'Number of fulfillment requests with created sales orders';
                }
                field(Posted; Posted)
                {
                    ApplicationArea = All;
                    Caption = 'Posted';
                    ToolTip = 'Number of fulfillment requests with posted sales orders';
                }
                field(Cancelled; Cancelled)
                {
                    ApplicationArea = All;
                    Caption = 'Cancelled';
                    ToolTip = 'Number of cancelled fulfillment requests';
                }
                field(Error; Error)
                {
                    ApplicationArea = All;
                    Caption = 'Error';
                    ToolTip = 'Number of fulfillment requests with errors';
                }
            }
        }
    }
    trigger OnOpenPage()
    begin
        CalculateCues();
    end;
    local procedure CalculateCues()
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
    begin
        // Calculate Not Created
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::"Not Created");
        NotCreated:=FlxPointFulfillmentReq.Count();
        // Calculate Created
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Created);
        Created:=FlxPointFulfillmentReq.Count();
        // Calculate Posted
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Posted);
        Posted:=FlxPointFulfillmentReq.Count();
        // Calculate Cancelled
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Cancelled);
        Cancelled:=FlxPointFulfillmentReq.Count();
        // Calculate Error
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Error);
        Error:=FlxPointFulfillmentReq.Count();
    end;
    var NotCreated: Integer;
    Created: Integer;
    Posted: Integer;
    Cancelled: Integer;
    Error: Integer;
}
