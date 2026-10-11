permissionset 50100 "ART CB Rates"
{
    Caption = 'Central Bank Rates (AllRatesToday)';
    Assignable = true;

    Permissions =
        table "ART CB Rate Setup" = X,
        tabledata "ART CB Rate Setup" = RIMD,
        page "ART CB Rate Setup Card" = X,
        codeunit "ART CB Rate Import" = X,
        tabledata "Currency Exchange Rate" = RIM,
        tabledata Currency = R,
        tabledata "General Ledger Setup" = R,
        tabledata "Job Queue Entry" = RIMD;
}
