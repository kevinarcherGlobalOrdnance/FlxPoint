codeunit 50706 "FlxPoint Sales Order Events"
{
    Permissions = TableData "FlxPoint Fulfillment Req"=RIMD;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnAfterSalesHeaderDelete(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    var
        FlxPointFulfillmentReq: Record "FlxPoint Fulfillment Req";
    begin
        if not RunTrigger then exit;
        if Rec."Document Type" <> Rec."Document Type"::Order then exit;
        FlxPointFulfillmentReq.SetRange("Sales Order No.", Rec."No.");
        if FlxPointFulfillmentReq.FindSet()then repeat FlxPointFulfillmentReq."Sales Order No.":='';
                FlxPointFulfillmentReq."Sales Order Status":=FlxPointFulfillmentReq."Sales Order Status"::"Not Created";
                FlxPointFulfillmentReq."Sales Order Created Date":=0DT;
                FlxPointFulfillmentReq."Sales Order Posted Date":=0DT;
                FlxPointFulfillmentReq."Sales Order Error Message":='';
                FlxPointFulfillmentReq.Modify(true);
            until FlxPointFulfillmentReq.Next() = 0;
    end;
    [EventSubscriber(ObjectType::Table, Database::"Sales Shipment Header", 'OnAfterInsertEvent', '', true, true)]
    local procedure UpdateEcommerceOrderTracking(Rec: Record "Sales Shipment Header")
    var
        flxpointCreateShipment: Codeunit "FlxPoint Create Shipment";
        flxpointFulfillmentReq: Record "FlxPoint Fulfillment Req";
    begin
        flxpointFulfillmentReq.Setrange("Sales Order No.", Rec."Order No.");
        if flxpointFulfillmentReq.FindFirst()then begin
            flxpointCreateShipment.CreateShipment(Format(flxpointFulfillmentReq."Request ID"), Rec."Package Tracking No.", Rec."Shipping Agent Code", Rec."Shipping Agent Service Code", Rec."Posting Date");
        end;
    end;
}
