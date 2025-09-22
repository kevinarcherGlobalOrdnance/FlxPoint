page 50711 "FlxPoint Activities"
{
    PageType = CardPart;
    Caption = 'FlxPoint Activities';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            cuegroup(Fulfillment)
            {
                Caption = 'Fulfillment Requests';
                InstructionalText = 'Overview of fulfillment request processing status. Click on any number to view the related requests.';

                field(NotCreated; NotCreated)
                {
                    ApplicationArea = All;
                    Caption = 'Not Created';
                    ToolTip = 'Number of fulfillment requests not yet created as sales orders. Click to view details.';
                    DrillDownPageId = "FlxPoint Fulfillment Req List";
                    Style = Attention;
                }
                field(Created; Created)
                {
                    ApplicationArea = All;
                    Caption = 'Created';
                    ToolTip = 'Number of fulfillment requests with created sales orders. Click to view details.';
                    DrillDownPageId = "FlxPoint Fulfillment Req List";
                    Style = Favorable;
                }
                field(Posted; Posted)
                {
                    ApplicationArea = All;
                    Caption = 'Posted';
                    ToolTip = 'Number of fulfillment requests with posted sales orders. Click to view details.';
                    DrillDownPageId = "FlxPoint Fulfillment Req List";
                    Style = Favorable;
                }
                field(Cancelled; Cancelled)
                {
                    ApplicationArea = All;
                    Caption = 'Cancelled';
                    ToolTip = 'Number of cancelled fulfillment requests. Click to view details.';
                    DrillDownPageId = "FlxPoint Fulfillment Req List";
                    Style = Unfavorable;
                }
                field(Error; Error)
                {
                    ApplicationArea = All;
                    Caption = 'Error';
                    ToolTip = 'Number of fulfillment requests with errors. Click to view details.';
                    DrillDownPageId = "FlxPoint Fulfillment Req List";
                    Style = Unfavorable;
                }
            }

            cuegroup(Processing)
            {
                Caption = 'Processing Status';
                InstructionalText = 'Current processing activity and system status.';

                field(ProcessingToday; ProcessingToday)
                {
                    ApplicationArea = All;
                    Caption = 'Processed Today';
                    ToolTip = 'Number of fulfillment requests processed today.';
                    Editable = false;
                }
                field(LastProcessed; LastProcessed)
                {
                    ApplicationArea = All;
                    Caption = 'Last Processed';
                    ToolTip = 'Date and time of the last processing activity.';
                    Editable = false;
                }
                field(IntegrationStatus; IntegrationStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Integration Status';
                    ToolTip = 'Current status of the FlxPoint integration.';
                    Editable = false;
                    Style = StrongAccent;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshData)
            {
                ApplicationArea = All;
                Image = Refresh;
                Caption = 'Refresh';
                ToolTip = 'Refresh the activity data and recalculate all cues.';

                trigger OnAction()
                begin
                    CalculateCues();
                    Message('Activity data refreshed successfully.');
                end;
            }
            action(ProcessFulfillment)
            {
                ApplicationArea = All;
                Image = Process;
                Caption = 'Process Fulfillment';
                ToolTip = 'Process pending fulfillment requests.';

                trigger OnAction()
                var
                    FlxPointFulfillment: Codeunit "FlxPoint Fulfillment";
                begin
                    FlxPointFulfillment.Run();
                    CalculateCues();
                    Message('Fulfillment processing completed.');
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        CalculateCues();
    end;

    trigger OnAfterGetRecord()
    begin
        CalculateCues();
    end;

    local procedure CalculateCues()
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
        FlxPointSetup: Record "FlxPoint Setup";
    begin
        // Calculate Not Created
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::"Not Created");
        NotCreated := FlxPointFulfillmentReq.Count();

        // Calculate Created
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Created);
        Created := FlxPointFulfillmentReq.Count();

        // Calculate Posted
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Posted);
        Posted := FlxPointFulfillmentReq.Count();

        // Calculate Cancelled
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Cancelled);
        Cancelled := FlxPointFulfillmentReq.Count();

        // Calculate Error
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetRange("Sales Order Status", FlxPointFulfillmentReq."Sales Order Status"::Error);
        Error := FlxPointFulfillmentReq.Count();

        // Calculate Processing Today
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetFilter("Processing Date", '>=%1&<=%2', CreateDateTime(Today, 0T), CreateDateTime(Today, 235959T));
        ProcessingToday := FlxPointFulfillmentReq.Count();

        // Calculate Last Processed
        FlxPointFulfillmentReq.Reset();
        FlxPointFulfillmentReq.SetCurrentKey("Processing Date");
        FlxPointFulfillmentReq.SetAscending("Processing Date", false);
        if FlxPointFulfillmentReq.FindFirst() then
            LastProcessed := FlxPointFulfillmentReq."Processing Date"
        else
            LastProcessed := 0DT;

        // Calculate Integration Status
        if FlxPointSetup.Get('DEFAULT') then begin
            if not FlxPointSetup.Enabled then
                IntegrationStatus := 'Disabled'
            else if FlxPointSetup."API Key" = '' then
                IntegrationStatus := 'Not Configured'
            else
                IntegrationStatus := 'Active';
        end else
            IntegrationStatus := 'Not Setup';
    end;

    var
        NotCreated: Integer;
        Created: Integer;
        Posted: Integer;
        Cancelled: Integer;
        Error: Integer;
        ProcessingToday: Integer;
        LastProcessed: DateTime;
        IntegrationStatus: Text;
}
