page 50740 "BigCommerce Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "BigCommerce Setup";
    Caption = 'BigCommerce Setup';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group("API Configuration")
            {
                Caption = 'API Configuration';

                field("Store Hash"; Rec."Store Hash")
                {
                    ApplicationArea = All;
                    ToolTip = 'The unique store hash from your BigCommerce store URL (store-{hash}.mybigcommerce.com)';
                }
                field("API Token"; Rec."API Token")
                {
                    ApplicationArea = All;
                    ToolTip = 'The API token for authenticating with BigCommerce API';
                }
                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Client ID from your BigCommerce app configuration';
                }
                field("Client Secret"; Rec."Client Secret")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Client Secret from your BigCommerce app configuration';
                }
                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'The base URL for BigCommerce API calls. Use {store_hash} placeholder for dynamic replacement.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable or disable BigCommerce integration';
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
                Caption = 'Test Connection';
                Image = TestReport;
                ToolTip = 'Test the connection to BigCommerce API with the current settings';

                trigger OnAction()
                var
                    SuccessMsg: Label 'Connection to BigCommerce API successful!';
                    ErrorMsg: Label 'Failed to connect to BigCommerce API. Please check your settings.';
                begin
                    if Rec.TestConnection()then Message(SuccessMsg)
                    else
                        Message(ErrorMsg);
                end;
            }
        }
        area(Navigation)
        {
            action(OpenBigCommerceAdmin)
            {
                ApplicationArea = All;
                Caption = 'Open BigCommerce Admin';
                Image = Web;
                ToolTip = 'Open BigCommerce admin panel in your browser';

                trigger OnAction()
                var
                    AdminUrl: Text;
                begin
                    if Rec."Store Hash" <> '' then begin
                        AdminUrl:='https://store-' + Rec."Store Hash" + '.mybigcommerce.com/manage';
                        Hyperlink(AdminUrl);
                    end
                    else
                        Message('Store Hash must be configured first.');
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        if not Rec.Get('DEFAULT')then begin
            Rec.Init();
            Rec."Primary Key":='DEFAULT';
            Rec.Insert();
        end;
    end;
}
