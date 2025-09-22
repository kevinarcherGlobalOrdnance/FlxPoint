page 50700 "FlxPoint Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FlxPoint Setup";
    Caption = 'FlxPoint Setup';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(APIKey; Rec."API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API Key for FlxPoint integration.';
                }
                field(APIBaseURL; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base URL for FlxPoint API.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the FlxPoint integration is enabled.';
                }
                field(PriceListCode; Rec."Price List Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the price list code for FlxPoint integration.';
                }
                field(CustomerTemplate; Rec."Customer Template")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer template to use when creating new customers.';
                }
                field(OrderNoSeriesCode; Rec."Order No Series Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the order no series code for FlxPoint integration.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Image = TestReport;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Caption = 'Test API Connection';
                ToolTip = 'Tests the connection to FlxPoint API with current settings.';

                trigger OnAction()
                begin
                    if not Rec.Enabled then begin
                        Message('FlxPoint integration is not enabled. Please enable it first.');
                        exit;
                    end;
                    if Rec."API Key" = '' then begin
                        Message('API Key is required. Please enter your FlxPoint API key.');
                        exit;
                    end;
                    Message('Connection test completed. Check the status information for results.');
                end;
            }
            action(CreateInventory)
            {
                ApplicationArea = All;
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Caption = 'Create Inventory Items';
                ToolTip = 'Process FlxPoint enabled items and create them in FlxPoint inventory.';

                trigger OnAction()
                var
                    FlxPointCreateInventory: Codeunit "FlxPoint Create Inventory";
                    ConfirmMsg: Label 'This will process all FlxPoint enabled items and create them in FlxPoint inventory. Do you want to continue?';
                begin
                    if not Rec.Enabled then begin
                        Message('FlxPoint integration is not enabled. Please enable it first.');
                        exit;
                    end;
                    if Rec."API Key" = '' then begin
                        Message('API Key is required. Please enter your FlxPoint API key.');
                        exit;
                    end;
                    if not Confirm(ConfirmMsg) then
                        exit;

                    if FlxPointCreateInventory.ProcessFlxPointEnabledItems() then
                        Message('Inventory items have been successfully created in FlxPoint.')
                    else
                        Message('Some errors occurred while creating inventory items. Check the event log for details.');
                end;
            }
        }
    }
}