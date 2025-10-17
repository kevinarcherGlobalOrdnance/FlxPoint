pageextension 50701 CustomerCardPgExt extends "Customer Card"
{
    layout
    {
        addafter("Customer type")
        {
            field("Ecommerce Customer"; Rec."Ecommerce Customer 2")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this customer is an ecommerce customer.';
            }
        }
    }
}
