tableextension 50701 CustomerTableExt extends Customer
{
    fields
    {
        field(50700; "Ecommerce Customer 2"; Boolean)
        {
            Caption = 'Ecommerce Customer';
            DataClassification = CustomerContent;
        }
    }
}
