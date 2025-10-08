tableextension 50700 "FlxPoint Item Ext" extends Item
{
    fields
    {
        field(50700; "FlxPoint Enabled"; Boolean)
        {
            Caption = 'FlxPoint Enabled';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if not Rec."FlxPoint Enabled" then begin
                    Rec."FlxPoint Last Sync" := 0DT;
                end;
                TestField(MAP);
                flxpointsetup.Get('DEFAULT');
                priceline.SetRange("Price List Code", flxpointsetup."Price List Code");
                priceline.SetRange("Item Reference", itemreference."Reference No.");
                if not priceline.FindFirst() then error('Price list line not found for item reference %1', itemreference."Reference No.");
                itemreference.SetRange("Item No.", Rec."No.");
                itemreference.SetRange("Reference Type", itemreference."Reference Type"::"Bar Code");
                if not itemreference.FindFirst() then error('Item reference not found for item %1', Rec."No.");

            end;
        }
        field(50702; "FlxPoint Last Sync"; DateTime)
        {
            Caption = 'FlxPoint Last Sync';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
    var
        priceline: Record "Price List Line";
        itemreference: Record "Item Reference";
        flxpointsetup: Record "FlxPoint Setup";
}
