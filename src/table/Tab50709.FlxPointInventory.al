table 50709 "FlxPoint Inventory"
{
    Caption = 'FlxPoint Inventory';
    DataClassification = CustomerContent;
    DrillDownPageId = "FlxPoint Inventory";
    LookupPageId = "FlxPoint Inventory";

    fields
    {
        field(1; "Inventory Variant ID"; Text[50])
        {
            Caption = 'Inventory Variant ID';
            DataClassification = CustomerContent;
        }
        field(2; SKU; Text[50])
        {
            Caption = 'SKU';
            DataClassification = CustomerContent;
        }
        field(3; Title; Text[250])
        {
            Caption = 'Title';
            DataClassification = CustomerContent;
        }
        field(4; "Item Reference ID"; Text[50])
        {
            Caption = 'Item Reference ID';
            DataClassification = CustomerContent;
        }
        field(5; UPC; Text[50])
        {
            Caption = 'UPC';
            DataClassification = CustomerContent;
        }
        field(6; MPN; Text[50])
        {
            Caption = 'MPN';
            DataClassification = CustomerContent;
        }
        field(7; "Inventory Item ID"; Text[50])
        {
            Caption = 'Inventory Item ID';
            DataClassification = CustomerContent;
        }
        field(8; "Inventory Item Title"; Text[250])
        {
            Caption = 'Inventory Item Title';
            DataClassification = CustomerContent;
        }
        field(9; "Inventory Item SKU"; Text[50])
        {
            Caption = 'Inventory Item SKU';
            DataClassification = CustomerContent;
        }
        field(10; "Inventory Item Reference ID"; Text[50])
        {
            Caption = 'Inventory Item Reference ID';
            DataClassification = CustomerContent;
        }
        field(11; "Inventory Item UPC"; Text[50])
        {
            Caption = 'Inventory Item UPC';
            DataClassification = CustomerContent;
        }
        field(12; "Inventory Item MPN"; Text[50])
        {
            Caption = 'Inventory Item MPN';
            DataClassification = CustomerContent;
        }
        field(13; "Last Modified Date"; DateTime)
        {
            Caption = 'Last Modified Date';
            DataClassification = CustomerContent;
        }
        field(14; "Last Sync Date"; DateTime)
        {
            Caption = 'Last Sync Date';
            DataClassification = CustomerContent;
        }
        field(15; "Source ID"; Text[50])
        {
            Caption = 'Source ID';
            DataClassification = CustomerContent;
        }
        field(16; "Inventory Parent ID"; Text[50])
        {
            Caption = 'Inventory Parent ID';
            DataClassification = CustomerContent;
        }
        field(17; "Supplier Variant ID"; Text[50])
        {
            Caption = 'Supplier Variant ID';
            DataClassification = CustomerContent;
        }
        field(18; "Shipping Cost"; Decimal)
        {
            Caption = 'Shipping Cost';
            DataClassification = CustomerContent;
        }
        field(19; "Dropship Fee"; Decimal)
        {
            Caption = 'Dropship Fee';
            DataClassification = CustomerContent;
        }
        field(20; "Inventory List Price"; Decimal)
        {
            Caption = 'Inventory List Price';
            DataClassification = CustomerContent;
        }
        field(21; "Reference Identifier"; Text[50])
        {
            Caption = 'Reference Identifier';
            DataClassification = CustomerContent;
        }
        field(22; "Committed Quantity"; Decimal)
        {
            Caption = 'Committed Quantity';
            DataClassification = CustomerContent;
        }
        field(23; "Incoming Quantity"; Decimal)
        {
            Caption = 'Incoming Quantity';
            DataClassification = CustomerContent;
        }
        field(24; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
        }
        field(25; "Total Quantity"; Decimal)
        {
            Caption = 'Total Quantity';
            DataClassification = CustomerContent;
        }
        field(26; "Account ID"; Text[50])
        {
            Caption = 'Account ID';
            DataClassification = CustomerContent;
        }
        field(27; "Master SKU"; Text[50])
        {
            Caption = 'Master SKU';
            DataClassification = CustomerContent;
        }
        field(28; EAN; Text[50])
        {
            Caption = 'EAN';
            DataClassification = CustomerContent;
        }
        field(29; ASIN; Text[50])
        {
            Caption = 'ASIN';
            DataClassification = CustomerContent;
        }
        field(30; MSRP; Decimal)
        {
            Caption = 'MSRP';
            DataClassification = CustomerContent;
        }
        field(31; MAP; Decimal)
        {
            Caption = 'MAP';
            DataClassification = CustomerContent;
        }
        field(32; Weight; Decimal)
        {
            Caption = 'Weight';
            DataClassification = CustomerContent;
        }
        field(33; Length; Decimal)
        {
            Caption = 'Length';
            DataClassification = CustomerContent;
        }
        field(34; Width; Decimal)
        {
            Caption = 'Width';
            DataClassification = CustomerContent;
        }
        field(35; Height; Decimal)
        {
            Caption = 'Height';
            DataClassification = CustomerContent;
        }
        field(36; "Weight Unit"; Text[10])
        {
            Caption = 'Weight Unit';
            DataClassification = CustomerContent;
        }
        field(37; "Dimension Unit"; Text[10])
        {
            Caption = 'Dimension Unit';
            DataClassification = CustomerContent;
        }
        field(38; "Dimensional Weight"; Decimal)
        {
            Caption = 'Dimensional Weight';
            DataClassification = CustomerContent;
        }
        field(39; Cost; Decimal)
        {
            Caption = 'Cost';
            DataClassification = CustomerContent;
        }
        field(40; Description; Text[2048])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(41; "Bin Location"; Text[50])
        {
            Caption = 'Bin Location';
            DataClassification = CustomerContent;
        }
        field(42; "Requires FFL"; Boolean)
        {
            Caption = 'Requires FFL';
            DataClassification = CustomerContent;
        }
        field(43; "Allow Backorders"; Boolean)
        {
            Caption = 'Allow Backorders';
            DataClassification = CustomerContent;
        }
        field(44; Archived; Boolean)
        {
            Caption = 'Archived';
            DataClassification = CustomerContent;
        }
        field(45; "Inserted At"; DateTime)
        {
            Caption = 'Inserted At';
            DataClassification = CustomerContent;
        }
        field(46; "Updated At"; DateTime)
        {
            Caption = 'Updated At';
            DataClassification = CustomerContent;
        }
        field(47; "Total Quantity Last Changed At"; DateTime)
        {
            Caption = 'Total Quantity Last Changed At';
            DataClassification = CustomerContent;
        }
        field(48; "Content Updated At"; DateTime)
        {
            Caption = 'Content Updated At';
            DataClassification = CustomerContent;
        }
        field(49; "Business Central UOM"; Text[50])
        {
            Caption = 'Business Central Unit of Measure';
            DataClassification = CustomerContent;
        }
        field(50; "Business Central QOH"; Decimal)
        {
            Caption = 'Business Central QOH';
            DataClassification = CustomerContent;
        }
        field(51; "Business Central Item No."; Code[20])
        {
            Caption = 'Business Central Item No.';
            DataClassification = CustomerContent;
        }
        field(52; "Business Central Price"; Decimal)
        {
            Caption = 'Business Central Price';
            DataClassification = CustomerContent;
        }
        field(53; "Business Central Cost"; Decimal)
        {
            Caption = 'Business Central Cost';
            DataClassification = CustomerContent;
        }
        field(54; "Business Central Map"; Decimal)
        {
            Caption = 'Business Central MAP';
            DataClassification = CustomerContent;
        }
        field(55; "BigCommerce Price"; Decimal)
        {
            Caption = 'BigCommerce Price';
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; "Inventory Variant ID")
        {
            Clustered = true;
        }
        key(Key2; SKU)
        {
        }
        key(Key3; UPC)
        {
        }
        key(Key4; "Master SKU")
        {
        }
    }
}
