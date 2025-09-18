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
                    Rec."FlxPoint Last Sync":=0DT;
                end;
            end;
        }
        field(50702; "FlxPoint Last Sync"; DateTime)
        {
            Caption = 'FlxPoint Last Sync';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
