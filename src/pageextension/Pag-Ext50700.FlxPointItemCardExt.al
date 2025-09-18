pageextension 50700 "FlxPoint Item Card Ext" extends "Item Card"
{
    layout
    {
        addlast(Item)
        {
            group(FlxPoint)
            {
                Caption = 'FlxPoint Integration';

                field("FlxPoint Enabled"; Rec."FlxPoint Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this item is integrated with FlxPoint.';
                }
                field("FlxPoint Last Sync"; Rec."FlxPoint Last Sync")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this item was last synchronized with FlxPoint.';
                    Editable = false;
                }
            }
        }
    }
}
