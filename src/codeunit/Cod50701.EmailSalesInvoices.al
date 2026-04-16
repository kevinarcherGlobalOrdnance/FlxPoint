codeunit 50701 EmailSalesInvoices
{

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20]; CommitIsSuppressed: Boolean; InvtPickPutaway: Boolean; var CustLedgerEntry: Record "Cust. Ledger Entry"; WhseShip: Boolean; WhseReceiv: Boolean; PreviewMode: Boolean);
    var
        O365SetupEmail: Codeunit "O365 Setup Email";
        CustomerRecord: Record Customer;
    begin
        if not PreviewMode then
            if SalesInvHdrNo <> '' then begin
                SalesInvoiceHeader.SetRange("No.", SalesInvHdrNo);
                If SalesInvoiceHeader.FindFirst then begin
                    CustomerRecord.Get(SalesInvoiceHeader."Sell-to Customer No.");
                    if NOT CustomerRecord."Ecommerce Customer 2" then begin
                        O365SetupEmail.CheckMailSetup();
                        IF CheckSendToEmailAddress(SalesInvoiceHeader."No.") then SalesInvoiceHeader.EmailRecords(false);
                    end;
                end;
            end;
    end;

    local procedure CheckSendToEmailAddress(DocumentNo: Code[20]): Boolean
    begin
        if GetSendToEmailAddress(DocumentNo) <> '' then EXIT(true);
    end;

    local procedure GetSendToEmailAddress(DocumentNo: Code[20]): Text[250]
    var
        EmailAddress: Text[250];
    begin
        EmailAddress := GetDocumentEmailAddress(DocumentNo);
        if EmailAddress <> '' then exit(EmailAddress);
        EmailAddress := GetCustomerEmailAddress();
        exit(EmailAddress);
    end;

    local procedure GetCustomerEmailAddress(): Text[250]
    var
        Customer: Record Customer;
    begin
        if not Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then exit('');
        exit(Customer."E-Mail");
    end;

    local procedure GetDocumentEmailAddress(DocumentNo: Code[20]): Text[250]
    var
        EmailParameter: Record "Email Parameter";
    begin
        if not EmailParameter.Get(DocumentNo, EmailParameter."Document Type"::Invoice, EmailParameter."Parameter Type"::Address) then exit('');
        exit(EmailParameter."Parameter Value");
    end;

    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
}
