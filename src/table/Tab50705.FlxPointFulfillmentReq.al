table 50705 "FlxPoint Fulfillment Req"
{
    Caption = 'FlxPoint Fulfillment Request';
    DataClassification = CustomerContent;
    DrillDownPageId = "FlxPoint Fulfillment Req List";
    LookupPageId = "FlxPoint Fulfillment Req List";

    fields
    {
        field(1; "Request ID"; Integer)
        {
            Caption = 'Request ID';
            DataClassification = CustomerContent;
        }
        field(2; "Fulfillment Request No."; Text[50])
        {
            Caption = 'Fulfillment Request No.';
            DataClassification = CustomerContent;
        }
        field(3; "Order ID"; Integer)
        {
            Caption = 'Order ID';
            DataClassification = CustomerContent;
        }
        field(4; "Sent At"; DateTime)
        {
            Caption = 'Sent At';
            DataClassification = CustomerContent;
        }
        field(5; "Source ID"; Integer)
        {
            Caption = 'Source ID';
            DataClassification = CustomerContent;
        }
        field(6; "Acknowledged At"; DateTime)
        {
            Caption = 'Acknowledged At';
            DataClassification = CustomerContent;
        }
        field(7; "Secondary Acknowledged At"; DateTime)
        {
            Caption = 'Secondary Acknowledged At';
            DataClassification = CustomerContent;
        }
        field(8; "Canceled At"; DateTime)
        {
            Caption = 'Canceled At';
            DataClassification = CustomerContent;
        }
        field(9; "Shipping Name"; Text[100])
        {
            Caption = 'Shipping Name';
            DataClassification = CustomerContent;
        }
        field(10; "Shipping Address 1"; Text[100])
        {
            Caption = 'Shipping Address 1';
            DataClassification = CustomerContent;
        }
        field(11; "Shipping Address 2"; Text[100])
        {
            Caption = 'Shipping Address 2';
            DataClassification = CustomerContent;
        }
        field(12; "Shipping City"; Text[50])
        {
            Caption = 'Shipping City';
            DataClassification = CustomerContent;
        }
        field(13; "Shipping State"; Text[50])
        {
            Caption = 'Shipping State';
            DataClassification = CustomerContent;
        }
        field(14; "Shipping Country"; Text[50])
        {
            Caption = 'Shipping Country';
            DataClassification = CustomerContent;
        }
        field(15; "Shipping State Code"; Text[10])
        {
            Caption = 'Shipping State Code';
            DataClassification = CustomerContent;
        }
        field(16; "Shipping Country Code"; Text[10])
        {
            Caption = 'Shipping Country Code';
            DataClassification = CustomerContent;
        }
        field(17; "Shipping Postal Code"; Text[20])
        {
            Caption = 'Shipping Postal Code';
            DataClassification = CustomerContent;
        }
        field(18; "Shipping Email"; Text[80])
        {
            Caption = 'Shipping Email';
            DataClassification = CustomerContent;
        }
        field(19; "Shipping Phone"; Text[30])
        {
            Caption = 'Shipping Phone';
            DataClassification = CustomerContent;
        }
        field(20; "Shipping Company"; Text[100])
        {
            Caption = 'Shipping Company';
            DataClassification = CustomerContent;
        }
        field(21; "Shipping First Name"; Text[50])
        {
            Caption = 'Shipping First Name';
            DataClassification = CustomerContent;
        }
        field(22; "Shipping Last Name"; Text[50])
        {
            Caption = 'Shipping Last Name';
            DataClassification = CustomerContent;
        }
        field(23; "Note"; Text[250])
        {
            Caption = 'Note';
            DataClassification = CustomerContent;
        }
        field(24; "Confirmation Number"; Text[50])
        {
            Caption = 'Confirmation Number';
            DataClassification = CustomerContent;
        }
        field(25; "Shipped Status"; Text[50])
        {
            Caption = 'Shipped Status';
            DataClassification = CustomerContent;
        }
        field(26; "Fulfillment Status"; Text[50])
        {
            Caption = 'Fulfillment Status';
            DataClassification = CustomerContent;
        }
        field(27; "Fulfillment Status Handle"; Text[50])
        {
            Caption = 'Fulfillment Status Handle';
            DataClassification = CustomerContent;
        }
        field(28; "Generated At"; DateTime)
        {
            Caption = 'Generated At';
            DataClassification = CustomerContent;
        }
        field(29; "Voided At"; DateTime)
        {
            Caption = 'Voided At';
            DataClassification = CustomerContent;
        }
        field(30; "Account ID"; Integer)
        {
            Caption = 'Account ID';
            DataClassification = CustomerContent;
        }
        field(31; "Total Items"; Integer)
        {
            Caption = 'Total Items';
            DataClassification = CustomerContent;
        }
        field(32; "Total Cost"; Decimal)
        {
            Caption = 'Total Cost';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(33; "Total Quantity"; Integer)
        {
            Caption = 'Total Quantity';
            DataClassification = CustomerContent;
        }
        field(34; "Shipped Quantity"; Integer)
        {
            Caption = 'Shipped Quantity';
            DataClassification = CustomerContent;
        }
        field(35; "Shipping Method"; Text[100])
        {
            Caption = 'Shipping Method';
            DataClassification = CustomerContent;
        }
        field(36; "Carrier"; Text[50])
        {
            Caption = 'Carrier';
            DataClassification = CustomerContent;
        }
        field(37; "Method"; Text[50])
        {
            Caption = 'Method';
            DataClassification = CustomerContent;
        }
        field(38; "Package Length"; Decimal)
        {
            Caption = 'Package Length';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(39; "Package Width"; Decimal)
        {
            Caption = 'Package Width';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(40; "Package Height"; Decimal)
        {
            Caption = 'Package Height';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(41; "Package Weight"; Decimal)
        {
            Caption = 'Package Weight';
            DataClassification = CustomerContent;
            DecimalPlaces = 2: 5;
        }
        field(42; "Last Modified At"; DateTime)
        {
            Caption = 'Last Modified At';
            DataClassification = CustomerContent;
        }
        field(43; "Hold Until"; DateTime)
        {
            Caption = 'Hold Until';
            DataClassification = CustomerContent;
        }
        field(44; "Processing Error Reason"; Text[250])
        {
            Caption = 'Processing Error Reason';
            DataClassification = CustomerContent;
        }
        field(45; "Cancel Reason"; Text[250])
        {
            Caption = 'Cancel Reason';
            DataClassification = CustomerContent;
        }
        field(46; "Voided Reason"; Text[250])
        {
            Caption = 'Voided Reason';
            DataClassification = CustomerContent;
        }
        field(47; "Processed"; Boolean)
        {
            Caption = 'Processed';
            DataClassification = CustomerContent;
        }
        field(48; "Processing Date"; DateTime)
        {
            Caption = 'Processing Date';
            DataClassification = CustomerContent;
        }
        field(49; "Error Message"; Text[250])
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
        }
        field(50; "Sales Order No."; Code[20])
        {
            Caption = 'Sales Order No.';
            DataClassification = CustomerContent;
            TableRelation = "Sales Header"."No." WHERE("Document Type"=CONST(Order));
        }
        field(51; "Sales Order Status"; Option)
        {
            Caption = 'Sales Order Status';
            DataClassification = CustomerContent;
            OptionCaption = 'Not Created,Created,Posted,Cancelled,Error';
            OptionMembers = "Not Created", Created, Posted, Cancelled, Error;
        }
        field(52; "Sales Order Created Date"; DateTime)
        {
            Caption = 'Sales Order Created Date';
            DataClassification = CustomerContent;
        }
        field(53; "Sales Order Posted Date"; DateTime)
        {
            Caption = 'Sales Order Posted Date';
            DataClassification = CustomerContent;
        }
        field(54; "Sales Order Error Message"; Text[250])
        {
            Caption = 'Sales Order Error Message';
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; "Request ID")
        {
            Clustered = true;
        }
        key(Key2; "Fulfillment Request No.")
        {
        }
        key(Key3; "Sales Order No.")
        {
        }
        key(Key4; "Sales Order Status")
        {
        }
        key(Key5; "Processed")
        {
        }
    }
    trigger OnDelete()
    var
        FlxPointFulfillmentReqLine: Record "FlxPoint Fulfillment Req Line";
    begin
        // Delete all related lines
        FlxPointFulfillmentReqLine.SetRange("Request ID", Rec."Request ID");
        FlxPointFulfillmentReqLine.DeleteAll(true);
    end;
}
