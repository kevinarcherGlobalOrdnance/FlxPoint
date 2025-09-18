report 50700 CopyWebEnabled
{
    ApplicationArea = All;
    Caption = 'CopyWebEnabled';
    UsageCategory = ReportsAndAnalysis;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Item; Item)
        {
            trigger OnAfterGetRecord()
            begin
                If Item.WebEnabled then Item."FlxPoint Enabled":=true;
                Item.Modify()end;
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(GroupName)
                {
                }
            }
        }
        actions
        {
            area(Processing)
            {
            }
        }
    }
}
