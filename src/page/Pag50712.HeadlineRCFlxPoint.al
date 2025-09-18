page 50712 "Headline RC FlxPoint"
{
    PageType = HeadlinePart;
    Caption = 'FlxPoint Integration Headline';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            field(HeadlineText; HeadlineText)
            {
                ApplicationArea = All;
                Caption = 'Welcome to FlxPoint Integration';
                Editable = false;
                MultiLine = true;
            }
            field(SubHeadlineText; SubHeadlineText)
            {
                ApplicationArea = All;
                Caption = 'Manage your FlxPoint integration';
                Editable = false;
                MultiLine = true;
            }
        }
    }
    trigger OnOpenPage()
    begin
        SetHeadlineText();
    end;
    local procedure SetHeadlineText()
    begin
        HeadlineText:='Welcome to FlxPoint Integration';
        SubHeadlineText:='Manage your inventory synchronization and fulfillment requests efficiently.';
    end;
    var HeadlineText: Text;
    SubHeadlineText: Text;
}
