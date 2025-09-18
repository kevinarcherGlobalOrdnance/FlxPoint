table 50740 "BigCommerce Setup"
{
    DataClassification = CustomerContent;
    Caption = 'BigCommerce Setup';

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = CustomerContent;
        }
        field(10; "Store Hash"; Text[100])
        {
            Caption = 'Store Hash';
            DataClassification = CustomerContent;
            ToolTip = 'The unique store hash from your BigCommerce store URL (store-{hash}.mybigcommerce.com)';
        }
        field(20; "API Token"; Text[250])
        {
            Caption = 'API Token';
            DataClassification = EndUserPseudonymousIdentifiers;
            ExtendedDatatype = Masked;
            ToolTip = 'The API token for authenticating with BigCommerce API';
        }
        field(30; "Client ID"; Text[100])
        {
            Caption = 'Client ID';
            DataClassification = CustomerContent;
            ToolTip = 'The Client ID from your BigCommerce app configuration';
        }
        field(40; "Client Secret"; Text[250])
        {
            Caption = 'Client Secret';
            DataClassification = EndUserPseudonymousIdentifiers;
            ExtendedDatatype = Masked;
            ToolTip = 'The Client Secret from your BigCommerce app configuration';
        }
        field(50; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';
            DataClassification = CustomerContent;
            InitValue = 'https://api.bigcommerce.com/stores/{store_hash}/v3/catalog/';
            ToolTip = 'The base URL for BigCommerce API calls. Use {store_hash} placeholder for dynamic replacement.';
        }
        field(60; Enabled; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = CustomerContent;
            ToolTip = 'Enable or disable BigCommerce integration';
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
    trigger OnInsert()
    begin
        "Primary Key":='DEFAULT';
    end;
    procedure GetAPIBaseURL(): Text begin
        if "Store Hash" = '' then exit("API Base URL");
        exit("API Base URL".Replace('{store_hash}', "Store Hash"));
    end;
    procedure TestConnection(): Boolean var
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
    begin
        if not Enabled then Error('BigCommerce integration is not enabled.');
        if("Store Hash" = '') or ("API Token" = '')then Error('Store Hash and API Token are required for connection test.');
        RequestMessage.Method:='GET';
        RequestMessage.SetRequestUri(GetAPIBaseURL() + 'products');
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Auth-Token', "API Token");
        RequestHeaders.Add('Accept', 'application/json');
        if Client.Send(RequestMessage, ResponseMessage)then exit(ResponseMessage.IsSuccessStatusCode)
        else
            exit(false);
    end;
}
