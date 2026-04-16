table 50742 "BigCommerce Order Line"
{
    Caption = 'BigCommerce Order Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(2; "Order ID"; Integer)
        {
            Caption = 'Order ID';
            DataClassification = CustomerContent;
            ToolTip = 'BigCommerce order ID';
        }
        field(3; "Order Date"; Date)
        {
            Caption = 'Order Date';
            DataClassification = CustomerContent;
        }
        field(4; "Order Product ID"; Integer)
        {
            Caption = 'Order Product ID';
            DataClassification = CustomerContent;
            ToolTip = 'ID of the product line within the BigCommerce order';
        }
        field(5; "Product ID"; Integer)
        {
            Caption = 'Product ID';
            DataClassification = CustomerContent;
            ToolTip = 'BigCommerce catalog product ID';
        }
        field(6; Name; Text[250])
        {
            Caption = 'Name';
            DataClassification = CustomerContent;
        }
        field(7; SKU; Code[50])
        {
            Caption = 'SKU';
            DataClassification = CustomerContent;
        }
        field(8; "Product Type"; Text[30])
        {
            Caption = 'Product Type';
            DataClassification = CustomerContent;
            ToolTip = 'physical, digital, or giftcertificate';
        }
        field(9; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(10; "Base Price"; Decimal)
        {
            Caption = 'Base Price';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(11; "Price Excl. Tax"; Decimal)
        {
            Caption = 'Price Excl. Tax';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(12; "Price Incl. Tax"; Decimal)
        {
            Caption = 'Price Incl. Tax';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(13; "Total Excl. Tax"; Decimal)
        {
            Caption = 'Total Excl. Tax';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(14; "Total Incl. Tax"; Decimal)
        {
            Caption = 'Total Incl. Tax';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(15; "Last Fetched At"; DateTime)
        {
            Caption = 'Last Fetched At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(16; "BC Item No."; Code[20])
        {
            Caption = 'Business Central Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
            ToolTip = 'Resolved from Item Reference (Bar Code) matching this line''s SKU.';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(OrderID; "Order ID", "Order Product ID")
        {
        }
        key(OrderDate; "Order Date", "Order ID")
        {
        }
    }
}
