$samplePath = 'data_safety_sample.csv'
$outPath = 'data_safety.csv'

$rows = Import-Csv $samplePath

$purposeIds = @(
    'PSL_APP_FUNCTIONALITY',
    'PSL_ANALYTICS',
    'PSL_DEVELOPER_COMMUNICATIONS',
    'PSL_FRAUD_PREVENTION_SECURITY',
    'PSL_PERSONALIZATION',
    'PSL_ACCOUNT_MANAGEMENT',
    'PSL_ADVERTISING'
)

# Data type ID -> settings
# settings: collected, shared, ephemeral, optional, collPurposes, sharePurposes
$mapping = @{
    'PSL_NAME' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;PERSONALIZATION'; sharePurposes='' }
    'PSL_EMAIL' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT'; sharePurposes='' }
    'PSL_USER_ACCOUNT' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_PHONE' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_OTHER_PERSONAL' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;PERSONALIZATION'; sharePurposes='' }
    'PSL_PURCHASE_HISTORY' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_CREDIT_DEBIT_BANK_ACCOUNT_NUMBER' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_OTHER' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_APPROX_LOCATION' = @{ collected=$true; shared=$true; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;PERSONALIZATION;ADVERTISING'; sharePurposes='ADVERTISING' }
    'PSL_PRECISE_LOCATION' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY'; sharePurposes='' }
    'PSL_OTHER_MESSAGES' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY'; sharePurposes='' }
    'PSL_PHOTOS' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;PERSONALIZATION'; sharePurposes='' }
    'PSL_VIDEOS' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;PERSONALIZATION'; sharePurposes='' }
    'PSL_AUDIO' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY'; sharePurposes='' }
    'PSL_MUSIC' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY'; sharePurposes='' }
    'PSL_FILES_AND_DOCS' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY'; sharePurposes='' }
    'PSL_CRASH_LOGS' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='ANALYTICS;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_PERFORMANCE_DIAGNOSTICS' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='ANALYTICS;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_USER_INTERACTION' = @{ collected=$true; shared=$true; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ANALYTICS;ADVERTISING'; sharePurposes='ADVERTISING' }
    'PSL_IN_APP_SEARCH_HISTORY' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;ANALYTICS;PERSONALIZATION'; sharePurposes='' }
    'PSL_USER_GENERATED_CONTENT' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$true; collPurposes='APP_FUNCTIONALITY;PERSONALIZATION'; sharePurposes='' }
    'PSL_OTHER_APP_ACTIVITY' = @{ collected=$true; shared=$false; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ANALYTICS;FRAUD_PREVENTION_SECURITY'; sharePurposes='' }
    'PSL_DEVICE_ID' = @{ collected=$true; shared=$true; ephemeral=$false; optional=$false; collPurposes='APP_FUNCTIONALITY;ANALYTICS;FRAUD_PREVENTION_SECURITY;ADVERTISING'; sharePurposes='ADVERTISING' }
}

function Set-Row($row, $value) {
    $row.'Response value' = $value
}

foreach ($row in $rows) {
    $qid = $row.'Question ID (machine readable)'
    $rid = $row.'Response ID (machine readable)'

    # Top-level questions
    if ($qid -eq 'PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA') {
        Set-Row $row 'true'
    }
    elseif ($qid -eq 'PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT') {
        Set-Row $row 'true'
    }
    elseif ($qid -eq 'PSL_SUPPORTED_ACCOUNT_CREATION_METHODS') {
        if ($rid -in @('PSL_ACM_USER_ID_OTHER_AUTH','PSL_ACM_OAUTH')) {
            Set-Row $row 'true'
        } else {
            Set-Row $row ''
        }
    }
    elseif ($qid -eq 'PSL_SUPPORT_DATA_DELETION_BY_USER') {
        if ($rid -eq 'DATA_DELETION_YES') {
            Set-Row $row 'true'
        } else {
            Set-Row $row ''
        }
    }
    elseif ($qid -eq 'PSL_ACCOUNT_DELETION_URL') {
        Set-Row $row 'https://unilive.me/delete-account.html'
    }
    elseif ($qid -eq 'PSL_DATA_DELETION_URL') {
        Set-Row $row 'https://unilive.me/delete-account.html'
    }
    elseif ($qid -match '^PSL_DATA_TYPES_') {
        if ($mapping.ContainsKey($rid)) {
            Set-Row $row 'true'
        } else {
            Set-Row $row ''
        }
    }
    elseif ($qid -match '^PSL_DATA_USAGE_RESPONSES:') {
        $parts = $qid.Split(':')
        $dtId = $parts[1]
        $usage = $parts[2]

        if ($mapping.ContainsKey($dtId)) {
            $m = $mapping[$dtId]
            switch ($usage) {
                'PSL_DATA_USAGE_COLLECTION_AND_SHARING' {
                    if ($rid -eq 'PSL_DATA_USAGE_ONLY_COLLECTED') {
                        Set-Row $row 'true'
                    } elseif ($rid -eq 'PSL_DATA_USAGE_ONLY_SHARED' -and $m.shared) {
                        Set-Row $row 'true'
                    } else {
                        Set-Row $row ''
                    }
                }
                'PSL_DATA_USAGE_EPHEMERAL' {
                    if ($m.ephemeral) { Set-Row $row 'true' }
                    else { Set-Row $row 'false' }
                }
                'DATA_USAGE_USER_CONTROL' {
                    if ($rid -eq 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL' -and $m.optional) {
                        Set-Row $row 'true'
                    } elseif ($rid -eq 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED' -and -not $m.optional) {
                        Set-Row $row 'true'
                    } else {
                        Set-Row $row ''
                    }
                }
                'DATA_USAGE_COLLECTION_PURPOSE' {
                    $short = $rid -replace '^PSL_'
                    if ($m.collPurposes.Split(';') -contains $short) {
                        Set-Row $row 'true'
                    } else {
                        Set-Row $row ''
                    }
                }
                'DATA_USAGE_SHARING_PURPOSE' {
                    $short = $rid -replace '^PSL_'
                    if ($m.sharePurposes -and $m.sharePurposes.Split(';') -contains $short) {
                        Set-Row $row 'true'
                    } else {
                        Set-Row $row ''
                    }
                }
            }
        }
    }
}

# Export with no BOM
$lines = $rows | ConvertTo-Csv -NoTypeInformation
$text = ($lines -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText((Resolve-Path .).Path + '\' + $outPath, $text, [System.Text.UTF8Encoding]::new($false))

"Generated $outPath ($($rows.Count) rows)."
