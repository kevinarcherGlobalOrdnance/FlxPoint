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
                Caption = 'Sync Inventory';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Synchronize inventory data from FlxPoint';

                trigger OnAction()
                var
                    FlxPointInventorySync: Codeunit "FlxPoint Inventory Sync";
                begin
                    FlxPointInventorySync.Run();
                end;
            }
        }
    }
}
