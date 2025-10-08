codeunit 50707 flxpointeventsubscribers
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnAfterSalesHeaderDelete(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
    begin
        if not RunTrigger then exit;
        if Rec."Document Type" <> Rec."Document Type"::Order then exit;
        FlxPointFulfillmentReq.SetRange("Sales Order No.", Rec."No.");
        if FlxPointFulfillmentReq.FindSet() then
            repeat
                FlxPointFulfillmentReq."Sales Order No." := '';
                FlxPointFulfillmentReq."Sales Order Status" := FlxPointFulfillmentReq."Sales Order Status"::"Not Created";
                FlxPointFulfillmentReq."Sales Order Created Date" := 0DT;
                FlxPointFulfillmentReq."Sales Order Posted Date" := 0DT;
                FlxPointFulfillmentReq."Sales Order Error Message" := '';
                FlxPointFulfillmentReq.Modify(true);
            until FlxPointFulfillmentReq.Next() = 0;
    end;
}


