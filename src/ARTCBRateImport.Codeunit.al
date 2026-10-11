/// <summary>
/// Calls GET https://allratestoday.com/api/v1/central-bank/{bank}/latest and writes the published table
/// into "Currency Exchange Rate". OnRun is the Job Queue entry point.
///
/// Direction: `value` is always quote currency per 1 unit of base currency. Each row is matched against
/// General Ledger Setup."LCY Code":
///   base = LCY  (bank quotes foreign per 1 home, e.g. ECB EUR->USD 1.15)
///       -> Currency Code = quote, Exchange Rate Amount = value, Relational Exch. Rate Amount = 1
///   quote = LCY (bank quotes home per 1 foreign, e.g. RBI USD->INR 96.6)
///       -> Currency Code = base,  Exchange Rate Amount = 1,     Relational Exch. Rate Amount = value
/// Rows involving neither side, currencies missing from the Currency table, and second rate types for a
/// currency already written in this run are skipped and counted.
/// </summary>
codeunit 50100 "ART CB Rate Import"
{
    TableNo = "ART CB Rate Setup";

    trigger OnRun()
    var
        Setup: Record "ART CB Rate Setup";
    begin
        Setup.GetRecordOnce();
        Setup.TestField(Enabled);
        Setup.TestField("Bank Code");
        ImportRates(Setup);
    end;

    var
        BaseUrlLbl: Label 'https://allratestoday.com/api/v1/central-bank/%1/latest', Comment = '%1 = bank code', Locked = true;
        OpenUrlLbl: Label 'https://allratestoday.com/api/open/central-bank/%1', Comment = '%1 = bank code', Locked = true;
        UserAgentLbl: Label 'business-central-central-bank-rates/1.0 (+https://allratestoday.com/docs/integrations/business-central/)', Locked = true;
        ConnectionErr: Label 'Could not reach the AllRatesToday API. Check that outbound HTTPS to allratestoday.com is allowed for this environment.';
        HttpStatusErr: Label 'The AllRatesToday API returned HTTP %1 %2 for bank "%3". Response: %4', Comment = '%1 = status code, %2 = reason phrase, %3 = bank code, %4 = response body (truncated)';
        InvalidJsonErr: Label 'The response from the AllRatesToday API was not valid JSON.';
        MissingFieldErr: Label 'The response did not contain the expected field "%1".', Comment = '%1 = JSON field name';
        InvalidDateErr: Label 'The response rate_date "%1" could not be read as a date.', Comment = '%1 = rate_date text';
        ResultMsg: Label '%1: table dated %2 imported. %3 exchange rate line(s) written, %4 row(s) skipped.', Comment = '%1 = bank code, %2 = rate date, %3 = imported count, %4 = skipped count';
        StaleMsg: Label ' The API flags this table as stale (older than the bank''s usual cadence).';
        JobQueueDescLbl: Label 'AllRatesToday: import central-bank exchange rates', MaxLength = 250;
        JobQueueCreatedMsg: Label 'A recurring Job Queue entry was created on hold. Set its earliest start time to after the bank''s publication time, then set the status to Ready.';

    /// <summary>Runs one import for the given setup record and stores the result on it.</summary>
    procedure ImportRates(var Setup: Record "ART CB Rate Setup")
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        ResponseJson: JsonObject;
        RateDate: Date;
        IsStale: Boolean;
        ImportedCount: Integer;
        SkippedCount: Integer;
        ResultText: Text;
    begin
        GeneralLedgerSetup.Get();
        GeneralLedgerSetup.TestField("LCY Code");

        ResponseJson := FetchLatestTable(Setup);
        RateDate := GetRateDate(ResponseJson);
        IsStale := GetBooleanField(ResponseJson, 'stale');

        ApplyTable(ResponseJson, RateDate, GeneralLedgerSetup."LCY Code", Setup."Rate Type Filter", ImportedCount, SkippedCount);

        ResultText := StrSubstNo(ResultMsg, Setup."Bank Code", Format(RateDate, 0, 9), ImportedCount, SkippedCount);
        if IsStale then
            ResultText += StaleMsg;

        Setup."Last Run Date/Time" := CurrentDateTime();
        Setup."Last Rate Date" := RateDate;
        Setup."Last Imported Count" := ImportedCount;
        Setup."Last Skipped Count" := SkippedCount;
        Setup."Last Table Stale" := IsStale;
        Setup."Last Message" := CopyStr(ResultText, 1, MaxStrLen(Setup."Last Message"));
        Setup.Modify();
        Commit();

        Session.LogMessage('ARTCB0001', ResultText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'AllRatesToday CB Import');

        if GuiAllowed() then
            Message(ResultText);
    end;

    /// <summary>Creates a daily recurring Job Queue entry (on hold) for this codeunit and opens its card.</summary>
    procedure CreateJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.Init();
        JobQueueEntry.Validate("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.Validate("Object ID to Run", Codeunit::"ART CB Rate Import");
        JobQueueEntry.Description := JobQueueDescLbl;
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := false;
        JobQueueEntry."Run on Sundays" := false;
        // 17:00 local server time: after the ECB's ~16:00 CET publication. Adjust per bank.
        JobQueueEntry."Starting Time" := 170000T;
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 600;
        JobQueueEntry."Earliest Start Date/Time" := CreateDateTime(Today(), 170000T);
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(true);

        if GuiAllowed() then begin
            Message(JobQueueCreatedMsg);
            Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
        end;
    end;

    local procedure FetchLatestTable(var Setup: Record "ART CB Rate Setup") ResponseJson: JsonObject
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        ApiKey: Text;
        Url: Text;
        Body: Text;
    begin
        ApiKey := Setup.GetApiKey();
        // Code fields are upper-case in AL; the API expects lower-case bank codes (ecb, rbi, hmrc).
        if ApiKey <> '' then
            Url := StrSubstNo(BaseUrlLbl, LowerCase(Setup."Bank Code"))
        else
            // Keyless evaluation copy of the same table (evaluation only, visible attribution required).
            Url := StrSubstNo(OpenUrlLbl, LowerCase(Setup."Bank Code"));

        Client.Timeout := 30000;
        Headers := Client.DefaultRequestHeaders();
        Headers.Add('Accept', 'application/json');
        Headers.Add('User-Agent', UserAgentLbl);
        if ApiKey <> '' then
            Headers.Add('Authorization', 'Bearer ' + ApiKey);

        if not Client.Get(Url, Response) then
            Error(ConnectionErr);

        Response.Content().ReadAs(Body);

        if not Response.IsSuccessStatusCode() then
            Error(HttpStatusErr, Response.HttpStatusCode(), Response.ReasonPhrase(), Setup."Bank Code", CopyStr(Body, 1, 500));

        if not ResponseJson.ReadFrom(Body) then
            Error(InvalidJsonErr);
    end;

    local procedure ApplyTable(ResponseJson: JsonObject; RateDate: Date; LcyCode: Code[10]; RateTypeFilter: Code[20]; var ImportedCount: Integer; var SkippedCount: Integer)
    var
        RatesToken: JsonToken;
        RateToken: JsonToken;
        WrittenCurrencies: List of [Code[10]];
    begin
        if not ResponseJson.Get('rates', RatesToken) or not RatesToken.IsArray() then
            Error(MissingFieldErr, 'rates');

        foreach RateToken in RatesToken.AsArray() do
            if TryApplyRow(RateToken.AsObject(), RateDate, LcyCode, RateTypeFilter, WrittenCurrencies) then
                ImportedCount += 1
            else
                SkippedCount += 1;
    end;

    /// <summary>Writes one published row when it resolves to a known currency against the LCY. Returns false when the row is skipped.</summary>
    local procedure TryApplyRow(RateJson: JsonObject; RateDate: Date; LcyCode: Code[10]; RateTypeFilter: Code[20]; var WrittenCurrencies: List of [Code[10]]): Boolean
    var
        Currency: Record Currency;
        BaseCcy: Code[10];
        QuoteCcy: Code[10];
        RateType: Code[20];
        CurrencyCode: Code[10];
        Value: Decimal;
        ExchangeRateAmount: Decimal;
        RelationalExchRateAmount: Decimal;
    begin
        BaseCcy := CopyStr(UpperCase(GetTextField(RateJson, 'base')), 1, MaxStrLen(BaseCcy));
        QuoteCcy := CopyStr(UpperCase(GetTextField(RateJson, 'quote')), 1, MaxStrLen(QuoteCcy));
        RateType := CopyStr(UpperCase(GetTextField(RateJson, 'type')), 1, MaxStrLen(RateType));
        Value := GetDecimalField(RateJson, 'value');

        // Optional rate-type filter (publishers may print buy/sell/reference for one pair).
        if (RateTypeFilter <> '') and (RateType <> RateTypeFilter) then
            exit(false);

        // Resolve direction against the LCY. value = quote per 1 base.
        if (BaseCcy = LcyCode) and (QuoteCcy <> LcyCode) then begin
            // Foreign per 1 home (ECB style): value units of foreign = 1 LCY
            CurrencyCode := QuoteCcy;
            ExchangeRateAmount := Value;
            RelationalExchRateAmount := 1;
        end else
            if (QuoteCcy = LcyCode) and (BaseCcy <> LcyCode) then begin
                // Home per 1 foreign (RBI style): 1 unit of foreign = value LCY
                CurrencyCode := BaseCcy;
                ExchangeRateAmount := 1;
                RelationalExchRateAmount := Value;
            end else
                // Cross pair not involving the LCY (e.g. USD/JPY on a table whose home currency is GTQ).
                exit(false);

        if (Value <= 0) or (CurrencyCode = '') then
            exit(false);

        // Only currencies already set up in Business Central are written.
        if not Currency.Get(CurrencyCode) then
            exit(false);

        // One line per currency per date: the first rate type published wins unless filtered above.
        if WrittenCurrencies.Contains(CurrencyCode) then
            exit(false);

        UpsertExchangeRate(CurrencyCode, RateDate, ExchangeRateAmount, RelationalExchRateAmount);
        WrittenCurrencies.Add(CurrencyCode);
        exit(true);
    end;

    local procedure UpsertExchangeRate(CurrencyCode: Code[10]; StartingDate: Date; ExchangeRateAmount: Decimal; RelationalExchRateAmount: Decimal)
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        IsNew: Boolean;
    begin
        IsNew := not CurrencyExchangeRate.Get(CurrencyCode, StartingDate);
        if IsNew then begin
            CurrencyExchangeRate.Init();
            CurrencyExchangeRate.Validate("Currency Code", CurrencyCode);
            CurrencyExchangeRate.Validate("Starting Date", StartingDate);
        end;
        CurrencyExchangeRate.Validate("Exchange Rate Amount", ExchangeRateAmount);
        CurrencyExchangeRate.Validate("Relational Exch. Rate Amount", RelationalExchRateAmount);
        CurrencyExchangeRate.Validate("Adjustment Exch. Rate Amount", ExchangeRateAmount);
        CurrencyExchangeRate.Validate("Relational Adjmt Exch Rate Amt", RelationalExchRateAmount);
        if IsNew then
            CurrencyExchangeRate.Insert(true)
        else
            CurrencyExchangeRate.Modify(true);
    end;

    local procedure GetRateDate(ResponseJson: JsonObject) RateDate: Date
    var
        RateDateText: Text;
    begin
        RateDateText := GetTextField(ResponseJson, 'rate_date');
        // Format 9 = XML (yyyy-MM-dd), which is what the API returns.
        if not Evaluate(RateDate, RateDateText, 9) then
            Error(InvalidDateErr, RateDateText);
    end;

    local procedure GetTextField(JsonObj: JsonObject; FieldName: Text) Result: Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(FieldName, Token) then
            Error(MissingFieldErr, FieldName);
        if Token.AsValue().IsNull() then
            Error(MissingFieldErr, FieldName);
        Result := Token.AsValue().AsText();
    end;

    local procedure GetDecimalField(JsonObj: JsonObject; FieldName: Text) Result: Decimal
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(FieldName, Token) then
            Error(MissingFieldErr, FieldName);
        if Token.AsValue().IsNull() then
            Error(MissingFieldErr, FieldName);
        Result := Token.AsValue().AsDecimal();
    end;

    local procedure GetBooleanField(JsonObj: JsonObject; FieldName: Text) Result: Boolean
    var
        Token: JsonToken;
    begin
        // Optional: absent on some response shapes.
        if not JsonObj.Get(FieldName, Token) then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Result := Token.AsValue().AsBoolean();
    end;
}
