page 50708 "FlxPoint Fulfillment Req Lines"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FlxPoint Fulfillment Req Line";
    Caption = 'FlxPoint Fulfillment Request Lines';

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
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                }
                field(SKU; Rec.SKU)
                {
                    ApplicationArea = All;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }
                field(Cost; Rec.Cost)
                {
                    ApplicationArea = All;
                }
                field(Title; Rec.Title)
                {
                    ApplicationArea = All;
                }
                field("Shipped Quantity"; Rec."Shipped Quantity")
                {
                    ApplicationArea = All;
                }
                field("Voided Quantity"; Rec."Voided Quantity")
                {
                    ApplicationArea = All;
                }
                field("Acknowledged Quantity"; Rec."Acknowledged Quantity")
                {
                    ApplicationArea = All;
                }
                field(UPC; Rec.UPC)
                {
                    ApplicationArea = All;
                }
                field(Subtotal; Rec.Subtotal)
                {
                    ApplicationArea = All;
                }
                field("Processed"; Rec."Processed")
                {
                    ApplicationArea = All;
                }
                field("Processing Date"; Rec."Processing Date")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
