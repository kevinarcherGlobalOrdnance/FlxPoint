page 50748 "FlxPoint Fulfillment Req List"
{
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FlxPoint Fulfillment Req";
    Caption = 'FlxPoint Fulfillment Requests';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Request ID"; Rec."Request ID")
                {
                    ApplicationArea = All;
                }
                field("Fulfillment Request No."; Rec."Fulfillment Request No.")
                {
                    ApplicationArea = All;
                }
                field("Order ID"; Rec."Order ID")
                {
                    ApplicationArea = All;
                }
                field("Generated At"; Rec."Generated At")
                {
                    ApplicationArea = All;
                }
                field("Fulfillment Status"; Rec."Fulfillment Status")
                {
                    ApplicationArea = All;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
