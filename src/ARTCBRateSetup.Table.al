/// <summary>
/// Single-record setup for the AllRatesToday central-bank rate import.
/// The API key is kept in Isolated Storage (module scope), not in a table field.
/// </summary>
table 50100 "ART CB Rate Setup"
{
    Caption = 'Central Bank Rates Setup (AllRatesToday)';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; Enabled; Boolean)
        {
            Caption = 'Enabled';
            ToolTip = 'Specifies whether scheduled (Job Queue) imports are allowed to run. Manual runs from this page do not require it.';
            DataClassification = CustomerContent;
        }
        field(11; "Bank Code"; Code[20])
        {
            Caption = 'Bank Code';
            ToolTip = 'Specifies the AllRatesToday source code of the central bank or tax authority, for example ecb, boe, rbi or hmrc. The full list is on https://allratestoday.com/central-bank-rates-api/.';
            DataClassification = CustomerContent;
        }
        field(12; "Rate Type Filter"; Code[20])
        {
            Caption = 'Rate Type Filter';
            ToolTip = 'Specifies which of the publisher''s rate types to import when a bank prints several (for example reference, buy, sell). Leave blank to take the first type published for each currency.';
            DataClassification = CustomerContent;
        }
        field(13; "Has API Key"; Boolean)
        {
            Caption = 'API Key Stored';
            ToolTip = 'Specifies whether an API key is stored. Without a key the extension reads the keyless evaluation copy of the table (https://allratestoday.com/api/open/central-bank/{bank}), intended for evaluation only.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(20; "Last Run Date/Time"; DateTime)
        {
            Caption = 'Last Run Date/Time';
            ToolTip = 'Specifies when the import last ran.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(21; "Last Rate Date"; Date)
        {
            Caption = 'Last Rate Date';
            ToolTip = 'Specifies the rate_date of the table imported on the last run, i.e. the publication date stated by the bank.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(22; "Last Imported Count"; Integer)
        {
            Caption = 'Last Imported Count';
            ToolTip = 'Specifies how many Currency Exchange Rate lines were inserted or updated on the last run.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(23; "Last Skipped Count"; Integer)
        {
            Caption = 'Last Skipped Count';
            ToolTip = 'Specifies how many published rows were skipped on the last run (currency not set up in Currencies, pair not involving the LCY, or a second rate type for a currency already imported).';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(24; "Last Table Stale"; Boolean)
        {
            Caption = 'Last Table Stale';
            ToolTip = 'Specifies whether the API flagged the last imported table as stale (the bank has not published for longer than its usual cadence).';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(25; "Last Message"; Text[250])
        {
            Caption = 'Last Message';
            ToolTip = 'Specifies the result or error message of the last run.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        ApiKeyStorageKeyLbl: Label 'ART_CB_API_KEY', Locked = true;

    /// <summary>Returns the single setup record, creating it when missing.</summary>
    procedure GetRecordOnce()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;

    /// <summary>Stores the API key in Isolated Storage (module scope). An empty value removes it.</summary>
    procedure SetApiKey(NewApiKey: Text)
    begin
        if NewApiKey = '' then begin
            if IsolatedStorage.Contains(ApiKeyStorageKeyLbl, DataScope::Module) then
                IsolatedStorage.Delete(ApiKeyStorageKeyLbl, DataScope::Module);
            "Has API Key" := false;
        end else begin
            if not EncryptionEnabled() then
                IsolatedStorage.Set(ApiKeyStorageKeyLbl, NewApiKey, DataScope::Module)
            else
                IsolatedStorage.SetEncrypted(ApiKeyStorageKeyLbl, NewApiKey, DataScope::Module);
            "Has API Key" := true;
        end;
        Modify();
    end;

    /// <summary>Reads the API key from Isolated Storage. Returns an empty string when none is stored.</summary>
    [NonDebuggable]
    procedure GetApiKey() ApiKey: Text
    begin
        if not IsolatedStorage.Contains(ApiKeyStorageKeyLbl, DataScope::Module) then
            exit('');
        IsolatedStorage.Get(ApiKeyStorageKeyLbl, DataScope::Module, ApiKey);
    end;
}
