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
            group(General)
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
                field("Shipped Status"; Rec."Shipped Status")
                {
                    ApplicationArea = All;
                }
                field("Total Items"; Rec."Total Items")
                {
                    ApplicationArea = All;
                }
                field("Total Quantity"; Rec."Total Quantity")
                {
                    ApplicationArea = All;
                }
                field("Total Cost"; Rec."Total Cost")
                {
                    ApplicationArea = All;
                }
            }
            group(Shipping)
            {
                field("Shipping Name"; Rec."Shipping Name")
                {
                    ApplicationArea = All;
                }
                field("Shipping Address 1"; Rec."Shipping Address 1")
                {
                    ApplicationArea = All;
                }
                field("Shipping Address 2"; Rec."Shipping Address 2")
                {
                    ApplicationArea = All;
                }
                field("Shipping City"; Rec."Shipping City")
                {
                    ApplicationArea = All;
                }
                field("Shipping State"; Rec."Shipping State")
                {
                    ApplicationArea = All;
                }
                field("Shipping Country"; Rec."Shipping Country")
                {
                    ApplicationArea = All;
                }
                field("Shipping Postal Code"; Rec."Shipping Postal Code")
                {
                    ApplicationArea = All;
                }
                field("Shipping Email"; Rec."Shipping Email")
                {
                    ApplicationArea = All;
                }
                field("Shipping Phone"; Rec."Shipping Phone")
                {
                    ApplicationArea = All;
                }
                field("Shipping Method"; Rec."Shipping Method")
                {
                    ApplicationArea = All;
                }
                field("Carrier"; Rec."Carrier")
                {
                    ApplicationArea = All;
                }
                field("Method"; Rec."Method")
                {
                    ApplicationArea = All;
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
                ToolTip = 'Process this fulfillment request.';

                trigger OnAction()
                var
                    FlxPointFulfillment: Codeunit "FlxPoint Fulfillment";
                begin
                    FlxPointFulfillment.ProcessFulfillmentRequests();
                end;
            }
            action(ViewLines)
            {
                ApplicationArea = All;
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Caption = 'View Lines';
                ToolTip = 'View the fulfillment request lines.';

                trigger OnAction()
                var
                    FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
                begin
                    FlxPointFulfillmentReqLine.SetRange("Request ID", Rec."Request ID");
                    Page.Run(Page::"FlxPoint Fulfillment Req Lines", FlxPointFulfillmentReqLine);
                end;
            }
        }
    }
}
