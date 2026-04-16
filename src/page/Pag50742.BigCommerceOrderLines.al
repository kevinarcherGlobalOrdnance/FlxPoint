page 50742 "BigCommerce Order Lines"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "BigCommerce Order Line";
    Caption = 'BigCommerce Order Lines';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unique entry number.';
                }
                field("Order ID"; Rec."Order ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'BigCommerce order ID.';
                }
                field("Order Date"; Rec."Order Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date the order was created.';
                }
                field("Order Product ID"; Rec."Order Product ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'ID of the line within the order.';
                }
                field("Product ID"; Rec."Product ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'BigCommerce catalog product ID.';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ToolTip = 'Product name.';
                }
                field(SKU; Rec.SKU)
                {
                    ApplicationArea = All;
                    ToolTip = 'Stock keeping unit.';
                }
                field("BC Item No."; Rec."BC Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Business Central item resolved from Item Reference (Bar Code) matching this line''s SKU.';
                }
                field("Product Type"; Rec."Product Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'physical, digital, or giftcertificate.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Quantity ordered.';
                }
                field("Base Price"; Rec."Base Price")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit base price.';
                }
                field("Price Excl. Tax"; Rec."Price Excl. Tax")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit price excluding tax.';
                }
                field("Price Incl. Tax"; Rec."Price Incl. Tax")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit price including tax.';
                }
                field("Total Excl. Tax"; Rec."Total Excl. Tax")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line total excluding tax.';
                }
                field("Total Incl. Tax"; Rec."Total Incl. Tax")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line total including tax.';
                }
                field("Last Fetched At"; Rec."Last Fetched At")
                {
                    ApplicationArea = All;
                    ToolTip = 'When this line was last synced from BigCommerce.';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(FetchOrders)
            {
                ApplicationArea = All;
                Caption = 'Fetch Order Lines';
                Image = Refresh;
                ToolTip = 'Retrieve orders and order lines from BigCommerce and update the list.';

                trigger OnAction()
                var
                    BigCommerceAPI: Codeunit "BigCommerce API";
                    BigCommerceSetup: Record "BigCommerce Setup";
                    MinDate: Date;
                begin
                    if not BigCommerceSetup.Get('DEFAULT') then
                        Error('BigCommerce Setup not found.');
                    MinDate := BigCommerceSetup."Earliest Order Date";
                    if MinDate = 0D then
                        MinDate := Today - 90; // Default: last 90 days to avoid very long runs
                    BigCommerceAPI.FetchOrderLinesToTable(MinDate, 0);
                    CurrPage.Update(false);
                    Message('Order lines have been fetched from BigCommerce (orders from %1).', MinDate);
                end;
            }
        }
    }
}
