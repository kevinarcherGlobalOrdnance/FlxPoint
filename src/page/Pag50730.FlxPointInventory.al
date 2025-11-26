page 50730 "FlxPoint Inventory"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FlxPoint Inventory";
    Caption = 'FlxPoint Inventory';
    CardPageId = "FlxPoint Inventory Card";

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Inventory Variant ID"; Rec."Inventory Variant ID")
                {
                    ApplicationArea = All;
                }
                field(SKU; Rec.SKU)
                {
                    ApplicationArea = All;
                }
                field("Master SKU"; Rec."Master SKU")
                {
                    ApplicationArea = All;
                }
                field(Title; Rec.Title)
                {
                    ApplicationArea = All;
                }
                field(UPC; Rec.UPC)
                {
                    ApplicationArea = All;
                }
                field(MPN; Rec.MPN)
                {
                    ApplicationArea = All;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }
                field("Total Quantity"; Rec."Total Quantity")
                {
                    ApplicationArea = All;
                }
                field("Committed Quantity"; Rec."Committed Quantity")
                {
                    ApplicationArea = All;
                }
                field("Incoming Quantity"; Rec."Incoming Quantity")
                {
                    ApplicationArea = All;
                }
                field(Cost; Rec.Cost)
                {
                    ApplicationArea = All;
                }
                field("Inventory List Price"; Rec."Inventory List Price")
                {
                    ApplicationArea = All;
                }
                field(MSRP; Rec.MSRP)
                {
                    ApplicationArea = All;
                }
                field(MAP; Rec.MAP)
                {
                    ApplicationArea = All;
                }
                field(Weight; Rec.Weight)
                {
                    ApplicationArea = All;
                }
                field("Weight Unit"; Rec."Weight Unit")
                {
                    ApplicationArea = All;
                }
                field("Requires FFL"; Rec."Requires FFL")
                {
                    ApplicationArea = All;
                }
                field("Allow Backorders"; Rec."Allow Backorders")
                {
                    ApplicationArea = All;
                }
                field(Archived; Rec.Archived)
                {
                    ApplicationArea = All;
                }
                field("Last Modified Date"; Rec."Last Modified Date")
                {
                    ApplicationArea = All;
                }
                field("Last Sync Date"; Rec."Last Sync Date")
                {
                    ApplicationArea = All;
                }
                field("Business Central Item No."; Rec."Business Central Item No.")
                {
                    ApplicationArea = All;
                }
                field("Business Central UOM"; Rec."Business Central UOM")
                {
                    ApplicationArea = All;
                }
                field("Business Central QOH"; Rec."Business Central QOH")
                {
                    ApplicationArea = All;
                }
                field("Business Central Price"; Rec."Business Central Price")
                {
                    ApplicationArea = All;
                }
                field("Business Central Cost"; Rec."Business Central Cost")
                {
                    ApplicationArea = All;
                }
                field("Business Central MAP"; Rec.MAP)
                {
                    ApplicationArea = All;
                }
                field("BigCommerce Price"; Rec."BigCommerce Price")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(SyncInventory)
            {
                ApplicationArea = All;
                Caption = 'Sync Filtered Inventory';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Synchronize only the filtered inventory items to FlxPoint';

                trigger OnAction()
                var
                    FlxPointInventorySync: Codeunit "FlxPoint Inventory Sync";
                begin
                    // Only update filtered items, not full sync
                    FlxPointInventorySync.UpdateFlxPointInventoryFiltered(Rec);
                end;
            }
            action(SyncAllInventory)
            {
                ApplicationArea = All;
                Caption = 'Sync All Inventory';
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Perform full bidirectional synchronization of all inventory data with FlxPoint (pulls from FlxPoint and pushes updates back)';

                trigger OnAction()
                var
                    FlxPointInventorySync: Codeunit "FlxPoint Inventory Sync";
                begin
                    // Full sync: pull from FlxPoint and push updates back for all products
                    FlxPointInventorySync.Run();
                end;
            }
        }
    }
}
