page 50710 "FlxPoint Inventory Card"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FlxPoint Inventory";
    Caption = 'FlxPoint Inventory';

    layout
    {
        area(Content)
        {
            group(General)
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
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Item Reference ID"; Rec."Item Reference ID")
                {
                    ApplicationArea = All;
                }
                field("Reference Identifier"; Rec."Reference Identifier")
                {
                    ApplicationArea = All;
                }
                field("Supplier Variant ID"; Rec."Supplier Variant ID")
                {
                    ApplicationArea = All;
                }
            }
            group(Identifiers)
            {
                field(UPC; Rec.UPC)
                {
                    ApplicationArea = All;
                }
                field(EAN; Rec.EAN)
                {
                    ApplicationArea = All;
                }
                field(ASIN; Rec.ASIN)
                {
                    ApplicationArea = All;
                }
                field(MPN; Rec.MPN)
                {
                    ApplicationArea = All;
                }
            }
            group(Inventory)
            {
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
                field("Bin Location"; Rec."Bin Location")
                {
                    ApplicationArea = All;
                }
                field("Allow Backorders"; Rec."Allow Backorders")
                {
                    ApplicationArea = All;
                }
            }
            group(Pricing)
            {
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
                field("Shipping Cost"; Rec."Shipping Cost")
                {
                    ApplicationArea = All;
                }
                field("Dropship Fee"; Rec."Dropship Fee")
                {
                    ApplicationArea = All;
                }
            }
            group(Dimensions)
            {
                field(Weight; Rec.Weight)
                {
                    ApplicationArea = All;
                }
                field("Weight Unit"; Rec."Weight Unit")
                {
                    ApplicationArea = All;
                }
                field(Length; Rec.Length)
                {
                    ApplicationArea = All;
                }
                field(Width; Rec.Width)
                {
                    ApplicationArea = All;
                }
                field(Height; Rec.Height)
                {
                    ApplicationArea = All;
                }
                field("Dimension Unit"; Rec."Dimension Unit")
                {
                    ApplicationArea = All;
                }
                field("Dimensional Weight"; Rec."Dimensional Weight")
                {
                    ApplicationArea = All;
                }
            }
            group(Status)
            {
                field("Requires FFL"; Rec."Requires FFL")
                {
                    ApplicationArea = All;
                }
                field(Archived; Rec.Archived)
                {
                    ApplicationArea = All;
                }
            }
            group(Dates)
            {
                field("Inserted At"; Rec."Inserted At")
                {
                    ApplicationArea = All;
                }
                field("Updated At"; Rec."Updated At")
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
                field("Total Quantity Last Changed At"; Rec."Total Quantity Last Changed At")
                {
                    ApplicationArea = All;
                }
                field("Content Updated At"; Rec."Content Updated At")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
