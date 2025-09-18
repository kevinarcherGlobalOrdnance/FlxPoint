table 50700 "FlxPoint Setup"
{
    Caption = 'FlxPoint Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "FlxPoint Setup";
    LookupPageId = "FlxPoint Setup";

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = CustomerContent;
        }
        field(2; "API Key"; Text[100])
        {
            Caption = 'API Key';
            DataClassification = CustomerContent;
        }
        field(3; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';
            DataClassification = CustomerContent;
        }
        field(4; Enabled; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = CustomerContent;
        }
        field(5; "Price List Code"; Code[20])
        {
            Caption = 'Price List Code';
            DataClassification = CustomerContent;
        }
        field(7; "Customer Template"; Code[20])
        {
            Caption = 'Customer Template';
            DataClassification = CustomerContent;
            TableRelation = "Customer Templ.";
        }
        field(8; "Order No Series Code"; Code[20])
        {
            Caption = 'Order No Series Code';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
    }
    keys
    {
        key(Key1; "Primary Key")
        {
            Clustered = true;
        }
    }
}
