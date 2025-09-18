table 50706 "FlxPoint Fulfillment Req Line"
{
    Caption = 'FlxPoint Fulfillment Request Line';
    DataClassification = CustomerContent;
    DrillDownPageId = "FlxPoint Fulfillment Req Lines";
    LookupPageId = "FlxPoint Fulfillment Req Lines";

    fields
    {
        field(1; "Request ID"; Integer)
        {
            Caption = 'Request ID';
            DataClassification = CustomerContent;
            TableRelation = "FlxPoint Fulfillment Req"."Request ID";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Item ID"; Integer)
        {
            Caption = 'Item ID';
            DataClassification = CustomerContent;
        }
        field(4; SKU; Text[50])
        {
            Caption = 'SKU';
            DataClassification = CustomerContent;
        }
        field(5; Quantity; Integer)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
        }
        field(6; Cost; Decimal)
        {
            Caption = 'Cost';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(7; "Item Reference ID"; Text[50])
        {
            Caption = 'Item Reference ID';
            DataClassification = CustomerContent;
        }
        field(8; "Reference ID"; Text[50])
        {
            Caption = 'Reference ID';
            DataClassification = CustomerContent;
        }
        field(9; "Shipped Quantity"; Integer)
        {
            Caption = 'Shipped Quantity';
            DataClassification = CustomerContent;
        }
        field(10; "Voided Quantity"; Integer)
        {
            Caption = 'Voided Quantity';
            DataClassification = CustomerContent;
        }
        field(11; "Acknowledged Quantity"; Integer)
        {
            Caption = 'Acknowledged Quantity';
            DataClassification = CustomerContent;
        }
        field(12; "Sec. Ack. Quantity"; Integer)
        {
            Caption = 'Secondary Acknowledged Quantity';
            DataClassification = CustomerContent;
        }
        field(13; "Inventory Variant ID"; BigInteger)
        {
            Caption = 'Inventory Variant ID';
            DataClassification = CustomerContent;
        }
        field(14; "Order Item ID"; Integer)
        {
            Caption = 'Order Item ID';
            DataClassification = CustomerContent;
        }
        field(15; Title; Text[250])
        {
            Caption = 'Title';
            DataClassification = CustomerContent;
        }
        field(16; "Weight Unit"; Text[10])
        {
            Caption = 'Weight Unit';
            DataClassification = CustomerContent;
        }
        field(17; Weight; Decimal)
        {
            Caption = 'Weight';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(18; "Dimension Unit"; Text[10])
        {
            Caption = 'Dimension Unit';
            DataClassification = CustomerContent;
        }
        field(19; Length; Decimal)
        {
            Caption = 'Length';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(20; Width; Decimal)
        {
            Caption = 'Width';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(21; Height; Decimal)
        {
            Caption = 'Height';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(22; UPC; Text[50])
        {
            Caption = 'UPC';
            DataClassification = CustomerContent;
        }
        field(23; MPN; Text[50])
        {
            Caption = 'MPN';
            DataClassification = CustomerContent;
        }
        field(24; "Line Item Number"; Integer)
        {
            Caption = 'Line Item Number';
            DataClassification = CustomerContent;
        }
        field(25; Subtotal; Decimal)
        {
            Caption = 'Subtotal';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(26; "Processed"; Boolean)
        {
            Caption = 'Processed';
            DataClassification = CustomerContent;
        }
        field(27; "Processing Date"; DateTime)
        {
            Caption = 'Processing Date';
            DataClassification = CustomerContent;
        }
        field(28; "Error Message"; Text[250])
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; "Request ID", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; "Processed")
        {
        }
        key(Key3; SKU)
        {
        }
    }
}
