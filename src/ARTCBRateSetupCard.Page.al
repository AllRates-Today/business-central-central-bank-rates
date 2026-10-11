/// <summary>
/// Setup card: API key, bank code, enabled flag, last-run diagnostics, and actions to import now
/// or create a Job Queue entry.
/// </summary>
page 50100 "ART CB Rate Setup Card"
{
    Caption = 'Central Bank Rates Setup (AllRatesToday)';
    PageType = Card;
    SourceTable = "ART CB Rate Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Official central-bank rates in Business Central';
    AboutText = 'Imports the latest table published by the selected central bank or tax authority from the AllRatesToday API into Currency Exchange Rates, dated with the bank''s own rate_date. Bank codes: https://allratestoday.com/central-bank-rates-api/';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
                field("Bank Code"; Rec."Bank Code")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                }
                field("Rate Type Filter"; Rec."Rate Type Filter")
                {
                    ApplicationArea = All;
                }
                field(ApiKeyInput; ApiKeyInput)
                {
                    ApplicationArea = All;
                    Caption = 'API Key';
                    ToolTip = 'Specifies the AllRatesToday API key (free key: https://allratestoday.com/register/). Stored in Isolated Storage and never shown again. Leave empty to use the keyless evaluation copy.';
                    ExtendedDatatype = Masked;

                    trigger OnValidate()
                    begin
                        Rec.SetApiKey(ApiKeyInput);
                        ApiKeyInput := '';
                        CurrPage.Update(false);
                    end;
                }
                field("Has API Key"; Rec."Has API Key")
                {
                    ApplicationArea = All;
                }
            }
            group(LastRun)
            {
                Caption = 'Last Run';

                field("Last Run Date/Time"; Rec."Last Run Date/Time")
                {
                    ApplicationArea = All;
                }
                field("Last Rate Date"; Rec."Last Rate Date")
                {
                    ApplicationArea = All;
                }
                field("Last Imported Count"; Rec."Last Imported Count")
                {
                    ApplicationArea = All;
                }
                field("Last Skipped Count"; Rec."Last Skipped Count")
                {
                    ApplicationArea = All;
                }
                field("Last Table Stale"; Rec."Last Table Stale")
                {
                    ApplicationArea = All;
                }
                field("Last Message"; Rec."Last Message")
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
            action(ImportNow)
            {
                ApplicationArea = All;
                Caption = 'Import Rates Now';
                ToolTip = 'Fetches the bank''s latest published table and writes it to Currency Exchange Rates immediately. Counts as one API call.';
                Image = Refresh;

                trigger OnAction()
                var
                    RateImport: Codeunit "ART CB Rate Import";
                begin
                    Rec.TestField("Bank Code");
                    RateImport.ImportRates(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CreateJobQueueEntry)
            {
                ApplicationArea = All;
                Caption = 'Create Job Queue Entry';
                ToolTip = 'Creates a recurring Job Queue entry (on hold) that runs the import daily. Set the time to after the bank''s publication time and set the status to Ready.';
                Image = Calendar;

                trigger OnAction()
                var
                    RateImport: Codeunit "ART CB Rate Import";
                begin
                    Rec.TestField("Bank Code");
                    RateImport.CreateJobQueueEntry();
                end;
            }
        }
        area(Navigation)
        {
            action(CurrencyExchangeRates)
            {
                ApplicationArea = All;
                Caption = 'Currency Exchange Rates';
                ToolTip = 'Opens the Currency Exchange Rates list to check the imported lines.';
                Image = Currencies;
                RunObject = page "Currency Exchange Rates";
            }
            action(JobQueueEntries)
            {
                ApplicationArea = All;
                Caption = 'Job Queue Entries';
                ToolTip = 'Opens the Job Queue Entries list.';
                Image = JobListSetup;
                RunObject = page "Job Queue Entries";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ImportNow_Promoted; ImportNow) { }
                actionref(CreateJobQueueEntry_Promoted; CreateJobQueueEntry) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navigate';

                actionref(CurrencyExchangeRates_Promoted; CurrencyExchangeRates) { }
                actionref(JobQueueEntries_Promoted; JobQueueEntries) { }
            }
        }
    }

    var
        ApiKeyInput: Text;

    trigger OnOpenPage()
    begin
        Rec.GetRecordOnce();
    end;
}
