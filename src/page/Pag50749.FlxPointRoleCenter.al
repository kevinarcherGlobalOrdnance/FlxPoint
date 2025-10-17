page 50749 "FlxPoint Role Center"
{
    PageType = RoleCenter;
    Caption = 'FlxPoint Integration';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(RoleCenter)
        {
            part(Headline; "Headline RC FlxPoint")
            {
                ApplicationArea = All;
            }
            part(Activities; "FlxPoint Activities")
            {
                ApplicationArea = All;
            }

        }
    }
    actions
    {
        area(Embedding)
        {
            action(FlxPointSetup)
            {
                ApplicationArea = All;
                Caption = 'FlxPoint Setup';
                RunObject = page "FlxPoint Setup";
                Image = Setup;
            }
            action(FlxPointFulfillmentRequests)
            {
                ApplicationArea = All;
                Caption = 'Fulfillment Requests';
                RunObject = page "FlxPoint Fulfillment Req List";
                Image = Order;
            }
        }
        area(Sections)
        {
            group(FlxPoint)
            {
                Caption = 'FlxPoint Integration';
                Image = Setup;

                action(ProcessFulfillment)
                {
                    ApplicationArea = All;
                    Caption = 'Process Fulfillment';
                    Image = Process;
                    RunObject = codeunit "FlxPoint Fulfillment";
                }
            }
        }
    }
}
